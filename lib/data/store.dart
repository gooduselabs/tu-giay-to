import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/backup_codec.dart';
import '../core/expiry.dart';
import '../core/models.dart';
import '../l10n/l10n.dart';
import 'persistence.dart';

abstract class ReminderSync {
  Future<void> sync(List<Document> docs, Map<String, Profile> profiles);
}

class NoopReminders implements ReminderSync {
  @override
  Future<void> sync(List<Document> docs, Map<String, Profile> profiles) async {}
}

class LimitReachedException implements Exception {}

class AppStore extends ChangeNotifier {
  static const freeLimit = 10;
  final Persistence db;
  final FileVault vault;
  final ReminderSync reminders;
  /// Hook: dữ liệu người dùng thay đổi (dùng cho sao lưu tự động).
  AppStore({required this.db, required this.vault, ReminderSync? reminders})
      : reminders = reminders ?? NoopReminders();

  final _uuid = const Uuid();
  final Map<String, Profile> profiles = {};
  final Map<String, Document> docs = {};
  Map<String, String> settings = {};
  bool loaded = false;

  // ---------- Cài đặt ----------
  ThemeMode get themeMode => switch (settings['theme']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  bool get lockEnabled => settings['lock'] == '1';
  bool get isPro => settings['pro'] == '1';
  String get locale => settings['locale'] ?? 'vi';
  /// Thời gian ở nền trước khi khoá lại (giây): 0, 30, 60, 300.
  Duration get lockGrace => Duration(seconds: int.tryParse(settings['lock_grace'] ?? '') ?? 30);
  DateTime? get lastBackup => DateTime.tryParse(settings['backup_last'] ?? '');

  /// Nhắc nhẹ khi có giấy tờ thật mà đã hơn 30 ngày chưa sao lưu (hoặc chưa sao lưu lần nào).
  bool backupOverdue([DateTime? now]) {
    if (!docs.values.any((d) => !d.isSample)) return false;
    final l = lastBackup;
    return l == null || (now ?? DateTime.now()).difference(l) > const Duration(days: 30);
  }
  int get reminderHour => int.tryParse(settings['hour'] ?? '') ?? 9;

  Future<void> setSetting(String k, String v) async {
    settings[k] = v;
    await db.saveSetting(k, v);
    if (k == 'locale') L10n.locale.value = v;
    notifyListeners();
  }

  Future<void> load() async {
    await db.open();
    profiles
      ..clear()
      ..addEntries((await db.loadProfiles()).map((p) => MapEntry(p.id, p)));
    docs
      ..clear()
      ..addEntries((await db.loadDocuments()).map((d) => MapEntry(d.id, d)));
    settings = await db.loadSettings();
    L10n.locale.value = locale;
    loaded = true;
    notifyListeners();
  }

  // ---------- Truy vấn ----------
  List<Profile> get profileList {
    final l = profiles.values.toList();
    l.sort((a, b) {
      final k = a.kind.index.compareTo(b.kind.index);
      return k != 0 ? k : a.name.compareTo(b.name);
    });
    return l;
  }

  List<Document> get sortedDocs => docs.values.toList()..sort(compareUrgency);
  List<Document> docsOf(String profileId) =>
      sortedDocs.where((d) => d.profileId == profileId).toList();

  /// Tài liệu mẫu không tính vào hạn mức miễn phí.
  int get userDocCount => docs.values.where((d) => !d.isSample).length;
  bool get canAddDocument => isPro || userDocCount < freeLimit;
  bool get hasSamples =>
      docs.values.any((d) => d.isSample) || profiles.values.any((p) => p.isSample);

  Map<Urgency, int> get urgencyCounts {
    final m = {for (final u in Urgency.values) u: 0};
    for (final d in docs.values) {
      m[urgencyOf(d)] = m[urgencyOf(d)]! + 1;
    }
    return m;
  }

  List<Document> search(String q, {Set<Urgency>? urgencies, String? profileId, DocType? type}) {
    final fq = q.trim().toLowerCase();
    return sortedDocs.where((d) {
      if (urgencies != null && urgencies.isNotEmpty && !urgencies.contains(urgencyOf(d))) return false;
      if (profileId != null && d.profileId != profileId) return false;
      if (type != null && d.type != type) return false;
      if (fq.isEmpty) return true;
      final p = profiles[d.profileId];
      return [d.title, d.number, d.holderName, d.notes, p?.name ?? '', p?.subtitle ?? '']
          .any((s) => s.toLowerCase().contains(fq));
    }).toList();
  }

  // ---------- Ghi ----------
  String newId() => _uuid.v4();

  Future<void> saveProfile(Profile p) async {
    profiles[p.id] = p;
    await db.saveProfile(p);
    notifyListeners();
    await _sync();
  }

  Future<void> deleteProfile(String id) async {
    for (final d in docsOf(id)) {
      await deleteDocument(d.id, sync: false);
    }
    profiles.remove(id);
    await db.deleteProfile(id);
    notifyListeners();
    await _sync();
  }

  Future<void> saveDocument(Document d) async {
    final isNew = !docs.containsKey(d.id);
    if (isNew && !d.isSample && !canAddDocument) throw LimitReachedException();
    docs[d.id] = d;
    await db.saveDocument(d);
    notifyListeners();
    await _sync();
  }

  Future<void> deleteDocument(String id, {bool sync = true}) async {
    final d = docs.remove(id);
    if (d != null) {
      for (final a in d.attachments) {
        await vault.delete(a.fileName);
      }
    }
    await db.deleteDocument(id);
    notifyListeners();
    if (sync) await _sync();
  }

  Future<Attachment> addAttachment(Uint8List bytes, AttachmentKind kind, String label) async {
    final name = await vault.put(bytes, ext: kind == AttachmentKind.pdf ? 'pdf' : 'jpg');
    return Attachment(id: newId(), kind: kind, label: label, fileName: name);
  }

  Future<Uint8List> readAttachment(Attachment a) => vault.read(a.fileName);

  Future<void> _sync() {
    return reminders.sync(docs.values.toList(), profiles);
  }
  Future<void> resync() => _sync();

  // ---------- Sao lưu ----------
  Future<Uint8List> exportBackup(String password) async {
    final files = <String, Uint8List>{};
    for (final d in docs.values) {
      for (final a in d.attachments) {
        files[a.fileName] = await vault.read(a.fileName);
      }
    }
    return BackupCodec.encode(
      data: {
        'app': 'tu-giay-to',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'profiles': profiles.values.map((p) => p.toJson()).toList(),
        'documents': docs.values.map((d) => d.toJson()).toList(),
      },
      files: files,
      password: password,
    );
  }

  /// Ghi nhận đã sao lưu (sau khi chia sẻ hoặc lưu file thành công).
  Future<void> markBackedUp([DateTime? at]) => setSetting('backup_last', (at ?? DateTime.now()).toIso8601String());

  /// Khôi phục.
  /// * replace (mặc định): thay thế toàn bộ dữ liệu hiện có.
  /// * merge: giữ dữ liệu hiện có và chỉ thêm hồ sơ hoặc giấy tờ chưa có (so theo id).
  ///   Mục trùng id thì giữ bản trên máy.
  /// Trả về số giấy tờ đã khôi phục (merge: số giấy tờ được thêm).
  Future<int> importBackup(Uint8List bytes, String password, {bool merge = false}) async {
    final r = await BackupCodec.decode(bytes, password);
    if (!merge) {
      await db.clearAll();
      await vault.clearAll();
      profiles.clear();
      docs.clear();
    }
    var added = 0;
    for (final pj in (r.data['profiles'] as List)) {
      final p = Profile.fromJson(Map<String, dynamic>.from(pj));
      if (profiles.containsKey(p.id)) continue;
      profiles[p.id] = p;
      await db.saveProfile(p);
    }
    for (final dj in (r.data['documents'] as List)) {
      final d = Document.fromJson(Map<String, dynamic>.from(dj));
      if (docs.containsKey(d.id)) continue;
      if (!profiles.containsKey(d.profileId)) continue;
      added++;
      for (final a in d.attachments) {
        final plain = r.files[a.fileName];
        if (plain != null) {
          a.fileName = await vault.put(plain, ext: a.kind == AttachmentKind.pdf ? 'pdf' : 'jpg');
        }
      }
      docs[d.id] = d;
      await db.saveDocument(d);
    }
    notifyListeners();
    await _sync();
    return merge ? added : docs.length;
  }

  Future<void> removeSamples() async {
    for (final d in docs.values.where((d) => d.isSample).toList()) {
      await deleteDocument(d.id, sync: false);
    }
    for (final p in profiles.values.where((p) => p.isSample).toList()) {
      if (docsOf(p.id).isEmpty) {
        profiles.remove(p.id);
        await db.deleteProfile(p.id);
      }
    }
    notifyListeners();
    await _sync();
  }
}
