import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/backup_codec.dart';
import '../../core/expiry.dart';
import '../../data/sample_data.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
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
            SectionLabel(tr('Sao lưu & khôi phục'), index: 'i.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            BackupSection(store: store),
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
                    if (!await LockGate.controller.confirm(() => Biometric.authenticate(tr('Xác nhận bật khoá')))) return;
                  }
                  await store.setSetting('lock', v ? '1' : '0');
                },
              ),
            ),
            if (store.lockEnabled)
              _Row(
                icon: Ic.lock,
                title: tr('Khoá lại sau khi rời ứng dụng'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final g in [(0, tr('Ngay')), (30, '30s'), (60, tr('1 phút')), (300, tr('5 phút'))])
                    _TextToggle(g.$2, store.lockGrace.inSeconds == g.$1, () => store.setSetting('lock_grace', '${g.$1}')),
                ]),
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
            SectionLabel(tr('Dữ liệu mẫu'), index: 'v.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            if (!store.hasSamples)
              _Row(icon: Ic.spark, title: tr('Thêm dữ liệu mẫu'), subtitle: tr('Gia đình hư cấu, gắn nhãn MẪU, không tính vào giới hạn'),
                  onTap: () => seedSamples(store, art: sampleArt))
            else
              _Row(icon: Ic.trash, title: tr('Xoá dữ liệu mẫu'), onTap: () => store.removeSamples()),
            const SizedBox(height: 30),
            Text('Tủ Giấy Tờ 0.4.0 — gooduselabs',
                style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 13, color: a.inkFaint)),
          ]),
        ),
      ),
    );
  }

}

void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

enum RestoreMode { replace, merge }

/// Hỏi trước khi ghi đè. Trả về null nếu huỷ.
Future<RestoreMode?> confirmRestore(BuildContext context, {required int current}) => showDialog<RestoreMode>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Khôi phục bản sao lưu?')),
        content: Text(current == 0
            ? tr('Dữ liệu trong bản sao lưu sẽ được nạp vào máy.')
            : tr('Trên máy đang có {n} giấy tờ. "Thay thế" xoá hết rồi nạp bản sao lưu. "Gộp" giữ dữ liệu hiện có và chỉ thêm những mục chưa có.',
                {'n': current})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Huỷ'), style: TextStyle(color: c.ar.ink))),
          if (current > 0)
            OutlinedButton(onPressed: () => Navigator.pop(c, RestoreMode.merge), child: Text(tr('Gộp'))),
          FilledButton(
              onPressed: () => Navigator.pop(c, RestoreMode.replace), child: Text(current > 0 ? tr('Thay thế') : tr('Khôi phục'))),
        ],
      ),
    );

/// Tạo bản sao lưu mã hoá. [toDevice]: lưu qua hộp thoại hệ thống; ngược lại mở bảng chia sẻ.
Future<void> backupFlow(BuildContext context, AppStore store, {bool toDevice = false}) async {
  final pw = await askPassword(context, confirm: true);
  if (pw == null || !context.mounted) return;
  snack(context, tr('Đang mã hoá bản sao lưu…'));
  try {
    final bytes = await store.exportBackup(pw);
    final name = Media.backupFileName(DateTime.now());
    final ok = toDevice
        ? await Media.saveToDevice(bytes, name)
        : await Media.shareBytes(bytes, name, text: tr('Bản sao lưu Tủ Giấy Tờ (đã mã hoá)'));
    if (!ok) return;
    await store.markBackedUp();
    if (context.mounted) snack(context, toDevice ? tr('Đã lưu {f}', {'f': name}) : tr('Đã tạo bản sao lưu'));
  } catch (e) {
    if (context.mounted) snack(context, tr('Không tạo được bản sao lưu: {e}', {'e': e}));
  }
}

/// Khôi phục từ dữ liệu file (chọn trong máy hoặc được mở/chia sẻ vào ứng dụng).
Future<void> restoreFlow(BuildContext context, AppStore store, Uint8List bytes) async {
  if (!BackupCodec.looksLike(bytes)) {
    snack(context, tr('File sao lưu không hợp lệ'));
    return;
  }
  final pw = await askPassword(context, confirm: false);
  if (pw == null || !context.mounted) return;
  final mode = await confirmRestore(context, current: store.docs.values.where((d) => !d.isSample).length);
  if (mode == null || !context.mounted) return;
  try {
    final n = await store.importBackup(bytes, pw, merge: mode == RestoreMode.merge);
    if (context.mounted) {
      snack(context, mode == RestoreMode.merge ? tr('Đã gộp thêm {n} giấy tờ', {'n': n}) : tr('Đã khôi phục {n} giấy tờ', {'n': n}));
    }
  } on FormatException catch (e) {
    if (context.mounted) snack(context, e.message == 'wrong-password' ? tr('Sai mật khẩu') : tr('File sao lưu không hợp lệ'));
  }
}

/// Sao lưu và khôi phục bằng file, chỉ lưu trên máy (không dùng tài khoản hay đám mây).
class BackupSection extends StatelessWidget {
  final AppStore store;
  const BackupSection({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final last = store.lastBackup;
    final overdue = store.backupOverdue();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('LẦN SAO LƯU CUỐI'), style: TextStyle(fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: a.inkSoft)),
              const SizedBox(height: 4),
              Text(last == null ? tr('Chưa sao lưu lần nào') : fmtTime(last),
                  style: TextStyle(fontFamily: serif, fontSize: 20, color: a.ink, fontFeatures: tabular)),
            ]),
          ),
          if (last != null) Stamp(overdue ? Urgency.expired : Urgency.green, label: overdue ? tr('ĐÃ LÂU') : tr('MỚI'), scale: .9),
        ]),
      ),
      if (overdue)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: a.cinnabar, width: 3)), color: a.cinnabar.withValues(alpha: .06)),
          child: Text(
              last == null
                  ? tr('Bạn chưa sao lưu lần nào. Nếu mất máy, giấy tờ sẽ mất theo. Hãy tạo một bản và gửi vào Zalo, email hoặc Drive của bạn.')
                  : tr('Đã hơn 30 ngày chưa sao lưu. Nên tạo bản mới và cất ra ngoài máy.'),
              style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 14, height: 1.35, color: a.ink)),
        ),
      _Row(icon: Ic.share, title: tr('Sao lưu ra file'), subtitle: tr('Mã hoá bằng mật khẩu, rồi gửi qua Zalo, Drive, email, Tệp…'),
          onTap: () => backupFlow(context, store)),
      _Row(icon: Ic.folderOpen, title: tr('Lưu vào máy'), subtitle: tr('Chọn thư mục, ví dụ Tải về (Downloads)'),
          onTap: () => backupFlow(context, store, toDevice: true)),
      _Row(icon: Ic.restore, title: tr('Khôi phục từ file'), subtitle: tr('File .tgtbak — thay thế hoặc gộp với dữ liệu hiện có'),
          onTap: () async {
            final bytes = await Media.pickBackupFile();
            if (bytes != null && context.mounted) await restoreFlow(context, store, bytes);
          }),
    ]);
  }
}

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
