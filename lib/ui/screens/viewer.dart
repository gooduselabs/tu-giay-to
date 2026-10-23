import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../widgets/glyphs.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../services/media.dart';
import '../scope.dart';

/// Trình xem: ảnh (phóng to/thu nhỏ) và PDF nhiều trang (vuốt theo trang).
class ViewerScreen extends StatefulWidget {
  final Document doc;
  final int initialIndex;
  const ViewerScreen({super.key, required this.doc, this.initialIndex = 0});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final _pc = PageController(initialPage: widget.initialIndex);
  late int _i = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    final atts = widget.doc.attachments;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0D12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('${atts[_i].label}  ·  ${_i + 1}/${atts.length}',
            style: const TextStyle(color: Colors.white, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Gl(Ic.share),
            tooltip: tr('Chia sẻ'),
            onPressed: () async {
              final a = atts[_i];
              final b = await AppScope.store(context).readAttachment(a);
              await Media.shareBytes(b, '${widget.doc.type.name}-${_i + 1}.${a.kind == AttachmentKind.pdf ? 'pdf' : 'jpg'}');
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: atts.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (c, i) => _AttachmentView(attachment: atts[i]),
      ),
    );
  }
}

class _AttachmentView extends StatefulWidget {
  final Attachment attachment;
  const _AttachmentView({required this.attachment});
  @override
  State<_AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<_AttachmentView> {
  Future<Uint8List>? _bytes;
  PdfControllerPinch? _pdf;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bytes ??= AppScope.store(context).readAttachment(widget.attachment).then((b) {
      if (widget.attachment.kind == AttachmentKind.pdf && AppScope.of(context).platformServices) {
        setState(() => _pdf = PdfControllerPinch(document: PdfDocument.openData(b)));
      }
      return b;
    });
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        if (widget.attachment.kind == AttachmentKind.image) {
          return InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(s.data!)));
        }
        if (_pdf == null) {
          return const Center(child: Gl(Ic.pdf, color: Colors.white54, size: 64));
        }
        return Column(children: [
          Expanded(child: PdfViewPinch(controller: _pdf!, scrollDirection: Axis.vertical)),
          PdfPageNumber(
            controller: _pdf!,
            builder: (_, state, page, pages) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(tr('Trang {p}/{n}', {'p': page, 'n': pages ?? 0}), style: const TextStyle(color: Colors.white70)),
            ),
          ),
        ]);
      },
    );
  }
}
