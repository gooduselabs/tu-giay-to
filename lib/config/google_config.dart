/// Cấu hình Google OAuth cho sao lưu Google Drive.
///
/// Client ID không phải bí mật. Mặc định dùng Web client của gooduselabs.
/// Có thể ghi đè khi build:
///   flutter build apk --release \
///     --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
///   flutter build ios --release \
///     --dart-define=GOOGLE_IOS_CLIENT_ID=yyyy.apps.googleusercontent.com \
///     --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
/// Xem README, mục "Thiết lập Google Drive".
class GoogleConfig {
  /// OAuth client loại "Web application" (Android dùng làm serverClientId).
  static const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID',
      defaultValue: '827113929173-iiv4spogrb91qcntqr9hbducdo04fr0l.apps.googleusercontent.com');

  /// OAuth client loại "iOS" (bundle id com.gooduselabs.tuGiayTo).
  static const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static const driveScope = 'https://www.googleapis.com/auth/drive.appdata';

  static bool get isConfigured => serverClientId.isNotEmpty;
}
