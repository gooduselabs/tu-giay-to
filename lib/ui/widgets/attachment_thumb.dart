import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'glyphs.dart';

import '../../core/models.dart';
import '../scope.dart';
import '../theme.dart';

/// Ảnh thu nhỏ — giải mã trong bộ nhớ, không ghi ra đĩa.
class AttachmentThumb extends StatefulWidget {
  final Attachment attachment;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  const AttachmentThumb({super.key, required this.attachment, this.onTap, this.onRemove});
  @override
  State<AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<AttachmentThumb> {
  Future<Uint8List>? _bytes;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.attachment.kind == AttachmentKind.image) {
      _bytes ??= AppScope.store(context).readAttachment(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ar = t.extension<Archive>()!;
    final a = widget.attachment;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: Container(
                decoration: BoxDecoration(color: ar.card, border: Border.all(color: ar.ruleStrong)),
                padding: const EdgeInsets.all(4),
                child: a.kind == AttachmentKind.pdf
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Gl(Ic.pdf, size: 34, color: ar.cinnabar),
                        const SizedBox(height: 4),
                        Text('PDF', style: t.textTheme.labelSmall),
                      ])
                    : FutureBuilder<Uint8List>(
                        future: _bytes,
                        builder: (c, s) => s.hasData
                            ? Image.memory(s.data!, fit: BoxFit.cover, gaplessPlayback: true, cacheWidth: 400)
                            : const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
              ),
            ),
            Positioned(top: -4, left: 10, child: Gl(Ic.clip, size: 22, color: ar.inkSoft, weight: 1.6)),
            if (widget.onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: ar.ink),
                    child: Gl(Ic.close, size: 14, color: ar.paper),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.textTheme.labelMedium),
      ]),
    );
  }
}
