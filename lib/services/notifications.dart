import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/expiry.dart';
import '../core/labels.dart';
import '../core/models.dart';
import '../data/store.dart';
import '../l10n/l10n.dart';

/// Nhắc hạn bằng thông báo cục bộ. Mỗi lần dữ liệu đổi: huỷ hết rồi lên lịch lại
/// (iOS giới hạn 64 thông báo chờ, nên chỉ giữ 60 mốc gần nhất).
class LocalReminders implements ReminderSync {
  final _plugin = FlutterLocalNotificationsPlugin();
  int hour = 9;
  bool _ready = false;

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // Ứng dụng hướng tới người dùng Việt Nam; dùng giờ Việt Nam cố định.
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
            requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    final a = await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final i = await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return (a ?? true) && (i ?? true);
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('expiry', 'Nhắc hạn giấy tờ',
        channelDescription: 'Nhắc trước khi giấy tờ hết hạn', importance: Importance.high, priority: Priority.high),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> sync(List<Document> docs, Map<String, Profile> profiles) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final all = <({Document d, DateTime at, int days})>[];
    for (final d in docs) {
      for (final r in reminderTimes(d, hour: hour)) {
        all.add((d: d, at: r.at, days: r.daysBefore));
      }
    }
    all.sort((a, b) => a.at.compareTo(b.at));
    var id = 1;
    for (final r in all.take(60)) {
      final who = profiles[r.d.profileId]?.name ?? '';
      final title = r.days == 0
          ? tr('{t} hết hạn hôm nay', {'t': r.d.title.isEmpty ? r.d.type.label : r.d.title})
          : tr('{t} còn {n} ngày', {'t': r.d.title.isEmpty ? r.d.type.label : r.d.title, 'n': r.days});
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: tr('{who} · Mở Tủ Giấy Tờ để xem hướng dẫn gia hạn.', {'who': who}),
        payload: r.d.id,
      );
    }
  }
}
