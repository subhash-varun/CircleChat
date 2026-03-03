import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:jhol_jhal_chat/firebase_options.dart';
import 'package:jhol_jhal_chat/provider/chat_provider.dart';
import 'package:jhol_jhal_chat/screens/auth/auth_gate_screen.dart';
import 'package:jhol_jhal_chat/screens/chat/chat_list_screen.dart';
import 'package:jhol_jhal_chat/screens/chat/chat_screen.dart';
import 'package:jhol_jhal_chat/theme/jj_theme.dart';
import 'package:provider/provider.dart';

const AndroidNotificationChannel _androidPushChannel = AndroidNotificationChannel(
  'chat_messages',
  'Chat Messages',
  description: 'Shows incoming chat messages while app is open.',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint(
    '[PUSH_BG] messageId="${message.messageId}" data=${message.data} '
    'title="${message.notification?.title}" body="${message.notification?.body}"',
  );
}

Future<void> _configureLocalNotifications() async {
  if (kIsWeb) return;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await _localNotifications.initialize(initSettings);

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidPushChannel);

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

Future<void> _showForegroundNotification(RemoteMessage message) async {
  if (kIsWeb) return;

  final notification = message.notification;
  if (notification == null) return;

  const details = NotificationDetails(
    android: AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Shows incoming chat messages while app is open.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: DarwinNotificationDetails(),
  );

  await _localNotifications.show(
    message.messageId.hashCode,
    notification.title ?? 'New message',
    notification.body ?? '',
    details,
    payload: message.data.toString(),
  );
}

Future<void> _configurePushMessaging() async {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  final settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  debugPrint('[PUSH] permission status=${settings.authorizationStatus}');

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint(
      '[PUSH_FG] messageId="${message.messageId}" data=${message.data} '
      'title="${message.notification?.title}" body="${message.notification?.body}"',
    );
    _showForegroundNotification(message).catchError((e) {
      debugPrint('[PUSH_FG] local notification show failed: $e');
    });
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint(
      '[PUSH_OPENED] messageId="${message.messageId}" data=${message.data} '
      'title="${message.notification?.title}" body="${message.notification?.body}"',
    );
  });

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    debugPrint(
      '[PUSH_INITIAL] messageId="${initialMessage.messageId}" data=${initialMessage.data} '
      'title="${initialMessage.notification?.title}" body="${initialMessage.notification?.body}"',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _configureLocalNotifications();
  await _configurePushMessaging();
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Jhol Jhal Chat',
        theme: JjTheme.theme,
        home: const AuthGateScreen(),
        routes: {
          ChatListScreen.route: (_) => const ChatListScreen(),
          ChatScreen.route: (context) {
            final args = ModalRoute.of(context)?.settings.arguments as ChatScreenArgs?;
            return ChatScreen(
              conversationId: args?.conversationId,
              chatTitle: args?.chatTitle,
            );
          },
        },
      ),
    );
  }
}
