import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../config/google_config.dart';

class DriveFile {
  final String id, name;
  final DateTime modified;
  final int size;
  DriveFile(this.id, this.name, this.modified, this.size);
}

class DriveNotConfigured implements Exception {}

class DriveAuthFailed implements Exception {
  final String message;
  DriveAuthFailed(this.message);
  @override
  String toString() => message;
}

/// REST Drive v3 trong thư mục ẩn appDataFolder (scope drive.appdata).
/// Chỉ tải lên file .tgtbak ĐÃ mã hoá bằng mật khẩu người dùng → Google không đọc được.
class DriveApi {
  final Future<String?> Function() token;
  final http.Client client;
  static const keep = 5; // giữ 5 bản gần nhất
  DriveApi(this.token, {http.Client? client}) : client = client ?? http.Client();

  Future<Map<String, String>> _h() async {
    final t = await token();
    if (t == null) throw DriveAuthFailed('no-token');
    return {'Authorization': 'Bearer $t'};
  }

  Future<List<DriveFile>> list() async {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'spaces': 'appDataFolder',
      'orderBy': 'modifiedTime desc',
      'fields': 'files(id,name,modifiedTime,size)',
      'pageSize': '50',
    });
    final r = await client.get(uri, headers: await _h());
    _check(r);
    final files = (jsonDecode(r.body)['files'] as List).cast<Map<String, dynamic>>();
    return [
      for (final f in files)
        DriveFile(f['id'], f['name'], DateTime.parse(f['modifiedTime']).toLocal(), int.tryParse('${f['size']}') ?? 0)
    ];
  }

  Future<DriveFile> upload(Uint8List bytes, String name) async {
    const boundary = 'tgt-boundary-7f3a';
    final meta = jsonEncode({'name': name, 'parents': ['appDataFolder'], 'mimeType': 'application/octet-stream'});
    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$meta\r\n'))
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/octet-stream\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final r = await client.post(
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,modifiedTime,size'),
      headers: {...await _h(), 'Content-Type': 'multipart/related; boundary=$boundary'},
      body: body.toBytes(),
    );
    _check(r);
    final f = jsonDecode(r.body);
    final out = DriveFile(f['id'], f['name'], DateTime.tryParse('${f['modifiedTime']}')?.toLocal() ?? DateTime.now(), bytes.length);
    await prune();
    return out;
  }

  Future<void> prune() async {
    final all = await list();
    for (final f in all.skip(keep)) {
      await client.delete(Uri.parse('https://www.googleapis.com/drive/v3/files/${f.id}'), headers: await _h());
    }
  }

  Future<Uint8List> download(String id) async {
    final r = await client.get(Uri.parse('https://www.googleapis.com/drive/v3/files/$id?alt=media'), headers: await _h());
    _check(r);
    return r.bodyBytes;
  }

  void _check(http.Response r) {
    if (r.statusCode == 401 || r.statusCode == 403) throw DriveAuthFailed('http-${r.statusCode}');
    if (r.statusCode >= 300) throw Exception('Drive HTTP ${r.statusCode}: ${r.body}');
  }
}

/// Đăng nhập Google (google_sign_in 7.x). Không cấu hình → ném DriveNotConfigured.
class GoogleDriveAuth {
  static bool _init = false;
  static GoogleSignInAccount? account;

  static Future<void> _ensureInit() async {
    if (!GoogleConfig.isConfigured) throw DriveNotConfigured();
    if (_init) return;
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS && GoogleConfig.iosClientId.isNotEmpty ? GoogleConfig.iosClientId : null,
      serverClientId: GoogleConfig.serverClientId,
    );
    _init = true;
  }

  /// Đăng nhập tương tác + xin quyền drive.appdata. Trả về email.
  static Future<String> signIn() async {
    await _ensureInit();
    try {
      account = await GoogleSignIn.instance.authenticate(scopeHint: [GoogleConfig.driveScope]);
      await account!.authorizationClient.authorizeScopes([GoogleConfig.driveScope]);
      return account!.email;
    } on GoogleSignInException catch (e) {
      throw DriveAuthFailed(e.description ?? e.code.name);
    }
  }

  /// Lấy access token; [interactive]=false dùng cho chạy nền.
  static Future<String?> token({bool interactive = true}) async {
    await _ensureInit();
    account ??= await GoogleSignIn.instance.attemptLightweightAuthentication();
    final client = account?.authorizationClient ?? GoogleSignIn.instance.authorizationClient;
    final a = await client.authorizationForScopes([GoogleConfig.driveScope]) ??
        (interactive ? await client.authorizeScopes([GoogleConfig.driveScope]) : null);
    return a?.accessToken;
  }

  static Future<void> signOut() async {
    if (!_init) return;
    await GoogleSignIn.instance.disconnect();
    account = null;
  }
}
