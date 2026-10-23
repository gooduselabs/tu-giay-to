import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/expiry.dart';
import '../../data/sample_data.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../services/cloud_backup.dart';
import '../../services/drive_backup.dart';
import '../../services/media.dart';
import '../../services/security.dart' show Biometric;
import '../app.dart';
import '../sample_art.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dossier.dart';
import '../widgets/glyphs.dart';

String fmtTime(DateTime t) => DateFormat('HH:mm · dd/MM/yyyy').format(t);

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final a = context.ar;
    final t = Theme.of(context);
    return Scaffold(
      body: NotebookBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 60), children: [
            Text(tr('SỔ TAY QUẢN LÝ'), style: t.textTheme.labelSmall?.copyWith(color: a.ink)),
            const SizedBox(height: 6),
            Container(height: 1.5, color: a.ink),
            const SizedBox(height: 14),
            Text(tr('Cài đặt'), style: t.textTheme.displaySmall?.copyWith(fontSize: 44)),
            const SizedBox(height: 18),
            _PlanSlip(store: store),
            SectionLabel(tr('Sao lưu Google Drive'), index: 'i.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            const DriveSection(),
            SectionLabel(tr('Giao diện'), index: 'ii.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            _Row(
              icon: Ic.sun,
              title: tr('Chế độ'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                for (final m in [('system', tr('Theo máy')), ('light', tr('Sáng')), ('dark', tr('Tối'))])
                  _TextToggle(m.$2, (store.settings['theme'] ?? 'system') == m.$1, () => store.setSetting('theme', m.$1)),
              ]),
            ),
            _Row(
              icon: Ic.language,
              title: tr('Ngôn ngữ'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _TextToggle('Tiếng Việt', store.locale == 'vi', () => store.setSetting('locale', 'vi')),
                _TextToggle('English', store.locale == 'en', () => store.setSetting('locale', 'en')),
              ]),
            ),
            SectionLabel(tr('Bảo mật'), index: 'iii.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            _Row(
              icon: Ic.fingerprint,
              title: tr('Khoá bằng vân tay / khuôn mặt'),
              subtitle: tr('Yêu cầu khi mở ứng dụng và khi xuất trình'),
              trailing: Switch(
                value: store.lockEnabled,
                onChanged: (v) async {
                  if (v && AppScope.of(context).platformServices) {
                    if (!await Biometric.available()) {
                      if (context.mounted) snack(context, tr('Thiết bị chưa cài vân tay/khuôn mặt hoặc mã khoá màn hình.'));
                      return;
                    }
                    if (!await Biometric.authenticate(tr('Xác nhận bật khoá'))) return;
                  }
                  await store.setSetting('lock', v ? '1' : '0');
                },
              ),
            ),
            _Row(
              icon: Ic.key,
              title: tr('Mã hoá trên máy'),
              subtitle: tr('CSDL SQLCipher + tệp AES-256-GCM. Khoá lưu trong Keystore/Keychain. Không cần tài khoản.'),
            ),
            SectionLabel(tr('Nhắc nhở'), index: 'iv.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            _Row(
              icon: Ic.bell,
              title: tr('Cho phép thông báo'),
              subtitle: tr('Nhắc lúc {h}:00 sáng theo lịch từng giấy tờ', {'h': store.reminderHour}),
              trailing: Gl(Ic.chevronRight, size: 18, color: a.inkSoft),
              onTap: () async {
                final ok = await TuGiayToApp.notificationPermission?.call() ?? false;
                await store.resync();
                if (context.mounted) snack(context, ok ? tr('Đã bật thông báo nhắc hạn') : tr('Chưa được cấp quyền thông báo'));
              },
            ),
            SectionLabel(tr('Sao lưu ra file'), index: 'v.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            _Row(icon: Ic.cloudUp, title: tr('Tạo bản sao lưu mã hoá'), subtitle: tr('File .tgtbak bảo vệ bằng mật khẩu của bạn'),
                onTap: () => _backupFile(context, store)),
            _Row(icon: Ic.restore, title: tr('Khôi phục từ file'), subtitle: tr('Thay thế toàn bộ dữ liệu hiện có'),
                onTap: () => _restoreFile(context, store)),
            SectionLabel(tr('Dữ liệu mẫu'), index: 'vi.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            if (!store.hasSamples)
              _Row(icon: Ic.spark, title: tr('Thêm dữ liệu mẫu'), subtitle: tr('Gia đình hư cấu, gắn nhãn MẪU, không tính vào giới hạn'),
                  onTap: () => seedSamples(store, art: sampleArt))
            else
              _Row(icon: Ic.trash, title: tr('Xoá dữ liệu mẫu'), onTap: () => store.removeSamples()),
            const SizedBox(height: 30),
            Text('Tủ Giấy Tờ 0.2.0 — gooduselabs',
                style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 13, color: a.inkFaint)),
          ]),
        ),
      ),
    );
  }

  static Future<void> _backupFile(BuildContext context, AppStore store) async {
    final pw = await askPassword(context, confirm: true);
    if (pw == null || !context.mounted) return;
    snack(context, tr('Đang mã hoá bản sao lưu…'));
    final bytes = await store.exportBackup(pw);
    LockGate.suppress = true;
    try {
      await Media.shareBytes(bytes, CloudBackup.fileName(DateTime.now()), text: tr('Bản sao lưu Tủ Giấy Tờ (đã mã hoá)'));
    } finally {
      LockGate.suppress = false;
    }
  }

  static Future<void> _restoreFile(BuildContext context, AppStore store) async {
    LockGate.suppress = true;
    final bytes = await Media.pickBackupFile().whenComplete(() => LockGate.suppress = false);
    if (bytes == null || !context.mounted) return;
    final pw = await askPassword(context, confirm: false);
    if (pw == null || !context.mounted) return;
    if (!await confirmReplace(context)) return;
    try {
      final n = await store.importBackup(bytes, pw);
      if (context.mounted) snack(context, tr('Đã khôi phục {n} giấy tờ', {'n': n}));
    } on FormatException catch (e) {
      if (context.mounted) snack(context, e.message == 'wrong-password' ? tr('Sai mật khẩu') : tr('File sao lưu không hợp lệ'));
    }
  }
}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<bool> confirmReplace(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Khôi phục?')),
        content: Text(tr('Dữ liệu hiện tại trên máy sẽ bị thay thế bằng bản sao lưu.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Huỷ'), style: TextStyle(color: c.ar.ink))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Khôi phục'))),
        ],
      ),
    ) ==
    true;

Future<String?> askPassword(BuildContext context, {required bool confirm, String? note}) {
  final p1 = TextEditingController(), p2 = TextEditingController();
  String? err;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(confirm ? tr('Đặt mật khẩu sao lưu') : tr('Nhập mật khẩu sao lưu')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (confirm || note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(note ?? tr('Không thể khôi phục nếu quên mật khẩu. Tối thiểu 8 ký tự.'), style: Theme.of(ctx).textTheme.bodySmall),
            ),
          TextField(controller: p1, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: tr('Mật khẩu'))),
          if (confirm) ...[
            const SizedBox(height: 10),
            TextField(controller: p2, obscureText: true, decoration: InputDecoration(labelText: tr('Nhập lại'))),
          ],
          if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: TextStyle(color: ctx.ar.cinnabar))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Huỷ'), style: TextStyle(color: ctx.ar.ink))),
          FilledButton(
            onPressed: () {
              if (confirm && p1.text.length < 8) return set(() => err = tr('Mật khẩu quá ngắn'));
              if (confirm && p1.text != p2.text) return set(() => err = tr('Mật khẩu không khớp'));
              Navigator.pop(ctx, p1.text);
            },
            child: Text(tr('Tiếp tục')),
          ),
        ],
      ),
    ),
  );
}

/// Khu vực Google Drive: xử lý cả trường hợp bản build chưa có OAuth client.
class DriveSection extends StatefulWidget {
  const DriveSection({super.key});
  @override
  State<DriveSection> createState() => _DriveSectionState();
}

class _DriveSectionState extends State<DriveSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    LockGate.suppress = true;
    try {
      await f();
    } on DriveNotConfigured {
      if (mounted) snack(context, tr('Bản build này chưa cấu hình Google OAuth.'));
    } on DriveAuthFailed catch (e) {
      if (mounted) snack(context, tr('Không đăng nhập được Google: {e}', {'e': e.message}));
    } on FormatException catch (e) {
      if (mounted) snack(context, e.message == 'wrong-password' ? tr('Sai mật khẩu') : tr('File sao lưu không hợp lệ'));
    } catch (e) {
      if (mounted) snack(context, tr('Lỗi Google Drive: {e}', {'e': e}));
    } finally {
      LockGate.suppress = false;
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _password({bool forAuto = false}) async {
    final saved = await CloudBackup.readPassword().catchError((_) => null);
    if (saved != null && !forAuto) return saved;
    if (!mounted) return null;
    return askPassword(context,
        confirm: true,
        note: forAuto
            ? tr('Sao lưu tự động cần lưu mật khẩu này trong Keystore/Keychain của máy. Google chỉ nhận file đã mã hoá.')
            : null);
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final a = context.ar;
    if (!CloudBackup.configured) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(border: Border.all(color: a.ruleStrong), color: a.paperDeep.withValues(alpha: .5)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Gl(Ic.cloud, size: 22, color: a.inkSoft),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Chưa bật trong bản build này'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(tr('Cần OAuth client của Google Cloud (xem README, mục "Thiết lập Google Drive"). Trong lúc chờ, hãy dùng "Sao lưu ra file" bên dưới.'),
                  style: TextStyle(fontSize: 12.5, color: a.inkSoft, height: 1.45)),
            ]),
          ),
        ]),
      );
    }
    final email = store.driveEmail;
    if (email == null) {
      return _Row(
        icon: Ic.cloud,
        title: tr('Kết nối Google Drive'),
        subtitle: tr('Lưu bản sao đã mã hoá vào thư mục ẩn của ứng dụng (drive.appdata). Google không đọc được nội dung.'),
        trailing: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.5)) : Gl(Ic.chevronRight, size: 18, color: a.inkSoft),
        onTap: _busy
            ? null
            : () => _run(() async {
                  final e = await GoogleDriveAuth.signIn();
                  await store.setSetting('drive_email', e);
                }),
      );
    }
    final last = store.driveLast;
    return Column(children: [
      _Row(
        icon: Ic.cloud,
        title: email,
        subtitle: last == null ? tr('Chưa có bản sao lưu nào') : tr('Lần sao lưu cuối: {t}', {'t': fmtTime(last)}),
        trailing: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.5)) : null,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final pw = await _password();
                        if (pw == null) return;
                        await CloudBackup.backupNow(store, pw);
                        if (mounted) snack(context, tr('Đã sao lưu lên Google Drive'));
                      }),
              icon: Gl(Ic.cloudUp, size: 18, color: a.paper),
              label: Text(tr('Sao lưu ngay')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(() => _restore(store)),
              icon: Gl(Ic.restore, size: 18, color: a.ink),
              label: Text(tr('Khôi phục')),
            ),
          ),
        ]),
      ),
      _Row(
        icon: Ic.calendar,
        title: tr('Tự động sao lưu'),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final m in [('off', tr('Tắt')), ('daily', tr('Hằng ngày')), ('change', tr('Khi thay đổi'))])
            _TextToggle(m.$2, store.driveAuto == m.$1, () => _run(() async {
                  if (m.$1 != 'off') {
                    final pw = await _password(forAuto: true);
                    if (pw == null) return;
                    await CloudBackup.savePassword(pw);
                  } else {
                    await CloudBackup.savePassword(null);
                  }
                  await store.setSetting('drive_auto', m.$1);
                  await CloudBackup.applySchedule(m.$1);
                })),
        ]),
      ),
      _Row(
        icon: Ic.close,
        title: tr('Ngắt kết nối Google'),
        onTap: () => _run(() async {
          await GoogleDriveAuth.signOut();
          await CloudBackup.savePassword(null);
          await CloudBackup.applySchedule('off');
          await store.setSetting('drive_email', '');
          await store.setSetting('drive_auto', 'off');
        }),
      ),
    ]);
  }

  Future<void> _restore(AppStore store) async {
    final files = await CloudBackup.api().list();
    if (!mounted) return;
    if (files.isEmpty) {
      snack(context, tr('Chưa có bản sao lưu nào trên Drive'));
      return;
    }
    final a = context.ar;
    final f = await showModalBottomSheet<DriveFile>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 8), child: Text(tr('Chọn bản sao lưu'), style: Theme.of(c).textTheme.titleLarge)),
          for (final x in files)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Gl(Ic.drawer, size: 20, color: a.ink),
              title: Text(fmtTime(x.modified), style: const TextStyle(fontFeatures: tabular)),
              subtitle: Text('${(x.size / 1024).toStringAsFixed(0)} KB'),
              onTap: () => Navigator.pop(c, x),
            ),
        ]),
      ),
    );
    if (f == null || !mounted) return;
    final pw = await askPassword(context, confirm: false);
    if (pw == null || !mounted) return;
    if (!await confirmReplace(context)) return;
    final n = await CloudBackup.restore(store, f, pw);
    if (mounted) snack(context, tr('Đã khôi phục {n} giấy tờ', {'n': n}));
  }
}

class _Row extends StatelessWidget {
  final Ic icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Row({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule))),
        child: Row(children: [
          Gl(icon, size: 20, color: a.ink),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(fontSize: 12.5, color: a.inkSoft, height: 1.4)),
              ],
            ]),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ]),
      ),
    );
  }
}

class _TextToggle extends StatelessWidget {
  final String label;
  final bool sel;
  final VoidCallback onTap;
  const _TextToggle(this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? a.ink : a.inkSoft)),
          const SizedBox(height: 3),
          Container(height: 1.5, width: sel ? 14 : 0, color: a.cinnabar),
        ]),
      ),
    );
  }
}

/// "Phiếu" gói sử dụng, có dấu mộc.
class _PlanSlip extends StatelessWidget {
  final AppStore store;
  const _PlanSlip({required this.store});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final used = store.userDocCount;
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen())),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(color: Color.alphaBlend(a.manila.withValues(alpha: .45), a.card), border: Border.all(color: a.manilaEdge)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.isPro ? tr('GÓI PRO') : tr('GÓI MIỄN PHÍ'),
                  style: TextStyle(fontSize: 10.5, letterSpacing: 1.8, fontWeight: FontWeight.w700, color: a.cinnabar)),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(used.toString().padLeft(2, '0'), style: TextStyle(fontFamily: serif, fontSize: 40, height: 1, color: a.ink, fontFeatures: tabular)),
                Text(store.isPro ? '  / ∞' : '  / ${AppStore.freeLimit}',
                    style: TextStyle(fontFamily: serif, fontSize: 20, color: a.inkSoft, fontFeatures: tabular)),
              ]),
              const SizedBox(height: 4),
              Text(store.isPro ? tr('Không giới hạn giấy tờ') : tr('giấy tờ đã lưu · chạm để xem Pro'),
                  style: TextStyle(fontSize: 12.5, color: a.inkSoft)),
            ]),
          ),
          Stamp(store.isPro ? Urgency.green : Urgency.yellow, scale: 1.1),
        ]),
      ),
    );
  }
}

/// Màn Pro — CHỈ LÀ CỜ THỬ NGHIỆM, chưa có thanh toán thật.
class ProScreen extends StatelessWidget {
  final bool reason;
  const ProScreen({super.key, this.reason = false});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final a = context.ar;
    Widget perk(String n, String s) => Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 34, child: Text(n, style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, color: a.cinnabar, fontSize: 15))),
            Expanded(child: Text(s, style: const TextStyle(fontSize: 15))),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Gl(Ic.close, size: 22, color: a.ink), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(tr('GÓI SỬ DỤNG')),
      ),
      body: NotebookBackground(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 40), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text(tr('Tủ Giấy Tờ Pro'), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 42)),
              ),
              Padding(padding: const EdgeInsets.only(top: 10), child: Stamp(Urgency.green, scale: 1.3, animate: true, angle: .12)),
            ]),
            const SizedBox(height: 10),
            Text(
              reason
                  ? tr('Bản miễn phí lưu tối đa {max} giấy tờ. Nâng cấp để thêm tiếp.', {'max': AppStore.freeLimit})
                  : tr('Cho cả gia đình, không giới hạn.'),
              style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 17, color: a.inkSoft),
            ),
            const SizedBox(height: 24),
            Container(height: 1.2, color: a.ink),
            perk('i.', tr('Không giới hạn số giấy tờ')),
            perk('ii.', tr('Không giới hạn hồ sơ thành viên & tài sản')),
            perk('iii.', tr('Vẫn mã hoá trên máy, không tài khoản')),
            perk('iv.', tr('Ủng hộ nhà phát triển độc lập')),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: a.cinnabar, minimumSize: const Size.fromHeight(54)),
              onPressed: () async {
                await store.setSetting('pro', store.isPro ? '0' : '1');
                if (context.mounted && store.isPro && reason) Navigator.of(context).pop();
              },
              child: Text(store.isPro ? tr('Tắt Pro (thử nghiệm)') : tr('Bật Pro (bản thử nghiệm)')),
            ),
            const SizedBox(height: 12),
            Text(tr('Bản thử nghiệm: chưa tích hợp thanh toán. Nút trên chỉ bật/tắt cờ Pro trên máy.'),
                style: TextStyle(color: a.inkFaint, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
