import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

typedef Picked = ({Uint8List bytes, bool pdf, String name});

class Media {
  static final _img = ImagePicker();

  static Future<Picked?> camera() async {
    final x = await _img.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
    return x == null ? null : (bytes: await x.readAsBytes(), pdf: false, name: x.name);
  }

  static Future<List<Picked>> gallery() async {
    final xs = await _img.pickMultiImage(imageQuality: 85, maxWidth: 2400);
    return [for (final x in xs) (bytes: await x.readAsBytes(), pdf: false, name: x.name)];
  }

  static Future<List<Picked>> pdfs() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final out = <Picked>[];
    for (final f in files) {
      if (f.path != null) out.add((bytes: await File(f.path!).readAsBytes(), pdf: true, name: f.name));
    }
    return out;
  }

  static Future<Uint8List?> pickBackupFile() async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty || files.first.path == null) return null;
    return File(files.first.path!).readAsBytes();
  }

  /// Ghép nhiều ảnh thành 1 PDF khổ A4 (mỗi ảnh một trang, căn giữa).
  static Future<Uint8List> imagesToPdf(List<Uint8List> images, {String title = ''}) async {
    final doc = pw.Document(title: title, creator: 'Tủ Giấy Tờ');
    for (final b in images) {
      final img = pw.MemoryImage(b);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
      ));
    }
    return doc.save();
  }

  /// Chia sẻ: ghi file giải mã vào cache tạm, chia sẻ, rồi dọn dẹp lần sau.
  static Future<void> shareBytes(Uint8List bytes, String fileName, {String? text}) async {
    final dir = Directory(p.join((await getTemporaryDirectory()).path, 'share'));
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, fileName));
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: text));
  }
}
