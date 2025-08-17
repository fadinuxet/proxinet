import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'notification_service.dart';
import 'package:proxinet/proxinet/proxinet_router.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final title = message.notification?.title ?? 'New alert';
  final body = message.notification?.body ?? 'You have a new notification';
  final notifier = GetIt.instance<NotificationService>();
  await notifier.init();
  await notifier.showNow(title: title, body: body);
}

Future<void> setupPushHandlers() async {
  FirebaseMessaging.onMessage.listen((message) async {
    final title = message.notification?.title ?? 'New alert';
    final body = message.notification?.body ?? 'You have a new notification';
    final notifier = GetIt.instance<NotificationService>();
    await notifier.init();
    await notifier.showNow(title: title, body: body);
  });
  FirebaseMessaging.onMessageOpenedApp.listen((message) async {
    final route = message.data['route'] as String?;
    if (route != null) {
      ProxinetRouter.navKey.currentState?.pushNamed(route);
    }
  });
}
