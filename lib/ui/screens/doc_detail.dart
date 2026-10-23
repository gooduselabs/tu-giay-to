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
import '../widgets/dossier.dart';
import '../widgets/glyphs.dart';
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
    final a = context.ar;
    final u = urgencyOf(d);
    final left = daysLeft(d);
    final images = d.attachments.where((x) => x.kind == AttachmentKind.image).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Gl(Ic.close, size: 22, color: a.ink), onPressed: () => Navigator.of(context).maybePop()),
        title: Text('${tr('HỒ SƠ')}  ${fileNumber(d)}', style: TextStyle(fontFeatures: tabular, color: a.inkSoft)),
        actions: [
          IconButton(
            tooltip: tr('Sửa'),
            icon: Gl(Ic.pen, size: 20, color: a.ink),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditScreen(existing: d))),
          ),
          PopupMenuButton<String>(
            icon: Gl(Ic.menu, size: 20, color: a.ink),
            onSelected: (v) async {
              if (v == 'delete') await _delete(d);
            },
            itemBuilder: (_) => [PopupMenuItem(value: 'delete', child: Text(tr('Huỷ hồ sơ này')))],
          ),
        ],
      ),
      body: NotebookBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 48), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.type.label.toUpperCase(),
                    style: TextStyle(fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: a.cinnabar)),
                const SizedBox(height: 6),
                Text(d.title.isEmpty ? d.type.label : d.title, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32)),
                const SizedBox(height: 4),
                Text([p?.name ?? '', if (p != null && !p.isPerson && p.subtitle.isNotEmpty) p.subtitle].join(' · '),
                    style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, color: a.inkSoft, fontSize: 15)),
              ]),
            ),
            Padding(padding: const EdgeInsets.only(top: 18, left: 8), child: Stamp(u, scale: 1.25, animate: true)),
          ]),
          const SizedBox(height: 22),
          // Dải đếm ngược
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: a.ink, width: 1.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Countdown(d, size: 64, align: CrossAxisAlignment.start),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.expiryDate == null ? tr('Không thời hạn') : tr('Có giá trị đến'),
                      style: TextStyle(fontSize: 12, color: a.inkSoft)),
                  if (d.expiryDate != null)
                    Text(dmy.format(d.expiryDate!), style: TextStyle(fontFamily: serif, fontSize: 22, color: a.ink, fontFeatures: tabular)),
                  if (left != null && left <= 7)
                    InkLink(tr('Xem cách gia hạn'), icon: Ic.book,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(type: d.type)))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          // Số giấy tờ — chạm để hiện
          InkWell(
            onTap: () => setState(() => _reveal = !_reveal),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('SỐ GIẤY TỜ'), style: TextStyle(fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w700, color: a.inkSoft)),
                    const SizedBox(height: 4),
                    Text(d.number.isEmpty ? '—' : shownNumber(d, reveal: _reveal),
                        style: TextStyle(fontSize: 22, letterSpacing: 2.2, fontWeight: FontWeight.w500, color: a.ink, fontFeatures: tabular)),
                  ]),
                ),
                Text(_reveal ? tr('ẩn') : tr('hiện'),
                    style: TextStyle(color: a.cinnabar, fontWeight: FontWeight.w600, decoration: TextDecoration.underline, decorationColor: a.cinnabar)),
              ]),
            ),
          ),
          // Hàng thao tác: chữ + glyph, ngăn bằng nét mảnh
          Container(
            decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: a.rule))),
            child: IntrinsicHeight(
              child: Row(children: [
                _Action(Ic.expand, tr('Xuất trình'), () => _quickShow(d)),
                VerticalDivider(color: a.rule, width: 1),
                _Action(Ic.share, tr('Chia sẻ'), () => _share(d)),
                VerticalDivider(color: a.rule, width: 1),
                _Action(Ic.book, tr('Gia hạn'),
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(type: d.type)))),
                VerticalDivider(color: a.rule, width: 1),
                _Action(Ic.camera, tr('Thêm ảnh'),
                    () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocEditScreen(existing: d)))),
              ]),
            ),
          ),
          SectionLabel(tr('Thông tin'), index: 'i.', padding: const EdgeInsets.fromLTRB(0, 28, 0, 4)),
          LedgerRow(tr('Hồ sơ'), p?.name ?? '—'),
          if (d.holderName.isNotEmpty) LedgerRow(tr('Họ tên trên giấy tờ'), d.holderName),
          LedgerRow(tr('Ngày cấp'), d.issueDate == null ? '—' : dmy.format(d.issueDate!)),
          LedgerRow(tr('Hết hạn'), d.expiryDate == null ? tr('Không thời hạn') : '${dmy.format(d.expiryDate!)} · ${statusText(d)}',
              color: u == Urgency.green || u == Urgency.none ? null : urgencyColor(u, a)),
          if (d.type == DocType.cccd && p?.birthDate != null && nextCccdMilestone(p!.birthDate!) != null)
            LedgerRow(tr('Mốc đổi thẻ tiếp theo'), () {
              final m = nextCccdMilestone(p.birthDate!)!;
              return tr('{age} tuổi · {date}', {'age': m.age, 'date': dmy.format(m.date)});
            }()),
          LedgerRow(tr('Nhắc trước'), d.expiryDate == null ? '—' : d.reminderDays.map((x) => tr('{n} ngày', {'n': x})).join(' · '),
              last: d.notes.isEmpty),
          if (d.notes.isNotEmpty) LedgerRow(tr('Ghi chú'), d.notes, last: true),
          SectionLabel(tr('Phiếu đính kèm ({n})', {'n': d.attachments.length}),
              index: 'ii.',
              padding: const EdgeInsets.fromLTRB(0, 28, 0, 12),
              trailing: images.length > 1 ? InkLink(tr('Gộp PDF'), icon: Ic.pdf, onTap: () => _mergeShare(d)) : null),
          if (d.attachments.isEmpty)
            Text(tr('Chưa có ảnh/PDF. Thêm mặt trước, mặt sau hoặc file PDF.'), style: TextStyle(color: a.inkSoft))
          else
            Wrap(spacing: 14, runSpacing: 18, children: [
              for (var i = 0; i < d.attachments.length; i++)
                Transform.rotate(
                  angle: i.isEven ? -.018 : .022,
                  child: SizedBox(
                    width: 100,
                    height: 128,
                    child: AttachmentThumb(
                      attachment: d.attachments[i],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(doc: d, initialIndex: i))),
                    ),
                  ),
                ),
            ]),
        ]),
      ),
    );
  }

  Future<void> _quickShow(Document d) async {
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => QuickShowScreen(doc: d),
      transitionsBuilder: (_, an, _, c) => FadeTransition(opacity: an, child: c),
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
      final at = d.attachments.first;
      await Media.shareBytes(await store.readAttachment(at), '${d.type.name}.${at.kind == AttachmentKind.pdf ? 'pdf' : 'jpg'}');
      return;
    }
    await _mergeShare(d);
  }

  Future<void> _mergeShare(Document d) async {
    final store = AppScope.store(context);
    final imgs = <Uint8List>[];
    for (final at in d.attachments.where((x) => x.kind == AttachmentKind.image)) {
      imgs.add(await store.readAttachment(at));
    }
    if (imgs.isEmpty) return;
    await Media.shareBytes(await Media.imagesToPdf(imgs, title: d.title), '${d.type.name}.pdf');
  }

  Future<void> _delete(Document d) async {
    final a = context.ar;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Huỷ hồ sơ này?')),
        content: Text(tr('Ảnh và PDF đính kèm sẽ bị xoá vĩnh viễn khỏi máy.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Giữ lại'), style: TextStyle(color: a.ink))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: a.cinnabar), onPressed: () => Navigator.pop(c, true), child: Text(tr('Xoá'))),
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
  final Ic icon;
  final String label;
  final VoidCallback onTap;
  const _Action(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Gl(icon, size: 22, color: a.ink),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: a.ink)),
          ]),
        ),
      ),
    );
  }
}
