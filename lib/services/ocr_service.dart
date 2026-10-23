import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../core/ocr_parser.dart';

/// Nhận dạng hoàn toàn trên máy (ML Kit): chữ Latin (có dấu tiếng Việt) kèm toạ độ dòng,
/// cùng mã QR/mã vạch. Ảnh giải mã chỉ ghi tạm vào cache rồi xoá ngay.
class OcrService {
  final _rec = TextRecognizer(script: TextRecognitionScript.latin);
  final _codes = BarcodeScanner(formats: [BarcodeFormat.qrCode, BarcodeFormat.pdf417, BarcodeFormat.dataMatrix, BarcodeFormat.code128]);

  Future<OcrPage> pageFromImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'ocr_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    await f.writeAsBytes(bytes, flush: true);
    try {
      final input = InputImage.fromFilePath(f.path);
      final lines = <OcrLine>[];
      try {
        final r = await _rec.processImage(input);
        for (final b in r.blocks) {
          for (final l in b.lines) {
            final box = l.boundingBox;
            lines.add(OcrLine(l.text, box.left, box.top, box.right, box.bottom));
          }
        }
      } catch (_) {}
      // ML Kit trả dòng theo khối; sắp lại theo hàng (trên→dưới, trái→phải) để "dòng dưới" có nghĩa.
      lines.sort((a, b) {
        final sameRow = (a.cy - b.cy).abs() < (a.h < b.h ? a.h : b.h) * .5;
        return sameRow ? a.l.compareTo(b.l) : a.cy.compareTo(b.cy);
      });
      final codes = <String>[];
      try {
        for (final c in await _codes.processImage(input)) {
          final v = c.rawValue ?? c.displayValue;
          if (v != null && v.trim().isNotEmpty) codes.add(v);
        }
      } catch (_) {}
      return OcrPage(lines, codes: codes);
    } finally {
      if (await f.exists()) await f.delete();
    }
  }

  /// PDF: render tối đa [maxPages] trang thành ảnh rồi nhận dạng từng trang.
  Future<List<OcrPage>> pagesFromPdf(Uint8List bytes, {int maxPages = 3}) async {
    final doc = await PdfDocument.openData(bytes);
    final out = <OcrPage>[];
    try {
      for (var i = 1; i <= doc.pagesCount && i <= maxPages; i++) {
        final page = await doc.getPage(i);
        final scale = 2200 / page.width;
        final img = await page.render(
            width: page.width * scale, height: page.height * scale,
            format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF', quality: 92);
        await page.close();
        if (img != null) out.add(await pageFromImage(img.bytes));
      }
    } finally {
      await doc.close();
    }
    return out;
  }

  /// Gộp mọi ảnh/trang của cùng một giấy tờ (mặt trước + mặt sau) rồi nhận dạng.
  Future<OcrGuess> analyse(List<({Uint8List bytes, bool pdf})> files) async {
    final pages = <OcrPage>[];
    for (final f in files) {
      try {
        if (f.pdf) {
          pages.addAll(await pagesFromPdf(f.bytes));
        } else {
          pages.add(await pageFromImage(f.bytes));
        }
      } catch (_) {/* bỏ qua file lỗi */}
    }
    return parsePages(pages);
  }

  void dispose() {
    _rec.close();
    _codes.close();
  }
}
