import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_giay_to/core/lock_controller.dart';

void main() {
  late DateTime now;
  LockController make({Duration grace = const Duration(seconds: 30), bool enabled = true}) =>
      LockController(enabled: enabled, grace: grace, clock: () => now);
  void tick(int s) => now = now.add(Duration(seconds: s));
  setUp(() => now = DateTime(2026, 10, 23, 12));

  test('khởi đầu bị khoá khi bật, mở khi tắt', () {
    expect(make().locked, isTrue);
    expect(make(enabled: false).locked, isFalse);
  });

  test('xác thực thành công thì mở khoá, thất bại thì vẫn khoá', () async {
    final c = make();
    expect(await c.unlock(() async => false), isFalse);
    expect(c.locked, isTrue);
    expect(await c.unlock(() async => true), isTrue);
    expect(c.locked, isFalse);
  });

  test('pause/resume do hộp thoại sinh trắc không khoá lại (lỗi hỏi liên tục)', () async {
    final c = make(grace: Duration.zero);
    final done = Completer<bool>();
    final f = c.unlock(() => done.future);
    c.onBackground(); // hộp thoại hệ thống che Activity
    tick(40);
    c.onForeground();
    done.complete(true);
    expect(await f, isTrue);
    // resume trễ đến ngay sau khi thành công
    c.onBackground();
    tick(1);
    c.onForeground();
    expect(c.locked, isFalse);
  });

  test('gọi xác thực chồng nhau chỉ chạy một lần', () async {
    final c = make();
    var calls = 0;
    final done = Completer<bool>();
    final a = c.unlock(() {
      calls++;
      return done.future;
    });
    final b = c.unlock(() {
      calls++;
      return Future.value(true);
    });
    done.complete(true);
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(calls, 1);
  });

  test('chỉ khoá lại khi ở nền lâu hơn thời gian chờ', () async {
    final c = make();
    await c.unlock(() async => true);
    tick(10);
    c.onBackground();
    tick(20);
    c.onForeground();
    expect(c.locked, isFalse, reason: '20s < 30s');
    c.onBackground();
    tick(31);
    c.onForeground();
    expect(c.locked, isTrue);
  });

  test('chế độ "ngay lập tức" khoá ở mọi lần rời ứng dụng (ngoài cooldown)', () async {
    final c = make(grace: Duration.zero);
    await c.unlock(() async => true);
    tick(5);
    c.onBackground();
    c.onForeground();
    expect(c.locked, isTrue);
  });

  test('camera/chọn file/chia sẻ trong guard không làm khoá', () async {
    final c = make(grace: Duration.zero);
    await c.unlock(() async => true);
    tick(10);
    await c.guard(() async {
      c.onBackground();
      tick(120);
      c.onForeground();
    });
    expect(c.locked, isFalse);
    // resume đến muộn ngay sau khi guard kết thúc
    c.onBackground();
    tick(1);
    c.onForeground();
    expect(c.locked, isFalse);
  });

  test('lỗi trong guard vẫn giải phóng guard', () async {
    final c = make();
    await expectLater(c.guard(() async => throw StateError('x')), throwsStateError);
    expect(c.guarded, isFalse);
  });

  test('xác thực ném lỗi thì coi như thất bại', () async {
    final c = make();
    expect(await c.unlock(() async => throw Exception('hw')), isFalse);
    expect(c.locked, isTrue);
    expect(c.authInProgress, isFalse);
  });

  test('tắt khoá thì mở ngay và không bao giờ khoá lại', () {
    final c = make();
    c.setEnabled(false);
    expect(c.locked, isFalse);
    c.onBackground();
    tick(999);
    c.onForeground();
    expect(c.locked, isFalse);
  });

  test('nhiều lần background liên tiếp tính từ lần đầu', () async {
    final c = make();
    await c.unlock(() async => true);
    tick(10);
    c.onBackground(); // paused
    tick(20);
    c.onBackground(); // hidden/detached lặp lại
    tick(15);
    c.onForeground();
    expect(c.locked, isTrue, reason: '35s tính từ lần background đầu');
  });
}
