import 'dart:typed_data';

import 'package:flutter/material.dart';

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
    final a = widget.attachment;
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: Stack(fit: StackFit.expand, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: t.colorScheme.surfaceContainerHighest,
                child: a.kind == AttachmentKind.pdf
                    ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.picture_as_pdf_outlined, size: 34, color: Palette.red),
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
            if (widget.onRemove != null)
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: widget.onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
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
