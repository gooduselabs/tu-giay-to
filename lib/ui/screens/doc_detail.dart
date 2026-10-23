import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../services/media.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/common.dart';
import '../widgets/wallet_card.dart';
import 'doc_edit.dart';
import 'guide.dart';
import 'quick_show.dart';
import 'viewer.dart';

class DocDetailScreen extends StatefulWidget {
  final String docId;
  const DocDetailScreen({super.key, required this.docId});
  @override
  State<DocDetailScreen> createState() => _DocDetailScreenState();
}

class _DocDetailScreenState extends State<DocDetailScreen> {
  bool _reveal = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final d = store.docs[widget.docId];
    if (d == null) return const Scaffold();
    final p = store.profiles[d.profileId];
    final t = Theme.of(context);
    final muted = t.colorScheme.onSurface.withValues(alpha: .6);
    final left = daysLeft(d);
    final images = d.attachments.where((a) => a.kind == AttachmentKind.image).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(d.type.label),
        actions: [
          IconButton(
            tooltip: tr('Sửa'),
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditScreen(existing: d))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') await _delete(d);
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(tr('Xoá giấy tờ')))],
          ),
        ],
      ),
      body: NotebookBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
          GestureDetector(
            onLongPress: () => setState(() => _reveal = !_reveal),
            child: WalletCard(doc: d, ownerName: p?.name, reveal: _reveal, onTap: () => setState(() => _reveal = !_reveal)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_reveal ? tr('Chạm thẻ để ẩn số') : tr('Chạm thẻ để hiện đầy đủ số'),
                textAlign: TextAlign.center, style: t.textTheme.bodySmall?.copyWith(color: muted)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            _Action(icon: Icons.fullscreen, label: tr('Xuất trình'), onTap: () => _quickShow(d)),
            _Action(icon: Icons.ios_share, label: tr('Chia sẻ'), onTap: () => _share(d)),
            _Action(icon: Icons.menu_book_outlined, label: tr('Gia hạn'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(type: d.type)))),
            _Action(icon: Icons.add_a_photo_outlined, label: tr('Thêm ảnh'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditScreen(existing: d)))),
          ]),
          if (urgencyOf(d) == Urgency.expired || urgencyOf(d) == Urgency.red) ...[
            const SizedBox(height: 16),
            _Banner(
              color: urgencyColor(urgencyOf(d)),
              text: left! < 0
                  ? tr('Giấy tờ đã quá hạn. Xem hướng dẫn gia hạn để chuẩn bị hồ sơ.')
                  : tr('Sắp hết hạn — nên làm thủ tục ngay trong tuần này.'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(type: d.type))),
            ),
          ],
          SectionLabel(tr('Thông tin')),
          Card(
            child: Column(children: [
              _Row(tr('Hồ sơ'), p?.name ?? '—'),
              _Row(tr('Số giấy tờ'), d.number.isEmpty ? '—' : d.number, mono: true),
              if (d.holderName.isNotEmpty) _Row(tr('Họ tên trên giấy tờ'), d.holderName),
              _Row(tr('Ngày cấp'), d.issueDate == null ? '—' : dmy.format(d.issueDate!)),
              _Row(tr('Hết hạn'), d.expiryDate == null ? tr('Không thời hạn') : '${dmy.format(d.expiryDate!)} · ${statusText(d)}'),
              if (d.type == DocType.cccd && p?.birthDate != null) _cccdHint(p!),
              _Row(tr('Nhắc trước'),
                  d.expiryDate == null ? '—' : d.reminderDays.map((x) => tr('{n} ngày', {'n': x})).join(' · '),
                  last: d.notes.isEmpty),
              if (d.notes.isNotEmpty) _Row(tr('Ghi chú'), d.notes, last: true),
            ]),
          ),
          SectionLabel(tr('Tệp đính kèm ({n})', {'n': d.attachments.length}),
              trailing: images.length > 1
                  ? TextButton.icon(
                      onPressed: () => _mergeShare(d),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                      label: Text(tr('Gộp PDF')))
                  : null),
          if (d.attachments.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(tr('Chưa có ảnh/PDF. Thêm mặt trước, mặt sau hoặc file PDF.'),
                    style: t.textTheme.bodyMedium?.copyWith(color: muted)),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: .82,
              children: [
                for (var i = 0; i < d.attachments.length; i++)
                  AttachmentThumb(
                    attachment: d.attachments[i],
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ViewerScreen(doc: d, initialIndex: i))),
                  ),
              ],
            ),
        ]),
      ),
    );
  }

  Widget _cccdHint(Profile p) {
    final m = nextCccdMilestone(p.birthDate!);
    if (m == null) return const SizedBox.shrink();
    return _Row(tr('Mốc đổi thẻ tiếp theo'), tr('{age} tuổi · {date}', {'age': m.age, 'date': dmy.format(m.date)}));
  }

  Future<void> _quickShow(Document d) async {
    await Navigator.of(context).push(PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => QuickShowScreen(doc: d),
      transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
    ));
  }

  Future<void> _share(Document d) async {
    final store = AppScope.store(context);
    if (d.attachments.isEmpty) {
      final text = '${d.title.isEmpty ? d.type.label : d.title}: ${d.number}'
          '${d.expiryDate != null ? ' — ${tr('hết hạn')} ${dmy.format(d.expiryDate!)}' : ''}';
      await Media.shareBytes(Uint8List.fromList(text.codeUnits), 'giay-to.txt', text: text);
      return;
    }
    if (d.attachments.length == 1) {
      final a = d.attachments.first;
      final bytes = await store.readAttachment(a);
      await Media.shareBytes(bytes, '${_slug(d)}.${a.kind == AttachmentKind.pdf ? 'pdf' : 'jpg'}');
      return;
    }
    await _mergeShare(d);
  }

  Future<void> _mergeShare(Document d) async {
    final store = AppScope.store(context);
    final imgs = <Uint8List>[];
    for (final a in d.attachments.where((a) => a.kind == AttachmentKind.image)) {
      imgs.add(await store.readAttachment(a));
    }
    if (imgs.isEmpty) return;
    final pdf = await Media.imagesToPdf(imgs, title: d.title);
    await Media.shareBytes(pdf, '${_slug(d)}.pdf');
  }

  String _slug(Document d) => d.type.name;

  Future<void> _delete(Document d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Xoá giấy tờ?')),
        content: Text(tr('Ảnh và PDF đính kèm sẽ bị xoá vĩnh viễn khỏi máy.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Huỷ'))),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Palette.red),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr('Xoá'))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AppScope.store(context).deleteDocument(d.id);
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Action({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: t.colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: Palette.brass.withValues(alpha: .5)),
              ),
              child: Icon(icon, color: t.brightness == Brightness.dark ? Palette.brassLight : Palette.ink),
            ),
            const SizedBox(height: 6),
            Text(label, style: t.textTheme.labelMedium),
          ]),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String k, v;
  final bool mono, last;
  const _Row(this.k, this.v, {this.mono = false, this.last = false});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: t.colorScheme.outlineVariant.withValues(alpha: .6)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 130,
            child: Text(k, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .6)))),
        Expanded(
          child: SelectableText(v,
              style: t.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: mono ? 1.2 : null,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final String text;
  final VoidCallback onTap;
  const _Banner({required this.color, required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .45)),
          ),
          child: Row(children: [
            Icon(Icons.notifications_active_outlined, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right, color: color),
          ]),
        ),
      );
}
