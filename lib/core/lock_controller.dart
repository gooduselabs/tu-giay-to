import 'dart:async';

/// Máy trạng thái khoá ứng dụng, không phụ thuộc Flutter để kiểm thử được.
///
/// Nguyên nhân lỗi "xác thực xong vẫn bị hỏi lại": hộp thoại sinh trắc/mã máy
/// của hệ thống làm Activity bị pause rồi resume, và bản cũ coi đó là
/// "rời ứng dụng". Bản này áp dụng các quy tắc sau:
///  * Không ghi nhận nền khi đang xác thực, hoặc khi đang mở camera, trình chọn
///    file hay bảng chia sẻ (gọi qua [guard]).
///  * Trong [cooldown] sau lần mở khoá thành công, mọi lần resume đều bỏ qua.
///  * Chỉ khoá lại khi ứng dụng đã ở nền lâu hơn [grace].
///  * Chỉ có một lời gọi xác thực chạy tại một thời điểm.
/// Bộ điều khiển khoá dùng chung cho cả ứng dụng.
final appLock = LockController(enabled: false);

class LockController {
  LockController({
    required this.enabled,
    this.grace = const Duration(seconds: 30),
    this.cooldown = const Duration(seconds: 3),
    DateTime Function()? clock,
  })  : _now = clock ?? DateTime.now,
        _locked = enabled;

  bool enabled;
  Duration grace;
  final Duration cooldown;
  final DateTime Function() _now;

  bool _locked;
  bool _authing = false;
  int _guards = 0;
  DateTime? _bgAt;
  DateTime? _lastOk;
  Future<bool>? _pending;
  final _changes = StreamController<bool>.broadcast();

  bool get locked => enabled && _locked;
  bool get authInProgress => _authing;
  bool get guarded => _guards > 0;
  Stream<bool> get changes => _changes.stream;

  void setEnabled(bool v) {
    enabled = v;
    if (!v) _locked = false;
    _changes.add(locked);
  }

  /// Khoá ngay (khi khởi động ứng dụng).
  void lockNow() {
    if (!enabled) return;
    _locked = true;
    _changes.add(true);
  }

  /// Ứng dụng bị đưa xuống nền (AppLifecycleState.paused/hidden).
  void onBackground() {
    if (!enabled || _locked || _authing || guarded) return;
    _bgAt ??= _now();
  }

  /// Ứng dụng trở lại (AppLifecycleState.resumed).
  void onForeground() {
    final bg = _bgAt;
    _bgAt = null;
    if (!enabled || _locked || _authing || guarded || bg == null) return;
    final now = _now();
    if (_lastOk != null && now.difference(_lastOk!) < cooldown) return;
    if (now.difference(bg) >= grace) {
      _locked = true;
      _changes.add(true);
    }
  }

  /// Gọi xác thực, có chặn gọi chồng: lời gọi thứ hai dùng chung kết quả của lời gọi đang chạy.
  Future<bool> unlock(Future<bool> Function() authenticate) {
    if (!locked) return Future.value(true);
    return _pending ??= _run(authenticate).whenComplete(() => _pending = null);
  }

  /// Xác thực cho một thao tác (ví dụ xuất trình) mà không làm thay đổi trạng thái khoá.
  Future<bool> confirm(Future<bool> Function() authenticate) => guard(authenticate);

  Future<bool> _run(Future<bool> Function() authenticate) async {
    _authing = true;
    _bgAt = null;
    var ok = false;
    try {
      ok = await authenticate();
    } catch (_) {
      ok = false;
    } finally {
      _authing = false;
      _bgAt = null;
    }
    if (ok) {
      _locked = false;
      _lastOk = _now();
      _changes.add(false);
    }
    return ok;
  }

  /// Bọc các thao tác mở Activity khác (camera, chọn file, chia sẻ, hộp thoại xác thực).
  Future<T> guard<T>(Future<T> Function() action) async {
    _guards++;
    _bgAt = null;
    try {
      return await action();
    } finally {
      _guards--;
      _bgAt = null;
      _lastOk = _now(); // lần resume ngay sau đó không bị tính
    }
  }

  void dispose() => _changes.close();
}
