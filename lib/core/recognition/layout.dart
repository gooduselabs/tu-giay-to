import 'text.dart';

/// Một dòng chữ OCR kèm khung toạ độ (pixel ảnh). Ảnh không có toạ độ thì dùng khung giả theo thứ tự dòng.
class OcrLine {
  final String text;
  final double l, t, r, b;
  final String folded;
  final String sq;
  OcrLine(this.text, this.l, this.t, this.r, this.b)
      : folded = fold(text),
        sq = squash(fold(text));
  double get h => (b - t).abs() < 1 ? 1 : (b - t);
  double get cy => (t + b) / 2;
}

/// Một trang/ảnh đã nhận dạng: các dòng chữ + nội dung mã QR/mã vạch.
class OcrPage {
  final List<OcrLine> lines;
  final List<String> codes;
  OcrPage(this.lines, {this.codes = const []});

  factory OcrPage.fromText(String raw, {List<String> codes = const []}) {
    final ls = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    return OcrPage([for (var i = 0; i < ls.length; i++) OcrLine(ls[i], 0, i * 20.0, 1000, i * 20.0 + 16)], codes: codes);
  }

  String get text => lines.map((l) => l.text).join('\n');
}

/// Vị trí của nhãn trong dòng: số token đã khớp (để cắt phần giá trị phía sau).
class LabelHit {
  final OcrLine line;
  final int index;
  final String remainder; // phần chữ gốc sau nhãn trên cùng dòng
  final int start; // vị trí ký tự bắt đầu nhãn
  LabelHit(this.line, this.index, this.remainder, this.start);
}

final _tokRe = RegExp(r'[^\s/:;,.()\[\]]+');

/// Tìm nhãn [label] (đã fold, ví dụ 'NGAY SINH') trong dòng, khớp mờ theo từng từ.
/// Nhãn 1–2 ký tự (SO, NO) phải đứng đầu dòng hoặc ngay sau dấu '/' để tránh bắt nhầm.
LabelHit? matchLabel(OcrLine line, int index, String label) {
  final want = label.split(' ');
  final toks = _tokRe.allMatches(line.text).toList();
  final folded = [for (final m in toks) squash(fold(m[0]!)).replaceAll(' ', '')];
  for (var i = 0; i + want.length <= toks.length; i++) {
    var ok = true;
    for (var j = 0; j < want.length; j++) {
      final w = want[j], f = folded[i + j];
      final tol = w.length >= 6 ? 1 : 0;
      if (f != w && (tol == 0 || levenshtein(f, w, max: tol) > tol)) {
        ok = false;
        break;
      }
    }
    if (!ok) continue;
    if (label.length <= 2 && i > 0) {
      final before = line.text.substring(0, toks[i].start).trimRight();
      if (!before.endsWith('/') && before.isNotEmpty) continue;
    }
    final end = toks[i + want.length - 1].end;
    return LabelHit(line, index, line.text.substring(end), toks[i].start);
  }
  return null;
}

String _stripLead(String s) => s.replaceFirst(RegExp(r'^[\s:;./\-–|]+'), '').trim();

/// Bỏ các nhãn (thường là nhãn tiếng Anh song ngữ) còn dính ở đầu giá trị.
String stripLabels(String s, List<String> labels) {
  var v = _stripLead(s);
  for (var k = 0; k < 4; k++) {
    LabelHit? best;
    for (final lb in labels) {
      final h = matchLabel(OcrLine(v, 0, 0, 0, 0), 0, lb);
      if (h != null && h.start <= 1 && (best == null || h.remainder.length < best.remainder.length)) best = h;
    }
    if (best == null) break;
    v = _stripLead(best.remainder);
  }
  return v;
}

/// Giá trị cho một trường: tìm nhãn, rồi lấy giá trị theo thứ tự ưu tiên
/// (1) cùng dòng sau nhãn → (2) dòng bên phải cùng hàng → (3) 1–2 dòng ngay bên dưới.
/// [accept] trả về giá trị đã chuẩn hoá hoặc null nếu ứng viên không hợp lệ.
({T value, double conf})? valueNear<T>(OcrPage page, List<String> labels, T? Function(String) accept,
    {List<String> exclude = const [], List<String> stopLabels = const [], int below = 2}) {
  for (var i = 0; i < page.lines.length; i++) {
    final line = page.lines[i];
    if (exclude.any((x) => line.sq.contains(x))) continue;
    LabelHit? hit;
    for (final lb in labels) {
      hit = matchLabel(line, i, lb);
      if (hit != null) break;
    }
    if (hit == null) continue;
    final same = stripLabels(hit.remainder, [...labels, ...stopLabels]);
    if (same.isNotEmpty) {
      final v = accept(same);
      if (v != null) return (value: v, conf: .82);
    }
    // cùng hàng, bên phải
    final right = page.lines
        .where((o) => o != line && (o.cy - line.cy).abs() < line.h * .6 && o.l >= line.r - line.h)
        .toList()
      ..sort((a, b) => a.l.compareTo(b.l));
    for (final o in right) {
      final v = accept(stripLabels(o.text, [...labels, ...stopLabels]));
      if (v != null) return (value: v, conf: .78);
    }
    // bên dưới: dòng có tâm thấp hơn, gần nhất theo chiều dọc, chồng lấn ngang
    final under = page.lines
        .where((o) =>
            o != line &&
            o.cy > line.cy + line.h * .4 &&
            o.t - line.b < line.h * 2.6 &&
            o.r > line.l - line.h * 2 &&
            o.l < line.r + line.h * 6)
        .toList()
      ..sort((a, b) => a.t.compareTo(b.t));
    var n = 0;
    for (final o in under) {
      if (n++ >= below) break;
      // dừng nếu gặp nhãn khác
      final isLabel = stopLabels.any((s) => matchLabel(o, 0, s) != null) || labels.any((s) => matchLabel(o, 0, s) != null);
      final cand = isLabel ? stripLabels(o.text, [...labels, ...stopLabels]) : o.text;
      final v = accept(cand);
      if (v != null) return (value: v, conf: isLabel ? .6 : .72);
      if (isLabel) break;
    }
  }
  return null;
}

/// Có nhãn/cụm từ nào trong trang (khớp mờ).
bool pageHas(OcrPage page, String phrase) => page.lines.any((l) => fuzzyContains(l.sq, phrase));
