import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:jhol_jhal_chat/api_services/services.dart';
import 'package:jhol_jhal_chat/common/common_entities.dart';
import 'package:jhol_jhal_chat/screens/chat/chat_list_screen.dart';
import 'package:jhol_jhal_chat/services/user_presence_service.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});
  static const String _webVapidKey = String.fromEnvironment(
    'FIREBASE_WEB_VAPID_KEY',
    defaultValue: '',
  );

  static final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'jholjhalchatdb',
  );
  static final Services _services = Services();

  static Future<void> storeCurrentDeviceToken(String uid) async {
    if (uid.trim().isEmpty) return;
    try {
      if (kIsWeb && _webVapidKey.trim().isEmpty) {
        debugPrint(
          'Skipping web FCM token registration: FIREBASE_WEB_VAPID_KEY is not set.',
        );
        return;
      }
      final token = await FirebaseMessaging.instance
          .getToken(vapidKey: kIsWeb ? _webVapidKey.trim() : null)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (token == null || token.trim().isEmpty) return;

      final platform = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';
      final docId = '${uid}_${token.hashCode}';
      debugPrint(
        '[AUTH_GATE] storeCurrentDeviceToken generated token '
        'uid="$uid" platform="$platform" len=${token.length} '
        'token="$token" docId="$docId"',
      );

      await _firestore.collection('user_device_tokens').doc(docId).set({
        'customer_ref': uid,
        'device_token': token.trim(),
        'platform': platform,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _services.api
          .registerDeviceToken(
            userRef: uid,
            token: token.trim(),
            platform: platform,
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error storing current device token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _CenteredLoader();
        }

        final user = authSnapshot.data;
        if (user == null) {
          CommonEntities.clearUser();
          return const AuthScreen();
        }

        CommonEntities.applyFirebaseUser(user);
        final usersRef = _firestore.collection('users').doc(user.uid);

        return FutureBuilder<void>(
          future: _ensureUserProfile(user),
          builder: (context, ensureSnapshot) {
            if (ensureSnapshot.connectionState == ConnectionState.waiting) {
              return const _CenteredLoader();
            }

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: usersRef.snapshots(),
              builder: (context, userDocSnapshot) {
                if (userDocSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const _CenteredLoader();
                }

                final data = userDocSnapshot.data?.data();
                final isAdmin = data?['isAdmin'] == true;
                final chatApproved = data?['chatApproved'] == true;
                if (isAdmin || chatApproved) {
                  return const ChatListScreen();
                }

                return const PendingApprovalScreen();
              },
            );
          },
        );
      },
    );
  }

  Future<void> _ensureUserProfile(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'email': (user.email ?? '').trim(),
        'displayName': (user.displayName ?? '').trim(),
        'isAdmin': false,
        'chatApproved': false,
        'verificationStatus': 'pending',
        'bubbleId': '',
        'bubbleIds': <String>[],
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    unawaited(UserPresenceService.markOnline(user.uid));
    unawaited(storeCurrentDeviceToken(user.uid));
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const Duration _authTimeout = Duration(seconds: 8);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSignup = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSignup ? 'Create account' : 'Login';
    final buttonLabel = _isSignup ? 'Sign up' : 'Sign in';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isSignup)
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if (!_isSignup) return null;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return 'Email is required';
                        if (!email.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (value) {
                        final password = (value ?? '').trim();
                        if (password.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(buttonLabel),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() => _isSignup = !_isSignup);
                            },
                      child: Text(
                        _isSignup
                            ? 'Already have an account? Sign in'
                            : 'No account? Sign up',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    try {
      if (_isSignup) {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password)
            .timeout(_authTimeout);

        if (name.isNotEmpty) {
          await cred.user?.updateDisplayName(name);
        }

        if (cred.user != null) {
          await AuthGateScreen._firestore
              .collection('users')
              .doc(cred.user!.uid)
              .set({
                'email': email,
                'displayName': name,
                'isAdmin': false,
                'chatApproved': false,
                'verificationStatus': 'pending',
                'bubbleId': '',
                'bubbleIds': <String>[],
                'isOnline': false,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          await _notifyAdminsAboutApprovalRequest(
            newUserRef: cred.user!.uid,
            name: name,
            email: email,
          );
          await UserPresenceService.markOnline(cred.user!.uid);
          await AuthGateScreen.storeCurrentDeviceToken(cred.user!.uid);
        }
      } else {
        final cred = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password)
            .timeout(_authTimeout);
        if (cred.user != null) {
          await UserPresenceService.markOnline(cred.user!.uid);
          await AuthGateScreen.storeCurrentDeviceToken(cred.user!.uid);
        }
      }
    } on TimeoutException {
      _showError('Request timed out. Check internet and try again.');
    } on FirebaseAuthException catch (e) {
      _showError(_mapAuthError(e));
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'Please enter a valid email.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'email-already-in-use':
        return 'This email is already registered. Please sign in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check internet and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _notifyAdminsAboutApprovalRequest({
    required String newUserRef,
    required String name,
    required String email,
  }) async {
    try {
      final adminsSnapshot = await AuthGateScreen._firestore
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      if (adminsSnapshot.docs.isEmpty) return;

      final candidateName = name.trim().isNotEmpty ? name.trim() : email.trim();
      final label = candidateName.isNotEmpty ? candidateName : newUserRef;

      for (final admin in adminsSnapshot.docs) {
        await AuthGateScreen._services.api.sendMessagePush(
          recipientRef: admin.id,
          senderRef: newUserRef,
          conversationId: 'admin_approval',
          messageId:
              'approval_${DateTime.now().millisecondsSinceEpoch}_$newUserRef',
          title: 'New approval request',
          body: '$label signed up and is waiting for verification',
          data: {
            'type': 'approval_request',
            'request_user_ref': newUserRef,
            'request_user_email': email.trim(),
            'request_user_name': name.trim(),
          },
        );
      }
    } catch (e) {
      debugPrint(
        '[AUTH_GATE] Failed to notify admins for approval request: $e',
      );
    }
  }
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  Future<void> _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (uid.trim().isNotEmpty && (token ?? '').trim().isNotEmpty) {
        await AuthGateScreen._services.api.unregisterDeviceToken(
          userRef: uid,
          token: token!.trim(),
        );
      }
    } catch (e) {
      debugPrint('[PENDING_APPROVAL] unregister token on logout failed: $e');
    }
    await UserPresenceService.markOffline(uid);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification pending'),
        actions: [
          TextButton(onPressed: _logout, child: const Text('Sign out')),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Your account is created but not verified yet. '
              'Once approved, chat will be enabled automatically.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
