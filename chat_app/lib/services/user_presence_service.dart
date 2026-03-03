import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class UserPresenceService {
  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'jholjhalchatdb');

  static Future<void> markOnline(String userRef) async {
    await _setStatus(userRef, isOnline: true);
  }

  static Future<void> markOffline(String userRef) async {
    await _setStatus(userRef, isOnline: false);
  }

  static Future<void> _setStatus(
    String userRef, {
    required bool isOnline,
  }) async {
    final uid = userRef.trim();
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).set({
        'isOnline': isOnline,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PRESENCE] Failed to update online status for "$uid": $e');
    }
  }
}

