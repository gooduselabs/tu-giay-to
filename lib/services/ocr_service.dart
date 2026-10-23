import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../core/ocr_parser.dart';

/// OCR trên thiết bị (ML Kit, bộ chữ Latin — đọc được tiếng Việt có dấu ở mức khá).
/// Ảnh giải mã được ghi tạm vào cache rồi xoá ngay sau khi nhận dạng.
class OcrService {
  final _rec = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> textFromImage(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'ocr_${DateTime.now().microsecondsSinceEpoch}.jpg'));
    await f.writeAsBytes(bytes, flush: true);
    try {
      final r = await _rec.processImage(InputImage.fromFilePath(f.path));
      return r.text;
    } finally {
      if (await f.exists()) await f.delete();
    }
  }

  /// PDF: render tối đa [maxPages] trang thành ảnh rồi OCR.
  Future<String> textFromPdf(Uint8List bytes, {int maxPages = 2}) async {
    final doc = await PdfDocument.openData(bytes);
    final buf = StringBuffer();
    try {
      for (var i = 1; i <= doc.pagesCount && i <= maxPages; i++) {
        final page = await doc.getPage(i);
        final scale = 2000 / page.width;
        final img = await page.render(
            width: page.width * scale, height: page.height * scale,
            format: PdfPageImageFormat.jpeg, backgroundColor: '#FFFFFF', quality: 90);
        await page.close();
        if (img != null) buf.writeln(await textFromImage(img.bytes));
      }
    } finally {
      await doc.close();
    }
    return buf.toString();
  }

  Future<OcrGuess> analyse(List<({Uint8List bytes, bool pdf})> files) async {
    final text = StringBuffer();
    for (final f in files) {
      try {
        text.writeln(f.pdf ? await textFromPdf(f.bytes) : await textFromImage(f.bytes));
      } catch (_) {/* bỏ qua file lỗi */}
    }
    return parseDocumentText(text.toString());
  }

  void dispose() => _rec.close();
}
