import 'package:flutter/material.dart';
import 'package:jhol_jhal_chat/model/chat/contact_list_model.dart';
import 'package:jhol_jhal_chat/provider/chat_provider.dart';
import 'package:provider/provider.dart';

class ChatCallActions extends StatelessWidget {
  final ChatContact contact;
  final String? conversationId;

  const ChatCallActions({
    super.key,
    required this.contact,
    this.conversationId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Voice call',
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: () => _sendCallPush(context, isVideoCall: false),
        ),
        IconButton(
          tooltip: 'Video call',
          icon: const Icon(Icons.videocam, color: Colors.white),
          onPressed: () => _sendCallPush(context, isVideoCall: true),
        ),
      ],
    );
  }

  Future<void> _sendCallPush(
    BuildContext context, {
    required bool isVideoCall,
  }) async {
    final provider = context.read<ChatProvider>();
    await provider.sendCallPushNotification(
      contact: contact,
      isVideoCall: isVideoCall,
      callId: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
    );
  }
}
