import 'package:firebase_auth/firebase_auth.dart';

class CommonEntities {
  static String userId = '';
  static String mobileNumber = '';
  static String email = '';
  static String firstname = '';
  static String lastname = '';

  static String appThemeColor = '#137D73';
  static String appBackgroundColor = '#F4F7F8';
  static String appLightGreyColor = '#F1F3F4';

  static void applyFirebaseUser(User user) {
    userId = user.uid;
    email = (user.email ?? '').trim();
    mobileNumber = (user.phoneNumber ?? '').trim();

    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      final parts = displayName.split(RegExp(r'\s+'));
      firstname = parts.first;
      lastname = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      return;
    }

    if (firstname.trim().isEmpty) {
      firstname = 'User';
    }
    if (lastname.trim().isEmpty) {
      lastname = '';
    }
  }

  static void clearUser() {
    userId = '';
    mobileNumber = '';
    email = '';
    firstname = '';
    lastname = '';
  }
}
