import 'package:local_auth/local_auth.dart';
import 'package:screen_brightness/screen_brightness.dart';

class Biometric {
  static final _auth = LocalAuthentication();
  static Future<bool> available() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool>? _inFlight;

  /// Không chỉ dùng sinh trắc: cho phép dùng mã PIN/hình vẽ/mật khẩu máy khi
  /// khuôn mặt/vân tay lỗi. Không yêu cầu bấm "Xác nhận" sau khi nhận diện khuôn
  /// mặt. Không dùng sticky auth, vì sticky auth tự bật lại hộp thoại khi resume.
  /// Chỉ cho phép một hộp thoại tại một thời điểm.
  static Future<bool> authenticate(String reason) => _inFlight ??= () async {
        try {
          return await _auth.authenticate(
            localizedReason: reason,
            biometricOnly: false,
            sensitiveTransaction: false,
            persistAcrossBackgrounding: false,
          );
        } catch (_) {
          return false;
        }
      }()
          .whenComplete(() => _inFlight = null);
}

class Brightness {
  static Future<void> boost() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (_) {}
  }

  static Future<void> reset() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}
