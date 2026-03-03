import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:jhol_jhal_chat/api_services/services.dart';
import 'package:jhol_jhal_chat/common/common_entities.dart';
import 'package:jhol_jhal_chat/model/chat/contact_list_model.dart';
import 'package:jhol_jhal_chat/model/chat/conversation_model.dart';
import 'package:jhol_jhal_chat/model/chat/message_model.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'jholjhalchatdb',
  );
  static const String _conversationsCollection = 'conversations';
  static const String _messagesCollection = 'messages';
  static const String _userDeviceTokensCollection = 'user_device_tokens';
  static const String _activeParticipantsField = 'active_participants';
  static const String _webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue: '',
  );
  final Services _services = Services();

  List<Conversation> _conversations = [];
  List<Message> _messages = [];
  List<ChatContact> _contacts = [];
  bool _isLoadingConversations = false;
  bool _isLoadingMessages = false;
  bool _isLoadingContacts = false;
  bool _isSendingMessage = false;

  // Getters
  List<Conversation> get conversations => _conversations;
  List<Message> get messages => _messages;
  List<ChatContact> get contacts => _contacts;
  bool get isLoadingConversations => _isLoadingConversations;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingContacts => _isLoadingContacts;
  bool get isSendingMessage => _isSendingMessage;
  String get currentUserRef => _resolveCurrentUserRef();
  String get currentSenderType => 'customer';

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _outgoingConversationsSubscription;
  StreamSubscription<QuerySnapshot>? _incomingConversationsSubscription;
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  final Map<String, Conversation> _outgoingConversations = {};
  final Map<String, Conversation> _incomingConversations = {};

  // Load conversations for current user
  Future<void> loadConversations() async {
    final currentUser = currentUserRef;
    if (currentUser.isEmpty) return;

    _isLoadingConversations = true;
    notifyListeners();

    try {
      // Cancel existing subscriptions
      await _outgoingConversationsSubscription?.cancel();
      await _incomingConversationsSubscription?.cancel();
      _outgoingConversations.clear();
      _incomingConversations.clear();

      _outgoingConversationsSubscription = _firestore
          .collection(_conversationsCollection)
          .where('customer_id', isEqualTo: currentUser)
          .orderBy('last_message_at', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _outgoingConversations
                ..clear()
                ..addEntries(
                  snapshot.docs.map((doc) {
                    final conversation = Conversation.fromFirestore(doc);
                    return MapEntry(conversation.id, conversation);
                  }),
                );
              _rebuildMergedConversations();
            },
            onError: (error) {
              debugPrint('Error in outgoing conversations stream: $error');
              _isLoadingConversations = false;
              notifyListeners();
            },
          );

      final assignedKeys = _resolveIncomingAssignmentKeys();
      final incomingQuery = _firestore.collection(_conversationsCollection);
      final Query incomingFilteredQuery = assignedKeys.length == 1
          ? incomingQuery.where('assigned_to', isEqualTo: assignedKeys.first)
          : incomingQuery.where('assigned_to', whereIn: assignedKeys);

      _incomingConversationsSubscription = incomingFilteredQuery
          .orderBy('last_message_at', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _incomingConversations
                ..clear()
                ..addEntries(
                  snapshot.docs.map((doc) {
                    final conversation = Conversation.fromFirestore(doc);
                    return MapEntry(conversation.id, conversation);
                  }),
                );
              _rebuildMergedConversations();
            },
            onError: (error) {
              debugPrint('Error in incoming conversations stream: $error');
              _isLoadingConversations = false;
              notifyListeners();
            },
          );
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      _isLoadingConversations = false;
      notifyListeners();
    }
  }

  void _rebuildMergedConversations() {
    final merged = <String, Conversation>{}
      ..addAll(_incomingConversations)
      ..addAll(_outgoingConversations);
    final mergedList = merged.values.toList()
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    _conversations = mergedList;
    _isLoadingConversations = false;
    notifyListeners();
  }

  // Load messages for a specific conversation
  Future<void> loadMessages(String conversationId) async {
    _isLoadingMessages = true;
    notifyListeners();

    try {
      // Cancel existing subscription
      await _messagesSubscription?.cancel();

      // Listen to messages in the conversation
      _messagesSubscription = _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .orderBy('created_at', descending: false)
          .snapshots()
          .listen((snapshot) {
            _messages = snapshot.docs
                .map((doc) => Message.fromFirestore(doc))
                .toList();
            _isLoadingMessages = false;
            notifyListeners();
          });
    } catch (e) {
      debugPrint('Error loading messages: $e');
      _isLoadingMessages = false;
      notifyListeners();
    }
  }

  // Send a message
  Future<bool> sendMessage({
    required String conversationId,
    required String text,
    List<File>? attachments,
    String? clientMessageId,
  }) async {
    final currentUser = currentUserRef;
    if (currentUser.isEmpty ||
        (text.trim().isEmpty && (attachments == null || attachments.isEmpty)))
      return false;

    debugPrint('Starting to send message...');
    _isSendingMessage = true;
    notifyListeners();

    try {
      // Upload attachments if any
      List<String> attachmentUrls = [];
      if (attachments != null && attachments.isNotEmpty) {
        debugPrint('Uploading ${attachments.length} attachments...');
        attachmentUrls = await _uploadAttachments(conversationId, attachments);
        debugPrint(
          'Uploaded ${attachmentUrls.length} attachments successfully',
        );
      }

      final conversationDoc = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .get();
      final conversationData = conversationDoc.data() ?? {};
      final customerRef = _asTrimmedString(conversationData['customer_id']);

      // Create message data aligned with schema.
      final messageData = {
        'sender_type': currentSenderType,
        'sender_ref': currentUser,
        'client_message_id': (clientMessageId ?? '').trim(),
        'text': text.trim(),
        'attachments': attachmentUrls,
        'created_at': FieldValue.serverTimestamp(),
        'customer_ref': customerRef.isNotEmpty ? customerRef : currentUser,
      };

      debugPrint('Adding message to Firestore...');
      // Add message to Firestore
      final messageDocRef = await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .collection(_messagesCollection)
          .add(messageData)
          .timeout(const Duration(seconds: 8));

      debugPrint('Updating conversation metadata...');
      // Update conversation metadata
      await _updateConversationMetadata(
        conversationId,
        text.trim().isEmpty ? 'Attachment' : text.trim(),
      );

      unawaited(
        _sendChatPushIfRecipientInactive(
          conversationId: conversationId,
          messageId: messageDocRef.id,
          conversationData: conversationData,
          text: text.trim(),
        ).catchError((e) {
          debugPrint('Push send failed (message is still stored): $e');
        }),
      );

      debugPrint('Message sent successfully');
      _isSendingMessage = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error sending message: $e');
      _isSendingMessage = false;
      notifyListeners();
      return false;
    }
  }

  // Create a new conversation
  Future<String?> createConversation({
    required String type, // "general", "order", "delivery"
    required String initialMessage,
    List<File>? attachments,
    String? clientMessageId,
  }) async {
    final currentUser = currentUserRef;
    if (currentUser.isEmpty) return null;

    try {
      // Create conversation data
      final conversationData = {
        'customer_id': currentUser,
        'status': 'open',
        'assigned_to': null,
        'last_message': initialMessage,
        'last_message_at': FieldValue.serverTimestamp(),
        'type': type,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Add conversation to Firestore
      final docRef = await _firestore
          .collection(_conversationsCollection)
          .add(conversationData)
          .timeout(const Duration(seconds: 8));

      // Send initial message
      await sendMessage(
        conversationId: docRef.id,
        text: initialMessage,
        attachments: attachments,
        clientMessageId: clientMessageId,
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error creating conversation: $e');
      return null;
    }
  }

  // Update conversation metadata after sending message
  Future<void> _updateConversationMetadata(
    String conversationId,
    String lastMessage,
  ) async {
    try {
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .update({
            'last_message': lastMessage,
            'last_message_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Error updating conversation metadata: $e');
    }
  }

  // Upload attachments to Firebase Storage with base64 fallback
  Future<List<String>> _uploadAttachments(
    String conversationId,
    List<File> attachments,
  ) async {
    final currentUser = currentUserRef;
    if (currentUser.isEmpty) {
      debugPrint('No authenticated user found');
      return [];
    }

    List<String> urls = [];
    debugPrint('Starting attachment upload for ${attachments.length} files');

    for (int i = 0; i < attachments.length; i++) {
      final file = attachments[i];

      try {
        // Check if file exists and is readable
        if (!await file.exists()) {
          debugPrint('File does not exist: ${file.path}');
          continue;
        }

        final fileSize = await file.length();
        debugPrint('Processing file $i: ${file.path}, size: $fileSize bytes');

        // Try Firebase Storage first
        final storageUrl = await _uploadToFirebaseStorage(
          conversationId,
          file,
          i,
        );
        if (storageUrl != null) {
          urls.add(storageUrl);
          debugPrint('Successfully uploaded file $i to Firebase Storage');
          continue;
        }

        // Fallback to base64 if Storage fails
        debugPrint(
          'Firebase Storage failed, using base64 fallback for file $i',
        );
        final base64Url = await _createBase64DataUrl(file);
        if (base64Url != null) {
          urls.add(base64Url);
          debugPrint('Successfully created base64 fallback for file $i');
        } else {
          debugPrint(
            'Both Firebase Storage and base64 fallback failed for file $i',
          );
        }
      } catch (e) {
        debugPrint('Error processing file $i: $e');
        continue;
      }
    }

    debugPrint('All attachments processed. Returning ${urls.length} URLs');
    return urls;
  }

  // Upload file to Firebase Storage
  Future<String?> _uploadToFirebaseStorage(
    String conversationId,
    File file,
    int index,
  ) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final storage = FirebaseStorage.instance;

      final ref = storage
          .ref()
          .child('conversations')
          .child(conversationId)
          .child(fileName);

      debugPrint('Uploading to Firebase Storage: $fileName');

      // Upload with metadata
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': currentUserRef,
          'conversationId': conversationId,
        },
      );

      final uploadTask = ref.putFile(file, metadata);

      // Wait for completion with timeout
      final snapshot = await uploadTask.timeout(const Duration(seconds: 30));

      if (snapshot.state == TaskState.success) {
        final downloadUrl = await ref.getDownloadURL();
        debugPrint('Firebase Storage upload successful: $downloadUrl');
        return downloadUrl;
      } else {
        debugPrint(
          'Firebase Storage upload failed with state: ${snapshot.state}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Firebase Storage upload error: $e');
      return null;
    }
  }

  Future<void> loadContacts({String searchText = ''}) async {
    _isLoadingContacts = true;
    notifyListeners();
    try {
      final currentUser = currentUserRef.trim();
      if (currentUser.isEmpty) {
        _contacts = [];
        _isLoadingContacts = false;
        notifyListeners();
        return;
      }

      final currentUserDoc = await _firestore
          .collection('users')
          .doc(currentUser)
          .get();
      final currentUserData = currentUserDoc.data() ?? <String, dynamic>{};
      final currentUserIsAdmin = currentUserData['isAdmin'] == true;
      final currentUserBubbleIds = _extractBubbleIds(currentUserData);

      final normalizedQuery = searchText.trim().toLowerCase();
      final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      if (currentUserIsAdmin) {
        final allUsers = await _firestore.collection('users').get();
        for (final doc in allUsers.docs) {
          docsById[doc.id] = doc;
        }
      } else {
        if (currentUserBubbleIds.isEmpty) {
          _contacts = [];
          _isLoadingContacts = false;
          notifyListeners();
          return;
        }

        final modernSnapshot = await _firestore
            .collection('users')
            .where(
              'bubbleIds',
              arrayContainsAny: currentUserBubbleIds.take(10).toList(),
            )
            .get();
        for (final doc in modernSnapshot.docs) {
          docsById[doc.id] = doc;
        }

        for (final bubbleId in currentUserBubbleIds) {
          final legacySnapshot = await _firestore
              .collection('users')
              .where('bubbleId', isEqualTo: bubbleId)
              .get();
          for (final doc in legacySnapshot.docs) {
            docsById[doc.id] = doc;
          }
        }

        // Keep admin users visible for all approved users.
        final adminsSnapshot = await _firestore
            .collection('users')
            .where('isAdmin', isEqualTo: true)
            .get();
        for (final doc in adminsSnapshot.docs) {
          docsById[doc.id] = doc;
        }
      }

      final contacts = docsById.values
          .where((doc) {
            final data = doc.data();
            if (doc.id == currentUser) return false;
            final isTargetAdmin = data['isAdmin'] == true;
            if (!currentUserIsAdmin && !isTargetAdmin) {
              final targetBubbleIds = _extractBubbleIds(data);
              if (targetBubbleIds.isEmpty) return false;
              final hasOverlap = currentUserBubbleIds.any(
                targetBubbleIds.contains,
              );
              if (!hasOverlap) return false;
            }
            return true;
          })
          .map((doc) {
            final data = doc.data();
            final displayName = (data['displayName'] ?? '').toString().trim();
            final email = (data['email'] ?? '').toString().trim();
            return ChatContact(
              userRef: doc.id,
              fullName: displayName,
              email: email,
            );
          })
          .where((contact) {
            final contactRef = contact.assigneeRef.trim();
            if (contactRef.isEmpty || contactRef == currentUserRef.trim())
              return false;
            if (normalizedQuery.isEmpty) return true;
            return contact.displayName.toLowerCase().contains(
                  normalizedQuery,
                ) ||
                contact.email.toLowerCase().contains(normalizedQuery) ||
                contactRef.toLowerCase().contains(normalizedQuery);
          })
          .toList();

      _contacts = _dedupeContacts(contacts);
    } catch (e) {
      debugPrint('Error loading contacts: $e');
      _contacts = [];
    }
    _isLoadingContacts = false;
    notifyListeners();
  }

  Future<String?> createOrOpenConversationWithAssignee({
    required String assignedTo,
    String type = 'general',
    String initialMessage = '',
  }) async {
    final currentUser = currentUserRef;
    if (currentUser.isEmpty || assignedTo.trim().isEmpty) return null;

    try {
      debugPrint(
        '[CHAT_PROVIDER] createOrOpen start currentUser="$currentUser" '
        'assignedTo="${assignedTo.trim()}" type="$type"',
      );
      final existingForward = await _firestore
          .collection(_conversationsCollection)
          .where('customer_id', isEqualTo: currentUser)
          .where('assigned_to', isEqualTo: assignedTo.trim())
          .orderBy('last_message_at', descending: true)
          .limit(3)
          .get();

      final existingReverse = await _firestore
          .collection(_conversationsCollection)
          .where('customer_id', isEqualTo: assignedTo.trim())
          .where('assigned_to', isEqualTo: currentUser)
          .orderBy('last_message_at', descending: true)
          .limit(3)
          .get();

      final mergedExistingDocs = <DocumentSnapshot>[
        ...existingForward.docs,
        ...existingReverse.docs,
      ];
      debugPrint(
        '[CHAT_PROVIDER] existingForward=${existingForward.docs.length} '
        'existingReverse=${existingReverse.docs.length}',
      );
      if (mergedExistingDocs.isNotEmpty) {
        mergedExistingDocs.sort((a, b) {
          final aTs =
              (a.data() as Map<String, dynamic>)['last_message_at']
                  as Timestamp?;
          final bTs =
              (b.data() as Map<String, dynamic>)['last_message_at']
                  as Timestamp?;
          final aMillis = aTs?.millisecondsSinceEpoch ?? 0;
          final bMillis = bTs?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
        debugPrint(
          '[CHAT_PROVIDER] reuse conversationId="${mergedExistingDocs.first.id}"',
        );
        return mergedExistingDocs.first.id;
      }

      final normalizedMessage = initialMessage.trim();
      final docRef = await _firestore.collection(_conversationsCollection).add({
        'customer_id': currentUser,
        'status': 'open',
        'assigned_to': assignedTo.trim(),
        'last_message': normalizedMessage,
        'last_message_at': FieldValue.serverTimestamp(),
        'type': type,
        'participants': [currentUser, assignedTo.trim()],
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (normalizedMessage.isNotEmpty) {
        await sendMessage(conversationId: docRef.id, text: normalizedMessage);
      }

      debugPrint('[CHAT_PROVIDER] created new conversationId="${docRef.id}"');
      return docRef.id;
    } catch (e) {
      debugPrint('Error creating/opening conversation with assignee: $e');
      return null;
    }
  }

  Future<void> registerCurrentDeviceToken() async {
    final currentUser = currentUserRef;
    if (currentUser.isEmpty) {
      debugPrint(
        '[CHAT_PROVIDER] registerCurrentDeviceToken skipped (empty currentUserRef)',
      );
      return;
    }

    try {
      if (kIsWeb && _webVapidKey.trim().isEmpty) {
        debugPrint(
          '[CHAT_PROVIDER] registerCurrentDeviceToken skipped on web: FIREBASE_WEB_VAPID_KEY is not set.',
        );
        return;
      }

      final token = await FirebaseMessaging.instance
          .getToken(vapidKey: kIsWeb ? _webVapidKey.trim() : null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (token == null || token.isEmpty) return;

      final docId = '${currentUser}_${token.hashCode}';
      debugPrint(
        '[CHAT_PROVIDER] registerCurrentDeviceToken userRef="$currentUser" '
        'token="$token" '
        'platform=${Platform.isIOS ? 'ios' : 'android'} docId="$docId"',
      );
      await _firestore.collection(_userDeviceTokensCollection).doc(docId).set({
        'customer_ref': currentUser,
        'device_token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      }, SetOptions(merge: true));

      final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      await _services.api.registerDeviceToken(
        userRef: currentUser,
        token: token,
        platform: platform,
      );
    } catch (e) {
      debugPrint('Error registering device token: $e');
    }
  }

  Future<void> setConversationActiveState({
    required String conversationId,
    required bool isActive,
  }) async {
    final currentUser = currentUserRef.trim();
    if (conversationId.trim().isEmpty || currentUser.isEmpty) return;

    try {
      await _firestore
          .collection(_conversationsCollection)
          .doc(conversationId)
          .set({
            _activeParticipantsField: isActive
                ? FieldValue.arrayUnion([currentUser])
                : FieldValue.arrayRemove([currentUser]),
            'updated_at': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating conversation active state: $e');
    }
  }

  String _resolveCurrentUserRef() {
    if (CommonEntities.userId.trim().isNotEmpty)
      return CommonEntities.userId.trim();
    if (CommonEntities.mobileNumber.trim().isNotEmpty)
      return CommonEntities.mobileNumber.trim();
    if (CommonEntities.email.trim().isNotEmpty)
      return CommonEntities.email.trim();
    return '';
  }

  List<String> _resolveIncomingAssignmentKeys() {
    final keys = <String>{};
    final userRef = currentUserRef;
    if (userRef.isNotEmpty) keys.add(userRef);
    return keys.toList();
  }

  List<ChatContact> _dedupeContacts(List<ChatContact> input) {
    final Map<String, ChatContact> byKey = <String, ChatContact>{};
    for (final contact in input) {
      byKey.putIfAbsent(contact.dedupeKey, () => contact);
    }
    final deduped = byKey.values.toList();
    deduped.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return deduped;
  }

  Future<void> _sendChatPushIfRecipientInactive({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> conversationData,
    required String text,
  }) async {
    final currentUser = currentUserRef.trim();
    if (currentUser.isEmpty) return;

    final customerRef = _asTrimmedString(conversationData['customer_id']);
    final assignedTo = _asTrimmedString(conversationData['assigned_to']);
    if (customerRef.isEmpty && assignedTo.isEmpty) return;

    String recipientRef = '';
    if (currentUser == customerRef) {
      recipientRef = assignedTo;
    } else if (currentUser == assignedTo) {
      recipientRef = customerRef;
    } else {
      recipientRef = assignedTo.isNotEmpty ? assignedTo : customerRef;
    }
    debugPrint(
      'recipientRef="$recipientRef" assignedTo="$assignedTo" customerRef="$customerRef"',
    );
    if (recipientRef.isEmpty) return;
    final activeParticipantsRaw = conversationData[_activeParticipantsField];
    final activeParticipants = (activeParticipantsRaw is List)
        ? activeParticipantsRaw
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
        : <String>{};

    if (activeParticipants.contains(recipientRef)) {
      debugPrint(
        '[CHAT_PROVIDER] skip push for "$conversationId" because recipient "$recipientRef" is active',
      );
      return;
    }

    final pushMessage = text.isNotEmpty ? text : 'Sent an attachment';
    final senderName = _resolveCallerName();
    await _services.api.sendMessagePush(
      recipientRef: recipientRef,
      senderRef: currentUser,
      conversationId: conversationId,
      messageId: messageId,
      title: senderName,
      body: pushMessage,
      data: {'type': 'chat_message'},
    );
  }

  Future<void> sendCallPushNotification({
    required ChatContact contact,
    required bool isVideoCall,
    required String callId,
    String? conversationId,
  }) async {
    final recipientRef = contact.assigneeRef.trim();
    if (recipientRef.isEmpty) return;

    final callKind = isVideoCall ? 'video' : 'voice';
    final callerName = _resolveCallerName();
    final callerId = currentUserRef.trim();
    final normalizedCallId = callId.trim();
    if (normalizedCallId.isEmpty) {
      debugPrint('[CHAT_PROVIDER] call push skipped: call_id is empty');
      return;
    }
    final normalizedConversationId = (conversationId ?? '').trim();
    await _services.api.sendMessagePush(
      recipientRef: recipientRef,
      senderRef: callerId,
      conversationId: normalizedConversationId.isNotEmpty
          ? normalizedConversationId
          : 'direct_call',
      messageId: normalizedCallId,
      title: '$callerName is calling',
      body: 'Incoming $callKind call',
      data: {'type': 'incoming_call', 'call_type': callKind},
    );
  }

  String _resolveCallerName() {
    final fullName = '${CommonEntities.firstname} ${CommonEntities.lastname}'
        .trim();
    if (fullName.isNotEmpty) return fullName;
    if (CommonEntities.email.trim().isNotEmpty)
      return CommonEntities.email.trim();
    if (CommonEntities.mobileNumber.trim().isNotEmpty)
      return CommonEntities.mobileNumber.trim();
    if (CommonEntities.userId.trim().isNotEmpty)
      return CommonEntities.userId.trim();
    return 'User';
  }

  String _asTrimmedString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  List<String> _extractBubbleIds(Map<String, dynamic> userData) {
    final normalized = <String>{};
    final rawList = userData['bubbleIds'];
    if (rawList is List) {
      for (final value in rawList) {
        final id = _asTrimmedString(value).toLowerCase();
        if (id.isNotEmpty) normalized.add(id);
      }
    }

    final legacy = _asTrimmedString(userData['bubbleId']).toLowerCase();
    if (legacy.isNotEmpty) normalized.add(legacy);
    return normalized.toList()..sort();
  }

  // Create base64 data URL as fallback
  Future<String?> _createBase64DataUrl(File file) async {
    try {
      final fileBytes = await file.readAsBytes();
      final base64String = base64Encode(fileBytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';
      return dataUrl;
    } catch (e) {
      debugPrint('Base64 fallback error: $e');
      return null;
    }
  }

  // Clear current messages (when switching conversations)
  void clearMessages() {
    _messages = [];
    notifyListeners();
  }

  // Dispose subscriptions
  @override
  void dispose() {
    _outgoingConversationsSubscription?.cancel();
    _incomingConversationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}
