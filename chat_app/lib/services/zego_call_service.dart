import 'package:flutter/foundation.dart';

class ZegoCallService {
  ZegoCallService._();

  static final ZegoCallService instance = ZegoCallService._();

  void initializeForCurrentUser({
    required String userId,
    required String userName,
  }) {
    debugPrint(
      '[ZEGO_STUB] initialize userId="$userId" userName="$userName"',
    );
  }
}
