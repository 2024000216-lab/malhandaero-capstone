import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/schedule.dart';

/// 일정 알림 (기기 안에서 예약, 서버 필요 없음)
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'schedule_alarm',
      '일정 알림',
      channelDescription: '일정 시작 전에 알려드려요',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
  }

  /// Android 13 이상에서 알림 권한 요청 (알림을 켜고 저장할 때만 물어본다)
  static Future<void> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  static Future<void> schedule(Schedule s) async {
    if (s.id == null) return;
    await cancel(s.id!);
    final at = s.alarmTime;
    if (at == null || at.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      s.id!,
      s.allDay ? '오늘 일정이 있어요' : '10분 뒤에 일정이 있어요',
      '${s.title} · ${s.timeLabel}${s.location != null ? ' · ${s.location}' : ''}',
      tz.TZDateTime.from(at, tz.local),
      _details,
      // 정확한 알람 권한 없이 동작 (몇 분 오차가 생길 수 있음)
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
