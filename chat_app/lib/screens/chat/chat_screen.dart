import 'dart:convert';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jhol_jhal_chat/model/chat/conversation_model.dart';
import 'package:jhol_jhal_chat/model/chat/message_model.dart';
import 'package:jhol_jhal_chat/provider/chat_provider.dart';
import 'package:jhol_jhal_chat/theme/jj_theme.dart';
import 'package:provider/provider.dart';

class ChatScreenArgs {
  final String conversationId;
  final String? chatTitle;

  const ChatScreenArgs({required this.conversationId, this.chatTitle});
}

class ChatScreen extends StatefulWidget {
  static const String route = 'chat_screen';

  final String? conversationId;
  final String? chatTitle;

  const ChatScreen({super.key, this.conversationId, this.chatTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _QueuedOutgoingMessage {
  _QueuedOutgoingMessage({
    required this.localMessageId,
    required this.text,
    required this.attachments,
  });

  final String localMessageId;
  final String text;
  final List<File> attachments;
}

enum _LocalMessageStatus {
  sending,
  failed,
}

class _LocalPendingMessage {
  _LocalPendingMessage({
    required this.id,
    required this.text,
    required this.attachments,
    required this.createdAt,
  }) : status = _LocalMessageStatus.sending;

  final String id;
  final String text;
  final List<File> attachments;
  final DateTime createdAt;
  _LocalMessageStatus status;
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _pendingAttachments = []; // Attachments selected in composer
  final List<_LocalPendingMessage> _localPendingMessages = [];
  final Queue<_QueuedOutgoingMessage> _outgoingQueue = Queue<_QueuedOutgoingMessage>();
  bool _isQueueProcessing = false;

  late String? _conversationId = widget.conversationId;
  ChatProvider? _chatProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_conversationId != null && _conversationId != 'new') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatProvider = _chatProvider;
        if (chatProvider == null) return;
        chatProvider.clearMessages();
        chatProvider.loadMessages(_conversationId!);
        chatProvider.setConversationActiveState(
          conversationId: _conversationId!,
          isActive: true,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProvider ??= context.read<ChatProvider>();
  }

  @override
  void dispose() {
    final conversationId = _conversationId;
    if (conversationId != null && conversationId != 'new' && _chatProvider != null) {
      _chatProvider!.setConversationActiveState(
        conversationId: conversationId,
        isActive: false,
      );
    }
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final conversationId = _conversationId;
    final chatProvider = _chatProvider;
    if (conversationId == null || conversationId == 'new') return;
    if (chatProvider == null) return;
    if (state == AppLifecycleState.resumed) {
      chatProvider.setConversationActiveState(
        conversationId: conversationId,
        isActive: true,
      );
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      chatProvider.setConversationActiveState(
        conversationId: conversationId,
        isActive: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final conversation = _resolveConversation(chatProvider);
    final title = _chatTitle(conversation);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: JjTheme.deep,
      appBar: AppBar(
        backgroundColor: JjTheme.surface,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: JjTheme.surfaceHover,
              child: const Icon(Icons.chat_bubble, color: JjTheme.text),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: JjTheme.text,
                  ),
                ),
                // Text(
                //   subtitle,
                //   style: const TextStyle(
                //     fontSize: 12,
                //     color: Colors.white,
                //   ),
                // ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: JjTheme.text),
        // actions: [
        //   if (counterparty != null)
        //     Padding(
        //       padding: const EdgeInsets.only(right: 10),
        //       child: Center(
        //         child: ChatCallActions(
        //           contact: counterparty,
        //           conversationId: _conversationId,
        //         ),
        //       ),
        //     ),
        // ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, chatProvider, child) {
                  if (chatProvider.isLoadingMessages) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final confirmedClientIds = chatProvider.messages
                      .map((m) => m.clientMessageId.trim())
                      .where((id) => id.isNotEmpty)
                      .toSet();
                  final visibleLocalPending = _localPendingMessages
                      .where((m) => !confirmedClientIds.contains(m.id))
                      .toList();

                  if (chatProvider.messages.isEmpty &&
                      _pendingAttachments.isEmpty &&
                      visibleLocalPending.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: JjTheme.textMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style: const TextStyle(
                              fontSize: 18,
                              color: JjTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start the conversation',
                            style: const TextStyle(
                              fontSize: 14,
                              color: JjTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final pendingDisplay = visibleLocalPending.reversed.toList();
                  final pendingCount = pendingDisplay.length;
                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true, // 🔥 IMPORTANT
                    padding: const EdgeInsets.all(12),
                    itemCount: chatProvider.messages.length + pendingCount,
                    itemBuilder: (context, index) {
                      if (index < pendingCount) {
                        return _LocalPendingMessageBubble(
                          pendingMessage: pendingDisplay[index],
                          onRetry: pendingDisplay[index].status == _LocalMessageStatus.failed
                              ? () => _retryPendingMessage(pendingDisplay[index].id)
                              : null,
                        );
                      }

                      final messageIndex = index - pendingCount;
                      final totalMessages = chatProvider.messages.length;
                      final reversedIndex = totalMessages - 1 - messageIndex;

                      final message = chatProvider.messages[
                          reversedIndex];

                      final showAvatar = reversedIndex == totalMessages - 1 ||
                          chatProvider.messages[reversedIndex + 1].senderType !=
                              message.senderType;

                      final isOwnMessage = _isOwnMessage(
                        message: message,
                        currentUserRef: chatProvider.currentUserRef,
                      );

                      return _MessageBubble(
                        message: message,
                        isOwnMessage: isOwnMessage,
                        showAvatar: showAvatar,
                        onImageTap: _showFullScreenImage,
                      );
                    },
                  );                },
              ),
            ),
            SafeArea(
              top: false,
              child: _buildMessageInput(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      color: JjTheme.deep,
      padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 6),
      child: Column(
        children: [
          // Text input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Text field - takes all available space
              Expanded(
                flex: 1,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 36,
                    maxHeight: 100,
                  ),
                  decoration: BoxDecoration(
                    color: JjTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: JjTheme.border),
                  ),
                  child: Row(
                    children: [
                      // Attachment button inside text field
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          icon: const Icon(Icons.attach_file, color: JjTheme.textSecondary, size: 20),
                          onPressed: _pickImages,
                          padding: EdgeInsets.zero,
                        ),
                      ),

                      // Text field takes remaining space
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) {
                            if (mounted) setState(() {});
                          },
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: JjTheme.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 14, color: JjTheme.text),
                        ),
                      ),

                      // Send button inside text field
                      Consumer<ChatProvider>(
                        builder: (context, chatProvider, child) {
                          final hasText = _messageController.text.trim().isNotEmpty;
                          final hasPendingAttachments = _pendingAttachments.isNotEmpty;

                          return SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              icon: Icon(
                                Icons.send,
                                color: (hasText || hasPendingAttachments)
                                    ? JjTheme.accent
                                    : JjTheme.textMuted,
                                size: 20,
                              ),
                              onPressed: (hasText || hasPendingAttachments)
                                  ? _sendMessage
                                  : null,
                              padding: EdgeInsets.zero,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    final attachments = List<File>.from(_pendingAttachments);
    if (text.isEmpty && attachments.isEmpty) return;

    _messageController.clear();
    setState(() {
      _pendingAttachments.clear();
    });

    _enqueueOutgoingMessage(text: text, attachments: attachments);
  }

  // Send only pending attachments automatically (WhatsApp-like behavior)
  Future<void> _sendPendingAttachments() async {
    if (_pendingAttachments.isEmpty) return;
    final attachments = List<File>.from(_pendingAttachments);
    setState(() {
      _pendingAttachments.clear();
    });
    _enqueueOutgoingMessage(text: '', attachments: attachments);
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      _scrollController.animateTo(
        0.0, // 🔥 because reverse: true
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
  }

  // void _scrollToBottomWithRetry({bool animated = true, int attempts = 8}) {
  //   if (_scrollController.hasClients) {
  //     _scrollToBottom(animated: animated);
  //     return;
  //   }
  //   if (attempts <= 0) return;
  //   Future.delayed(const Duration(milliseconds: 80), () {
  //     if (!mounted) return;
  //     _scrollToBottomWithRetry(animated: animated, attempts: attempts - 1);
  //   });
  // }

  Future<void> _pickImages() async {
    try {
      debugPrint('Picking images...');
      final pickedFiles = await _imagePicker.pickMultiImage();
      debugPrint('Picked ${pickedFiles.length} files');

      if (pickedFiles.isNotEmpty) {
        List<File> validFiles = [];
        for (var xFile in pickedFiles) {
          debugPrint('Processing file: ${xFile.path}');
          if (xFile.path.isNotEmpty) {
            final file = File(xFile.path);
            if (await file.exists()) {
              debugPrint('File exists: ${file.path}');
              validFiles.add(file);
            } else {
              debugPrint('File does not exist: ${file.path}');
            }
          }
        }

        if (validFiles.isNotEmpty) {
          setState(() {
            _pendingAttachments.addAll(validFiles);
          });
          debugPrint('Added ${validFiles.length} valid files to pending attachments');

          // Scroll to bottom to show the pending attachments
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          });

          // Automatically send the images (WhatsApp-like behavior)
          debugPrint('Automatically sending images...');
          await _sendPendingAttachments();
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  void _showFullScreenImage(String url) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Full screen image
              InteractiveViewer(
                child: Center(
                  child: url.startsWith('data:image/')
                      ? _buildFullScreenBase64Image(url)
                      : _buildFullScreenNetworkImage(url),
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 30,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullScreenBase64Image(String url) {
    try {
      final base64Data = url.split(',')[1];
      final decodedBytes = base64Decode(base64Data);
      return Image.memory(
        decodedBytes,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.white,
              size: 64,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error decoding full-screen base64 image: $e');
      return const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.white,
          size: 64,
        ),
      );
    }
  }

  Widget _buildFullScreenNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.white,
            size: 64,
          ),
        );
      },
    );
  }

  bool _isOwnMessage({
    required Message message,
    required String currentUserRef,
  }) {
    if (message.senderType == 'system') return false;
    final senderRef = message.senderRef.trim();
    if (senderRef.isNotEmpty) {
      return senderRef == currentUserRef.trim();
    }
    // Backward compatibility for older messages without sender_ref.
    return message.senderType == 'customer';
  }

  Conversation? _resolveConversation(ChatProvider provider) {
    if (_conversationId == null || _conversationId == 'new') return null;
    for (final conversation in provider.conversations) {
      if (conversation.id == _conversationId) return conversation;
    }
    return null;
  }

  String _chatTitle(Conversation? conversation) {
    final providedTitle = widget.chatTitle?.trim() ?? '';
    if (providedTitle.isNotEmpty) return providedTitle;
    final assignedTo = conversation?.assignedTo?.trim() ?? '';
    if (assignedTo.isNotEmpty) return assignedTo;
    return 'Conversation';
  }

  void _enqueueOutgoingMessage({
    required String text,
    required List<File> attachments,
  }) {
    final normalizedText = text.trim();
    if (normalizedText.isEmpty && attachments.isEmpty) return;
    final localId = DateTime.now().microsecondsSinceEpoch.toString();
    final localPendingMessage = _LocalPendingMessage(
      id: localId,
      text: normalizedText,
      attachments: List<File>.from(attachments),
      createdAt: DateTime.now(),
    );

    setState(() {
      _localPendingMessages.add(localPendingMessage);
      _outgoingQueue.add(
        _QueuedOutgoingMessage(
          localMessageId: localId,
          text: normalizedText,
          attachments: List<File>.from(attachments),
        ),
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    _processOutgoingQueue();
  }

  Future<void> _processOutgoingQueue() async {
    if (_isQueueProcessing || !mounted) return;

    setState(() {
      _isQueueProcessing = true;
    });

    final provider = context.read<ChatProvider>();
    while (mounted && _outgoingQueue.isNotEmpty) {
      final item = _outgoingQueue.first;
      bool success = false;
      try {
        if (_conversationId == null || _conversationId == 'new') {
          final newId = await provider
              .createConversation(
                type: 'general',
                initialMessage: item.text,
                attachments: item.attachments,
                clientMessageId: item.localMessageId,
              )
              .timeout(const Duration(seconds: 20), onTimeout: () => null);
          if (newId != null) {
            _conversationId = newId;
            success = true;
            await provider.loadMessages(newId);
            await provider.setConversationActiveState(
              conversationId: newId,
              isActive: true,
            );
          }
        } else {
          success = await provider
              .sendMessage(
                conversationId: _conversationId!,
                text: item.text,
                attachments: item.attachments,
                clientMessageId: item.localMessageId,
              )
              .timeout(const Duration(seconds: 20), onTimeout: () => false);
        }
      } catch (e) {
        debugPrint('Queue send exception for ${item.localMessageId}: $e');
        success = false;
      }

      if (!success) {
        _markLocalMessageFailed(item.localMessageId);
        _outgoingQueue.removeFirst();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message failed to send. Tap failed bubble to retry.'),
            ),
          );
        }
        continue;
      }

      _outgoingQueue.removeFirst();
      _removeLocalPendingMessage(item.localMessageId);
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }

    if (mounted) {
      setState(() {
        _isQueueProcessing = false;
      });
    }
  }

  void _markLocalMessageFailed(String localMessageId) {
    if (!mounted) return;
    setState(() {
      for (final message in _localPendingMessages) {
        if (message.id == localMessageId) {
          message.status = _LocalMessageStatus.failed;
          break;
        }
      }
    });
  }

  void _removeLocalPendingMessage(String localMessageId) {
    if (!mounted) return;
    setState(() {
      _localPendingMessages.removeWhere((message) => message.id == localMessageId);
    });
  }

  void _retryPendingMessage(String localMessageId) {
    final index = _localPendingMessages.indexWhere((m) => m.id == localMessageId);
    if (index < 0) return;
    final localMessage = _localPendingMessages[index];
    setState(() {
      localMessage.status = _LocalMessageStatus.sending;
      _outgoingQueue.addFirst(
        _QueuedOutgoingMessage(
          localMessageId: localMessage.id,
          text: localMessage.text,
          attachments: List<File>.from(localMessage.attachments),
        ),
      );
    });
    _processOutgoingQueue();
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isOwnMessage;
  final bool showAvatar;
  final void Function(String url)? onImageTap;

  const _MessageBubble({
    required this.message,
    required this.isOwnMessage,
    this.showAvatar = true,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCustomer = isOwnMessage;
    final primaryColor = JjTheme.accent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: isCustomer ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages
          if (!isCustomer)
            Container(
              margin: const EdgeInsets.only(right: 6, bottom: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: primaryColor,
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),

          // Message bubble
          Flexible(
            child: Container(
              margin: EdgeInsets.only(
                left: isCustomer ? 40 : 0,
                right: isCustomer ? 0 : 40,
                bottom: 4,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.6,
                minWidth: 80,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCustomer
                    ? JjTheme.accentSoft
                    : JjTheme.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isCustomer ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: isCustomer ? const Radius.circular(4) : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attachments
                  if (message.attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: message.attachments
                            .map((url) => _buildAttachmentImage(url, onTap: () => onImageTap?.call(url)))
                            .toList(),
                      ),
                    ),

                  // Message text
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        fontSize: 14,
                        color: JjTheme.text,
                      ),
                    ),

                  // Timestamp
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: JjTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar for sent messages (usually not shown in WhatsApp, but optional)
          // if (isCustomer && showAvatar)
          if (isCustomer)
            Container(
              margin: const EdgeInsets.only(left: 6, bottom: 4),
              child: CircleAvatar(
                radius: 14,
                backgroundColor: JjTheme.surfaceHover,
                child: const Icon(
                  Icons.person,
                  color: JjTheme.textSecondary,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildAttachmentImage(String url, {VoidCallback? onTap}) {
    Widget imageWidget;

    // Handle base64 data URLs
    if (url.startsWith('data:image/')) {
      try {
        // Extract base64 data from data URL
        final base64Data = url.split(',')[1];
        final decodedBytes = base64Decode(base64Data);

        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: JjTheme.border, width: 1),
            ),
            child: Image.memory(
              decodedBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: JjTheme.surfaceHover,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: JjTheme.textMuted,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
        imageWidget = Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: JjTheme.border, width: 1),
          ),
          child: const Center(
            child: Icon(
              Icons.broken_image,
              color: JjTheme.textMuted,
              size: 24,
            ),
          ),
        );
      }
    } else {
      // Handle regular URLs
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: JjTheme.border, width: 1),
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: JjTheme.surfaceHover,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: JjTheme.surfaceHover,
                child: const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: JjTheme.textMuted,
                    size: 24,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Make the image tappable to open full-screen view
    return GestureDetector(
      onTap: onTap,
      child: imageWidget,
    );
  }
}

class _LocalPendingMessageBubble extends StatelessWidget {
  const _LocalPendingMessageBubble({
    required this.pendingMessage,
    this.onRetry,
  });

  final _LocalPendingMessage pendingMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isFailed = pendingMessage.status == _LocalMessageStatus.failed;
    final statusIcon = isFailed ? Icons.error_outline : Icons.schedule;
    final statusColor = isFailed ? JjTheme.secure : JjTheme.textSecondary;
    final statusLabel = isFailed ? 'Failed. Tap to retry' : 'Sending...';
    final bubble = Container(
      margin: const EdgeInsets.only(left: 40, bottom: 4),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.6,
        minWidth: 80,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: JjTheme.accentSoft,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (pendingMessage.attachments.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: List.generate(
                pendingMessage.attachments.length,
                (index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: JjTheme.border, width: 1),
                    ),
                    child: Image.file(
                      pendingMessage.attachments[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          if (pendingMessage.text.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: pendingMessage.attachments.isNotEmpty ? 6 : 0),
              child: Text(
                pendingMessage.text,
                style: const TextStyle(
                  fontSize: 14,
                  color: JjTheme.text,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: isFailed
                ? InkWell(onTap: onRetry, borderRadius: BorderRadius.circular(12), child: bubble)
                : bubble,
          ),
        ],
      ),
    );
  }
}
