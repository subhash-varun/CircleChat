import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:jhol_jhal_chat/api_services/services.dart';
import 'package:jhol_jhal_chat/common/common_entities.dart';
import 'package:jhol_jhal_chat/model/chat/contact_list_model.dart';
import 'package:jhol_jhal_chat/model/chat/conversation_model.dart';
import 'package:jhol_jhal_chat/provider/chat_provider.dart';
import 'package:jhol_jhal_chat/screens/admin/admin_dashboard_screen.dart';
import 'package:jhol_jhal_chat/screens/chat/chat_screen.dart';
import 'package:jhol_jhal_chat/services/user_presence_service.dart';
import 'package:jhol_jhal_chat/services/zego_call_service.dart';
import 'package:jhol_jhal_chat/theme/jj_theme.dart';
import 'package:provider/provider.dart';

class ChatListScreen extends StatefulWidget {
  static const String route = 'chat_list';

  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final Services _services = Services();
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'jholjhalchatdb');
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _lastRequestedQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      debugPrint(
        '[CHAT_LIST] init currentUserRef="${chatProvider.currentUserRef}" '
        'zegoUserIdCandidate="${chatProvider.currentUserRef.trim()}"',
      );
      chatProvider.loadConversations();
      chatProvider.loadContacts();
      chatProvider.registerCurrentDeviceToken();
      ZegoCallService.instance.initializeForCurrentUser(
        userId: chatProvider.currentUserRef,
        userName: _resolveCurrentUserName(),
      );
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = JjTheme.accent;
    final lightGreyColor = JjTheme.deep;

    return Scaffold(
      backgroundColor: JjTheme.deep,
      appBar: AppBar(
        title: const Text('Chats'),
        backgroundColor: JjTheme.surface,
        foregroundColor: JjTheme.text,
        actions: [
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                .snapshots(),
            builder: (context, snapshot) {
              final isAdmin = snapshot.data?.data()?['isAdmin'] == true;
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: _onAppBarMenuSelected,
                itemBuilder: (context) => [
                  if (isAdmin)
                    const PopupMenuItem<String>(
                      value: 'dashboard',
                      child: Text('Dashboard'),
                    ),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Text('Logout'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<ChatProvider>(
        builder: (context, chatProvider, child) {
          final sortedContacts = _sortedContacts(chatProvider);
          final isInitialLoading =
              chatProvider.isLoadingContacts && chatProvider.contacts.isEmpty;
          if (isInitialLoading) {
            return Container(
              color: lightGreyColor,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (chatProvider.contacts.isEmpty) {
            return Container(
              color: lightGreyColor,
              child: RefreshIndicator(
                color: primaryColor,
                onRefresh: () async {
                  await context.read<ChatProvider>().loadContacts(
                        searchText: _searchQuery,
                      );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    _buildSearchBar(primaryColor),
                    const SizedBox(height: 120),
                    Center(
                      child: Text(
                        _searchQuery.isEmpty
                            ? 'No contacts found'
                            : 'No results for "$_searchQuery"',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            color: lightGreyColor,
            child: RefreshIndicator(
              color: primaryColor,
              onRefresh: () async {
                final provider = context.read<ChatProvider>();
                await provider.loadConversations();
                await provider.loadContacts(
                      searchText: _searchQuery,
                    );
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildSearchBar(primaryColor),
                  if (chatProvider.isLoadingContacts)
                    const LinearProgressIndicator(minHeight: 2),
                  ...List.generate(sortedContacts.length, (index) {
                    final contact = sortedContacts[index];
                    final conversation = _findConversation(
                        chatProvider.conversations, contact.assigneeRef);
                    return Column(
                      children: [
                        _ChatContactTile(
                          contact: contact,
                          conversation: conversation,
                          onTap: () => _openContactChat(contact,
                              existingConversation: conversation),
                        ),
                        const Divider(height: 1),
                      ],
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<ChatContact> _sortedContacts(ChatProvider provider) {
    final contacts = List<ChatContact>.from(provider.contacts);
    contacts.sort((a, b) {
      final aConversation = _findConversation(provider.conversations, a.assigneeRef);
      final bConversation = _findConversation(provider.conversations, b.assigneeRef);

      if (aConversation != null && bConversation != null) {
        return bConversation.lastMessageAt.compareTo(aConversation.lastMessageAt);
      }
      if (aConversation != null) return -1;
      if (bConversation != null) return 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return contacts;
  }

  Conversation? _findConversation(
    List<Conversation> conversations,
    String assigneeRef,
  ) {
    final myRef = context.read<ChatProvider>().currentUserRef.trim();
    for (final conversation in conversations) {
      final assignedTo = (conversation.assignedTo ?? '').trim();
      final customerId = conversation.customerId.trim();
      final matchesForward = assignedTo == assigneeRef && customerId == myRef;
      final matchesReverse = customerId == assigneeRef && assignedTo == myRef;
      if (matchesForward || matchesReverse) {
        return conversation;
      }
    }
    return null;
  }

  Future<void> _openContactChat(
    ChatContact contact, {
    Conversation? existingConversation,
  }) async {
    debugPrint(
      '[CHAT_LIST] tap contact="${contact.displayName}" '
      'assigneeRef="${contact.assigneeRef}" '
      'matchedConversationId="${existingConversation?.id ?? ''}" '
      'matchedAssignedTo="${existingConversation?.assignedTo ?? ''}" '
      'matchedCustomerId="${existingConversation?.customerId ?? ''}"',
    );

    if (existingConversation != null) {
      if (!mounted) return;
      debugPrint(
        '[CHAT_LIST] opening existing conversationId="${existingConversation.id}" '
        'for contact="${contact.displayName}"',
      );
      Navigator.pushNamed(
        context,
        ChatScreen.route,
        arguments: ChatScreenArgs(
          conversationId: existingConversation.id,
          chatTitle: contact.displayName,
        ),
      );
      return;
    }

    final chatProvider = context.read<ChatProvider>();
    final conversationId =
        await chatProvider.createOrOpenConversationWithAssignee(
      assignedTo: contact.assigneeRef,
      type: 'general',
      initialMessage: '',
    );

    if (conversationId != null && mounted) {
      debugPrint(
        '[CHAT_LIST] opening createOrOpen conversationId="$conversationId" '
        'for contact="${contact.displayName}"',
      );
      Navigator.pushNamed(
        context,
        ChatScreen.route,
        arguments: ChatScreenArgs(
          conversationId: conversationId,
          chatTitle: contact.displayName,
        ),
      );
    }
  }

  Widget _buildSearchBar(Color primaryColor) {
    return Container(
      color: JjTheme.deep,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: JjTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: JjTheme.border),
        ),
        child: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search',
            hintStyle: const TextStyle(color: JjTheme.textMuted),
            prefixIcon: const Icon(Icons.search, color: JjTheme.textMuted),
            suffixIcon: _searchQuery.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    color: JjTheme.textMuted,
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          style: const TextStyle(color: JjTheme.text),
        ),
      ),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final normalized = value.trim();
    if (_searchQuery != normalized) {
      setState(() {
        _searchQuery = normalized;
      });
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      // Avoid request-per-keystroke UX: search only after 2 chars, or when cleared.
      if (_searchQuery.isNotEmpty && _searchQuery.length < 2) return;
      if (_lastRequestedQuery == _searchQuery) return;
      _lastRequestedQuery = _searchQuery;
      context.read<ChatProvider>().loadContacts(searchText: _searchQuery);
    });
  }

  Future<void> _onAppBarMenuSelected(String value) async {
    if (value == 'dashboard') {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const AdminDashboardScreen(),
        ),
      );
      return;
    }
    if (value != 'logout') return;
    final userRef = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (userRef.trim().isNotEmpty && (token ?? '').trim().isNotEmpty) {
        await _services.api.unregisterDeviceToken(
          userRef: userRef,
          token: token!.trim(),
        );
      }
    } catch (e) {
      debugPrint('[CHAT_LIST] unregister token on logout failed: $e');
    }
    await UserPresenceService.markOffline(userRef);
    await FirebaseAuth.instance.signOut();
  }

  String _resolveCurrentUserName() {
    final fullName =
        '${CommonEntities.firstname} ${CommonEntities.lastname}'.trim();
    if (fullName.isNotEmpty) return fullName;
    if (CommonEntities.email.trim().isNotEmpty) {
      return CommonEntities.email.trim();
    }
    if (CommonEntities.mobileNumber.trim().isNotEmpty) {
      return CommonEntities.mobileNumber.trim();
    }
    if (CommonEntities.userId.trim().isNotEmpty) {
      return CommonEntities.userId.trim();
    }
    return 'User';
  }
}

class _ChatContactTile extends StatelessWidget {
  final ChatContact contact;
  final Conversation? conversation;
  final VoidCallback onTap;

  const _ChatContactTile({
    required this.contact,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = JjTheme.accent;
    final subtitle = conversation?.lastMessage.trim().isNotEmpty == true
        ? conversation!.lastMessage
        : (contact.email.trim().isNotEmpty ? contact.email.trim() : 'Tap to start chat');

    return Material(
      color: JjTheme.surface,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
                radius: 24,
                backgroundColor: primaryColor,
                child: Text(
                  _initials(contact.displayName),
                  style: const TextStyle(color: JjTheme.text, fontWeight: FontWeight.w600),
                ),
              ),
        title: Text(
          contact.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: JjTheme.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: JjTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (conversation != null)
              Text(
                _formatTime(conversation!.lastMessageAt),
                style: const TextStyle(
                  color: JjTheme.textMuted,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'now';
  }
}
