class ContactListModel {
  ContactListModel({
    required this.status,
    required this.message,
    required this.contacts,
  });

  final String status;
  final String message;
  final List<ChatContact> contacts;

  factory ContactListModel.fromJson(Map<String, dynamic> json) {
    final rawContacts = (json['contacts'] as List?) ?? const [];
    return ContactListModel(
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      contacts: rawContacts
          .whereType<Map<String, dynamic>>()
          .map((x) => ChatContact.fromJson(x))
          .toList(),
    );
  }
}

class ChatContact {
  ChatContact({
    required this.userRef,
    required this.fullName,
    required this.email,
  });

  final String userRef;
  final String fullName;
  final String email;

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      userRef: (json['user_ref'] ?? json['uid'] ?? '').toString().trim(),
      fullName: (json['full_name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }

  String get displayName {
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (email.trim().isNotEmpty) return email.trim();
    return 'Unknown Contact';
  }

  String get assigneeRef {
    if (userRef.isNotEmpty) return userRef;
    return displayName;
  }

  String get dedupeKey {
    if (userRef.isNotEmpty) return 'u_$userRef';
    if (email.trim().isNotEmpty) return 'e_${email.trim().toLowerCase()}';
    return 'n_${displayName.toLowerCase()}';
  }
}
