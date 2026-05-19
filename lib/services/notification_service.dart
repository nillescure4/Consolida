import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Madrid'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Obrir',
    );

    const windowsSettings = WindowsInitializationSettings(
      appName: 'Consolida',
      appUserModelId: 'com.example.tfg_app',
      guid: 'b0dd2fc7-40e8-4b7e-9d77-7ce7e73b7a12',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    await _plugin.initialize(
      settings: settings,
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    _initialized = true;
  }

  static Future<void> showInstantPendingPracticeNotification({
    required String subjectName,
    required String goalTitle,
  }) async {
    await initialize();

    await _plugin.show(
      id: 999999,
      title: 'Pràctica disponible: $subjectName',
      body: 'Ja tens una pràctica pendent de l’objectiu: $goalTitle',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'instant_practice_channel',
          'Pràctiques immediates',
          channelDescription:
              'Notificacions immediates de pràctiques disponibles.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
    );
  }

  static Future<void> cancelSubjectNotifications(String subjectId) async {
    await initialize();

    await _plugin.cancel(
      id: _notificationId(subjectId),
    );
  }

  static Future<void> scheduleDailyPendingPracticeNotification({
    required String subjectId,
    required String subjectName,
    required String goalTitle,
    int hour = 9,
    int minute = 0,
  }) async {
    await initialize();

    await cancelSubjectNotifications(subjectId);

    await _plugin.zonedSchedule(
      id: _notificationId(subjectId),
      title: 'Pràctica pendent: $subjectName',
      body: 'Avui tens una pràctica pendent de l’objectiu: $goalTitle',
      scheduledDate: _nextInstanceOfTime(
        hour: hour,
        minute: minute,
      ),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pending_practice_channel',
          'Pràctiques pendents',
          channelDescription: 'Avisos diaris quan hi ha pràctiques pendents.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
        linux: LinuxNotificationDetails(),
        windows: WindowsNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static tz.TZDateTime _nextInstanceOfTime({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(
        const Duration(days: 1),
      );
    }

    return scheduledDate;
  }

  static int _notificationId(String subjectId) {
    return subjectId.hashCode.abs() % 2147483647;
  }
}