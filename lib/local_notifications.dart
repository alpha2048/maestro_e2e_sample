import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final openedNotificationPayloadProvider = StateProvider<String?>((ref) => null);

final localNotificationsControllerProvider =
    AsyncNotifierProvider<LocalNotificationsController, void>(
      LocalNotificationsController.new,
    );

class LocalNotificationsController extends AsyncNotifier<void> {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> build() async {
    await _ensureInitialized();
  }

  Future<void> _ensureInitialized() async {
    if (kIsWeb || _initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        ref.read(openedNotificationPayloadProvider.notifier).state =
            details.payload;
      },
    );

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      ref.read(openedNotificationPayloadProvider.notifier).state =
          launchDetails?.notificationResponse?.payload;
    }

    _initialized = true;
  }

  Future<bool> requestPermissionsIfNeeded() async {
    await _ensureInitialized();
    if (kIsWeb) return false;

    final ios =
        _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    final android =
        _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    final androidGranted = await android?.requestNotificationsPermission();

    final iosOk = iosGranted ?? true;
    final androidOk = androidGranted ?? true;
    return iosOk && androidOk;
  }

  Future<void> showJoke({
    required String payload,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();
    if (kIsWeb) return;

    const androidDetails = AndroidNotificationDetails(
      'jokes',
      'Jokes',
      channelDescription: 'Random jokes',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
      1 << 31,
    );
    await _plugin.show(
      notificationId,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }
}
