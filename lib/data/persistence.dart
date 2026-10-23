import 'dart:typed_data';
import '../core/models.dart';

/// Lưu trữ bản ghi (CSDL mã hoá trên máy thật, bộ nhớ trong khi test).
abstract class Persistence {
  Future<void> open();
  Future<List<Profile>> loadProfiles();
  Future<List<Document>> loadDocuments();
  Future<void> saveProfile(Profile p);
  Future<void> deleteProfile(String id);
  Future<void> saveDocument(Document d);
  Future<void> deleteDocument(String id);
  Future<Map<String, String>> loadSettings();
  Future<void> saveSetting(String key, String value);
  Future<void> clearAll();
}

/// Kho file đính kèm (mã hoá AES-GCM trên máy thật).
abstract class FileVault {
  Future<String> put(Uint8List plain, {required String ext});
  Future<Uint8List> read(String fileName);
  Future<void> delete(String fileName);
  Future<void> clearAll();
}

class MemoryPersistence implements Persistence {
  final profiles = <String, Profile>{};
  final docs = <String, Document>{};
  final settings = <String, String>{};
  @override
  Future<void> open() async {}
  @override
  Future<List<Profile>> loadProfiles() async => profiles.values.toList();
  @override
  Future<List<Document>> loadDocuments() async => docs.values.toList();
  @override
  Future<void> saveProfile(Profile p) async => profiles[p.id] = p;
  @override
  Future<void> deleteProfile(String id) async => profiles.remove(id);
  @override
  Future<void> saveDocument(Document d) async => docs[d.id] = d;
  @override
  Future<void> deleteDocument(String id) async => docs.remove(id);
  @override
  Future<Map<String, String>> loadSettings() async => Map.of(settings);
  @override
  Future<void> saveSetting(String key, String value) async =>
      settings[key] = value;
  @override
  Future<void> clearAll() async {
    profiles.clear();
    docs.clear();
  }
}

class MemoryVault implements FileVault {
  final files = <String, Uint8List>{};
  int _n = 0;
  @override
  Future<String> put(Uint8List plain, {required String ext}) async {
    final name = 'f${_n++}.$ext.enc';
    files[name] = plain;
    return name;
  }

  @override
  Future<Uint8List> read(String fileName) async => files[fileName]!;
  @override
  Future<void> delete(String fileName) async => files.remove(fileName);
  @override
  Future<void> clearAll() async => files.clear();
}
