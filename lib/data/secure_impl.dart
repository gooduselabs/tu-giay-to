import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import 'persistence.dart';

/// Khoá chủ ngẫu nhiên 256-bit lưu trong Keystore (Android) / Keychain (iOS).
class KeyStore {
  static const _storage = FlutterSecureStorage();
  static Future<Uint8List> masterKey() async {
    var b64 = await _storage.read(key: 'tgt_master_key');
    if (b64 == null) {
      final r = Random.secure();
      b64 = base64Encode(List<int>.generate(32, (_) => r.nextInt(256)));
      await _storage.write(key: 'tgt_master_key', value: b64);
    }
    return base64Decode(b64);
  }
}

class SqlCipherPersistence implements Persistence {
  late Database _db;

  @override
  Future<void> open() async {
    final key = await KeyStore.masterKey();
    // Mật khẩu CSDL suy ra từ khoá chủ (hex), không bao giờ rời thiết bị.
    final pass = key.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final dir = await getApplicationSupportDirectory();
    _db = await openDatabase(
      p.join(dir.path, 'vault.db'),
      password: pass,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('CREATE TABLE profiles(id TEXT PRIMARY KEY, json TEXT NOT NULL)');
        await db.execute('CREATE TABLE documents(id TEXT PRIMARY KEY, json TEXT NOT NULL)');
        await db.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT NOT NULL)');
      },
    );
  }

  Future<List<Map<String, dynamic>>> _all(String t) async =>
      (await _db.query(t)).map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>).toList();

  @override
  Future<List<Profile>> loadProfiles() async => (await _all('profiles')).map(Profile.fromJson).toList();
  @override
  Future<List<Document>> loadDocuments() async => (await _all('documents')).map(Document.fromJson).toList();
  @override
  Future<void> saveProfile(Profile x) => _db.insert('profiles', {'id': x.id, 'json': jsonEncode(x.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace);
  @override
  Future<void> deleteProfile(String id) => _db.delete('profiles', where: 'id=?', whereArgs: [id]);
  @override
  Future<void> saveDocument(Document d) => _db.insert('documents', {'id': d.id, 'json': d.encode()},
      conflictAlgorithm: ConflictAlgorithm.replace);
  @override
  Future<void> deleteDocument(String id) => _db.delete('documents', where: 'id=?', whereArgs: [id]);
  @override
  Future<Map<String, String>> loadSettings() async =>
      {for (final r in await _db.query('settings')) r['k'] as String: r['v'] as String};
  @override
  Future<void> saveSetting(String key, String value) =>
      _db.insert('settings', {'k': key, 'v': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  @override
  Future<void> clearAll() async {
    await _db.delete('profiles');
    await _db.delete('documents');
  }
}

/// File đính kèm: AES-256-GCM, mỗi file một nonce ngẫu nhiên.
/// Định dạng: nonce(12) | ciphertext | mac(16).
class EncryptedFileVault implements FileVault {
  final _algo = AesGcm.with256bits();
  late SecretKey _key;
  late Directory _dir;

  Future<void> init() async {
    _key = SecretKey(await KeyStore.masterKey());
    final base = await getApplicationSupportDirectory();
    _dir = Directory(p.join(base.path, 'vault'));
    await _dir.create(recursive: true);
  }

  @override
  Future<String> put(Uint8List plain, {required String ext}) async {
    final box = await _algo.encrypt(plain, secretKey: _key);
    final name = '${const Uuid().v4()}.$ext.enc';
    await File(p.join(_dir.path, name)).writeAsBytes(box.concatenation(), flush: true);
    return name;
  }

  @override
  Future<Uint8List> read(String fileName) async {
    final bytes = await File(p.join(_dir.path, fileName)).readAsBytes();
    final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
    return Uint8List.fromList(await _algo.decrypt(box, secretKey: _key));
  }

  @override
  Future<void> delete(String fileName) async {
    final f = File(p.join(_dir.path, fileName));
    if (await f.exists()) await f.delete();
  }

  @override
  Future<void> clearAll() async {
    if (await _dir.exists()) await _dir.delete(recursive: true);
    await _dir.create(recursive: true);
  }
}
