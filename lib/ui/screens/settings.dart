import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/sample_data.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../services/media.dart';
import '../../services/security.dart';
import '../app.dart';
import '../sample_art.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final t = Theme.of(context);
    Widget group(List<Widget> children) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Card(clipBehavior: Clip.antiAlias, child: Column(children: children)),
        );
    return Scaffold(
      body: NotebookBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.only(bottom: 40), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 20, 4),
              child: Text(tr('Cài đặt'), style: t.textTheme.displaySmall?.copyWith(fontSize: 32)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _ProBanner(store: store),
            ),
            SectionLabel(tr('Giao diện')),
            group([
              Padding(
                padding: const EdgeInsets.all(12),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'system', label: Text(tr('Theo máy')), icon: const Icon(Icons.brightness_auto_outlined)),
                    ButtonSegment(value: 'light', label: Text(tr('Sáng')), icon: const Icon(Icons.light_mode_outlined)),
                    ButtonSegment(value: 'dark', label: Text(tr('Tối')), icon: const Icon(Icons.dark_mode_outlined)),
                  ],
                  selected: {store.settings['theme'] ?? 'system'},
                  onSelectionChanged: (s) => store.setSetting('theme', s.first),
                  showSelectedIcon: false,
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(tr('Ngôn ngữ')),
                trailing: DropdownButton<String>(
                  value: store.locale,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: (v) => store.setSetting('locale', v!),
                ),
              ),
            ]),
            SectionLabel(tr('Bảo mật')),
            group([
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint),
                title: Text(tr('Khoá bằng vân tay / khuôn mặt')),
                subtitle: Text(tr('Yêu cầu khi mở ứng dụng và khi xuất trình')),
                value: store.lockEnabled,
                onChanged: (v) async {
                  if (v && AppScope.of(context).platformServices) {
                    if (!await Biometric.available()) {
                      if (context.mounted) _snack(context, tr('Thiết bị chưa cài vân tay/khuôn mặt hoặc mã khoá màn hình.'));
                      return;
                    }
                    if (!await Biometric.authenticate(tr('Xác nhận bật khoá'))) return;
                  }
                  await store.setSetting('lock', v ? '1' : '0');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.enhanced_encryption_outlined),
                title: Text(tr('Mã hoá trên máy')),
                subtitle: Text(tr('CSDL SQLCipher + tệp AES-256-GCM. Khoá lưu trong Keystore/Keychain. Không cần tài khoản.')),
              ),
            ]),
            SectionLabel(tr('Nhắc nhở')),
            group([
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(tr('Cho phép thông báo')),
                subtitle: Text(tr('Nhắc lúc {h}:00 sáng theo lịch từng giấy tờ', {'h': store.reminderHour})),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await TuGiayToApp.notificationPermission?.call() ?? false;
                  await store.resync();
                  if (context.mounted) _snack(context, ok ? tr('Đã bật thông báo nhắc hạn') : tr('Chưa được cấp quyền thông báo'));
                },
              ),
            ]),
            SectionLabel(tr('Sao lưu')),
            group([
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: Text(tr('Tạo bản sao lưu mã hoá')),
                subtitle: Text(tr('File .tgtbak bảo vệ bằng mật khẩu của bạn')),
                onTap: () => _backup(context, store),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: Text(tr('Khôi phục từ bản sao lưu')),
                subtitle: Text(tr('Thay thế toàn bộ dữ liệu hiện có')),
                onTap: () => _restore(context, store),
              ),
            ]),
            SectionLabel(tr('Dữ liệu mẫu')),
            group([
              if (!store.hasSamples)
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: Text(tr('Thêm dữ liệu mẫu')),
                  subtitle: Text(tr('Gia đình hư cấu, gắn nhãn MẪU, không tính vào giới hạn')),
                  onTap: () => seedSamples(store, art: sampleArt),
                )
              else
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined),
                  title: Text(tr('Xoá dữ liệu mẫu')),
                  onTap: () => store.removeSamples(),
                ),
            ]),
            const SizedBox(height: 24),
            Center(
              child: Text('Tủ Giấy Tờ 1.0 · gooduselabs',
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .45))),
            ),
          ]),
        ),
      ),
    );
  }

  static void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  static Future<String?> _askPassword(BuildContext context, {required bool confirm}) {
    final a = TextEditingController(), b = TextEditingController();
    String? err;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(confirm ? tr('Đặt mật khẩu sao lưu') : tr('Nhập mật khẩu sao lưu')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (confirm)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(tr('Không thể khôi phục nếu quên mật khẩu. Tối thiểu 8 ký tự.'),
                    style: Theme.of(ctx).textTheme.bodySmall),
              ),
            TextField(controller: a, obscureText: true, autofocus: true, decoration: InputDecoration(labelText: tr('Mật khẩu'))),
            if (confirm) ...[
              const SizedBox(height: 10),
              TextField(controller: b, obscureText: true, decoration: InputDecoration(labelText: tr('Nhập lại'))),
            ],
            if (err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err!, style: const TextStyle(color: Palette.red))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Huỷ'))),
            FilledButton(
              onPressed: () {
                if (confirm && a.text.length < 8) return set(() => err = tr('Mật khẩu quá ngắn'));
                if (confirm && a.text != b.text) return set(() => err = tr('Mật khẩu không khớp'));
                Navigator.pop(ctx, a.text);
              },
              child: Text(tr('Tiếp tục')),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _backup(BuildContext context, AppStore store) async {
    final pw = await _askPassword(context, confirm: true);
    if (pw == null || !context.mounted) return;
    _snack(context, tr('Đang mã hoá bản sao lưu…'));
    final bytes = await store.exportBackup(pw);
    final name = 'tu-giay-to-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.tgtbak';
    LockGate.suppress = true;
    try {
      await Media.shareBytes(bytes, name, text: tr('Bản sao lưu Tủ Giấy Tờ (đã mã hoá)'));
    } finally {
      LockGate.suppress = false;
    }
  }

  static Future<void> _restore(BuildContext context, AppStore store) async {
    LockGate.suppress = true;
    final bytes = await Media.pickBackupFile().whenComplete(() => LockGate.suppress = false);
    if (bytes == null || !context.mounted) return;
    final pw = await _askPassword(context, confirm: false);
    if (pw == null || !context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Khôi phục?')),
        content: Text(tr('Dữ liệu hiện tại trên máy sẽ bị thay thế bằng bản sao lưu.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Huỷ'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Khôi phục'))),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      final n = await store.importBackup(bytes, pw);
      if (context.mounted) _snack(context, tr('Đã khôi phục {n} giấy tờ', {'n': n}));
    } on FormatException catch (e) {
      if (context.mounted) {
        _snack(context, e.message == 'wrong-password' ? tr('Sai mật khẩu') : tr('File sao lưu không hợp lệ'));
      }
    }
  }
}

class _ProBanner extends StatelessWidget {
  final AppStore store;
  const _ProBanner({required this.store});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen())),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF1C2230), Color(0xFF3A3324)]),
        ),
        child: Row(children: [
          const Icon(Icons.workspace_premium, color: Palette.brassLight, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.isPro ? tr('Tủ Giấy Tờ Pro') : tr('Bản miễn phí'),
                  style: const TextStyle(fontFamily: serif, color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                store.isPro
                    ? tr('Không giới hạn giấy tờ')
                    : tr('Đã dùng {n}/{max} giấy tờ · Nâng cấp để không giới hạn',
                        {'n': store.userDocCount, 'max': AppStore.freeLimit}),
                style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 13),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Palette.brassLight),
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
    Widget perk(IconData i, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Icon(i, color: Palette.brassLight, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 15.5))),
          ]),
        );
    return Scaffold(
      backgroundColor: Palette.night,
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(padding: const EdgeInsets.fromLTRB(28, 0, 28, 40), children: [
          const Icon(Icons.workspace_premium, size: 64, color: Palette.brass),
          const SizedBox(height: 12),
          Text(tr('Tủ Giấy Tờ Pro'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: serif, fontSize: 32, color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            reason
                ? tr('Bản miễn phí lưu tối đa {max} giấy tờ. Nâng cấp để thêm tiếp.', {'max': AppStore.freeLimit})
                : tr('Cho cả gia đình, không giới hạn.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 15),
          ),
          const SizedBox(height: 28),
          perk(Icons.all_inclusive, tr('Không giới hạn số giấy tờ')),
          perk(Icons.family_restroom, tr('Không giới hạn hồ sơ thành viên & tài sản')),
          perk(Icons.lock_outline, tr('Vẫn mã hoá trên máy, không tài khoản')),
          perk(Icons.favorite_outline, tr('Ủng hộ nhà phát triển độc lập')),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Palette.brass, minimumSize: const Size.fromHeight(54)),
            onPressed: () async {
              await store.setSetting('pro', store.isPro ? '0' : '1');
              if (context.mounted && store.isPro && reason) Navigator.of(context).pop();
            },
            child: Text(store.isPro ? tr('Tắt Pro (thử nghiệm)') : tr('Bật Pro (bản thử nghiệm)')),
          ),
          const SizedBox(height: 12),
          Text(tr('Bản thử nghiệm: chưa tích hợp thanh toán. Nút trên chỉ bật/tắt cờ Pro trên máy.'),
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: .5), fontSize: 12)),
        ]),
      ),
    );
  }
}
