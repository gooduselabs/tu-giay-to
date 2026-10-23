import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/lock_controller.dart';

typedef Picked = ({Uint8List bytes, bool pdf, String name});

class Media {
  static final _img = ImagePicker();

  static const backupExt = 'tgtbak';
  static String backupFileName(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'tu-giay-to-${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}.$backupExt';
  }

  // Mọi thao tác mở Activity khác đều chạy trong appLock.guard, để việc
  // quay lại ứng dụng không bị tính là rời đi rồi khoá lại.
  static Future<Picked?> camera() => appLock.guard(_camera);
  static Future<List<Picked>> gallery() => appLock.guard(_gallery);
  static Future<List<Picked>> pdfs() => appLock.guard(_pdfs);

  static Future<Picked?> _camera() async {
    final x = await _img.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
    return x == null ? null : (bytes: await x.readAsBytes(), pdf: false, name: x.name);
  }

  static Future<List<Picked>> _gallery() async {
    final xs = await _img.pickMultiImage(imageQuality: 85, maxWidth: 2400);
    return [for (final x in xs) (bytes: await x.readAsBytes(), pdf: false, name: x.name)];
  }

  static Future<List<Picked>> _pdfs() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    final out = <Picked>[];
    for (final f in files) {
      if (f.path != null) out.add((bytes: await File(f.path!).readAsBytes(), pdf: true, name: f.name));
    }
    return out;
  }

  static Future<Uint8List?> pickBackupFile() => appLock.guard(() async {
        // .tgtbak không có MIME chuẩn, nên chọn mọi loại tệp; định dạng được kiểm tra khi giải mã.
        final files = await FilePicker.pickFiles(type: FileType.any);
        if (files.isEmpty || files.first.path == null) return null;
        return File(files.first.path!).readAsBytes();
      });

  /// Lưu vào bộ nhớ máy qua hộp thoại "Lưu thành" của hệ thống (chọn được Tải về / Downloads).
  /// Trả về true nếu đã lưu.
  static Future<bool> saveToDevice(Uint8List bytes, String fileName) => appLock.guard(() async {
        final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, dialogTitle: fileName);
        return uri != null;
      });

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
  static Future<Directory> _shareDir() async => Directory(p.join((await getTemporaryDirectory()).path, 'share'));

  /// Xoá mọi file tạm đã giải mã để chia sẻ (gọi khi mở ứng dụng).
  static Future<void> clearShareCache() async {
    try {
      final d = await _shareDir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  /// Chia sẻ qua bảng chia sẻ hệ thống. File giải mã nằm trong thư mục riêng (mỗi lần một thư mục con)
  /// và bị xoá ngay khi ứng dụng nhận lại kết quả — có độ trễ ngắn [keepFor] vì ứng dụng nhận
  /// (Zalo, Gmail…) đọc file qua content URI *sau* khi người dùng chọn đích. Phần còn sót sẽ bị
  /// dọn khi mở ứng dụng lần sau.
  /// Trả về false nếu người dùng đóng bảng chia sẻ mà không chọn ứng dụng nào.
  static Future<bool> shareBytes(Uint8List bytes, String fileName, {String? text, Duration keepFor = const Duration(seconds: 45)}) =>
      appLock.guard(() async {
        final dir = Directory(p.join((await _shareDir()).path, '${DateTime.now().microsecondsSinceEpoch}'));
        await dir.create(recursive: true);
        final f = File(p.join(dir.path, fileName));
        await f.writeAsBytes(bytes, flush: true);
        ShareResult? r;
        try {
          r = await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: text));
        } finally {
          final dismissed = r == null || r.status == ShareResultStatus.dismissed;
          Future<void> wipe() async {
            try {
              if (await dir.exists()) await dir.delete(recursive: true);
            } catch (_) {}
          }

          if (dismissed) {
            await wipe();
          } else {
            Future.delayed(keepFor, wipe);
          }
        }
        return r.status != ShareResultStatus.dismissed;
      });
}
