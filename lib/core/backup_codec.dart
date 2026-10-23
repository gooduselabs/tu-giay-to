import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

/// File sao lưu .tgtbak:
///   "TGTB" | version(1) | iterations(u32 BE) | salt(16) | nonce(12) | ciphertext | mac(16)
/// Nội dung giải mã là một file ZIP gồm data.json + files/<tên>.
/// Khoá = PBKDF2-HMAC-SHA256(mật khẩu, salt, iterations) -> AES-256-GCM.
class BackupCodec {
  static const magic = [0x54, 0x47, 0x54, 0x42];
  static const defaultIterations = 150000;

  static Future<SecretKey> _derive(String password, List<int> salt, int it) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: it, bits: 256)
          .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Future<Uint8List> encode({
    required Map<String, dynamic> data,
    required Map<String, Uint8List> files,
    required String password,
    int iterations = defaultIterations,
  }) async {
    final arc = Archive();
    final js = utf8.encode(jsonEncode(data));
    arc.addFile(ArchiveFile('data.json', js.length, js));
    files.forEach((name, bytes) => arc.addFile(ArchiveFile('files/$name', bytes.length, bytes)));
    final zip = ZipEncoder().encode(arc);
    final r = Random.secure();
    final salt = List<int>.generate(16, (_) => r.nextInt(256));
    final key = await _derive(password, salt, iterations);
    final box = await AesGcm.with256bits().encrypt(zip, secretKey: key);
    final header = BytesBuilder()
      ..add(magic)
      ..addByte(1)
      ..add((ByteData(4)..setUint32(0, iterations)).buffer.asUint8List())
      ..add(salt)
      ..add(box.concatenation());
    return header.toBytes();
  }

  static Future<({Map<String, dynamic> data, Map<String, Uint8List> files})> decode(
      Uint8List bytes, String password) async {
    if (bytes.length < 4 + 1 + 4 + 16 + 12 + 16 ||
        !List.generate(4, (i) => bytes[i] == magic[i]).every((x) => x)) {
      throw const FormatException('not-a-backup');
    }
    final it = ByteData.sublistView(bytes, 5, 9).getUint32(0);
    final salt = bytes.sublist(9, 25);
    final key = await _derive(password, salt, it);
    final box = SecretBox.fromConcatenation(bytes.sublist(25), nonceLength: 12, macLength: 16);
    final List<int> zip;
    try {
      zip = await AesGcm.with256bits().decrypt(box, secretKey: key);
    } on SecretBoxAuthenticationError {
      throw const FormatException('wrong-password');
    }
    final arc = ZipDecoder().decodeBytes(zip);
    Map<String, dynamic>? data;
    final files = <String, Uint8List>{};
    for (final f in arc.files) {
      if (!f.isFile) continue;
      final content = Uint8List.fromList(f.content as List<int>);
      if (f.name == 'data.json') {
        data = jsonDecode(utf8.decode(content));
      } else if (f.name.startsWith('files/')) {
        files[f.name.substring(6)] = content;
      }
    }
    if (data == null) throw const FormatException('corrupt');
    return (data: data, files: files);
  }
}
