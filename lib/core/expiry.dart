import 'dart:math';
import 'models.dart';

enum Urgency { expired, red, yellow, green, none }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int? daysLeft(Document d, {DateTime? now}) {
  final e = d.expiryDate;
  if (e == null) return null;
  return dateOnly(e).difference(dateOnly(now ?? DateTime.now())).inDays;
}

/// Màu khẩn cấp: đỏ khi tới mốc nhắc gần nhất (tối thiểu 7 ngày),
/// vàng khi tới mốc nhắc xa nhất (tối thiểu 30 ngày), còn lại xanh.
Urgency urgencyOf(Document d, {DateTime? now}) {
  final left = daysLeft(d, now: now);
  if (left == null) return Urgency.none;
  if (left < 0) return Urgency.expired;
  final days = d.reminderDays.isEmpty ? [30, 7] : d.reminderDays;
  final redAt = max(7, days.reduce(min));
  final yellowAt = max(30, days.reduce(max));
  if (left <= redAt) return Urgency.red;
  if (left <= yellowAt) return Urgency.yellow;
  return Urgency.green;
}

int urgencyRank(Urgency u) => switch (u) {
      Urgency.expired => 0,
      Urgency.red => 1,
      Urgency.yellow => 2,
      Urgency.green => 3,
      Urgency.none => 4,
    };

/// Sắp xếp theo độ khẩn cấp, rồi theo ngày hết hạn gần nhất.
int compareUrgency(Document a, Document b, {DateTime? now}) {
  final r = urgencyRank(urgencyOf(a, now: now))
      .compareTo(urgencyRank(urgencyOf(b, now: now)));
  if (r != 0) return r;
  final ea = a.expiryDate, eb = b.expiryDate;
  if (ea != null && eb != null) return ea.compareTo(eb);
  return a.title.compareTo(b.title);
}

/// Các mốc tuổi phải đổi thẻ căn cước/CCCD (Luật Căn cước 2023): 14, 25, 40, 60.
/// Thẻ cấp/đổi trong vòng 2 năm trước mốc tuổi thì dùng tới mốc tiếp theo.
const cccdMilestones = [14, 25, 40, 60];

DateTime _addYears(DateTime d, int y) {
  final day = min(d.day, DateTime(d.year + y, d.month + 1, 0).day);
  return DateTime(d.year + y, d.month, day);
}

/// Trả về ngày hết hạn suy ra từ ngày sinh + ngày cấp; null = không thời hạn
/// (cấp/đổi từ đủ 58 tuổi trở đi).
DateTime? cccdExpiryFor(DateTime birth, DateTime issue) {
  for (final m in cccdMilestones) {
    final milestone = _addYears(birth, m);
    final windowStart = _addYears(milestone, -2);
    if (issue.isBefore(windowStart)) return milestone;
  }
  return null;
}

/// Mốc đổi CCCD tiếp theo kể từ hôm nay (để hiển thị gợi ý).
({int age, DateTime date})? nextCccdMilestone(DateTime birth, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  for (final m in cccdMilestones) {
    final d = _addYears(birth, m);
    if (!d.isBefore(today)) return (age: m, date: d);
  }
  return null;
}

/// Các thời điểm nhắc (09:00) còn ở tương lai, kèm số ngày còn lại.
List<({DateTime at, int daysBefore})> reminderTimes(Document d,
    {DateTime? now, int hour = 9}) {
  final e = d.expiryDate;
  if (e == null) return [];
  final n = now ?? DateTime.now();
  final set = {...d.reminderDays.where((x) => x >= 0), 0}.toList()
    ..sort((a, b) => b.compareTo(a));
  final out = <({DateTime at, int daysBefore})>[];
  for (final days in set) {
    final day = dateOnly(e).subtract(Duration(days: days));
    final at = DateTime(day.year, day.month, day.day, hour);
    if (at.isAfter(n)) out.add((at: at, daysBefore: days));
  }
  return out;
}
