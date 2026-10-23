/// Tiện ích chuỗi cho nhận dạng: bỏ dấu, so khớp mờ, sửa lỗi OCR hay gặp.
library;

const _from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Bỏ dấu tiếng Việt (cả dạng dựng sẵn lẫn dấu tổ hợp NFD) và viết hoa.
String fold(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    if (r >= 0x300 && r <= 0x36f) continue; // dấu tổ hợp
    final c = String.fromCharCode(r);
    final i = _from.indexOf(c);
    b.write(i >= 0 ? _to[i] : c);
  }
  return b.toString().toUpperCase();
}

/// Chỉ giữ chữ + số, gộp khoảng trắng — để so khớp từ khoá chịu được nhiễu dấu câu.
String squash(String folded) => folded.replaceAll(RegExp(r'[^A-Z0-9]+'), ' ').trim();

int levenshtein(String a, String b, {int max = 99}) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var best = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      if (cur[j] < best) best = cur[j];
    }
    if (best > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}

/// Số lỗi cho phép khi so khớp mờ một từ khoá theo độ dài.
int tolerance(int len) => len >= 12 ? 2 : (len >= 5 ? 1 : 0);

/// Từ khoá [kw] (đã fold+squash) có xuất hiện mờ trong [hay] (đã fold+squash) không.
bool fuzzyContains(String hay, String kw) {
  if (kw.isEmpty) return false;
  if (hay.contains(kw)) return true;
  final tol = tolerance(kw.length);
  if (tol == 0) return false;
  final h = hay.replaceAll(' ', ''), k = kw.replaceAll(' ', '');
  if (h.contains(k)) return true;
  for (var i = 0; i + k.length - tol <= h.length; i++) {
    for (var len = k.length - tol; len <= k.length + tol; len++) {
      if (i + len > h.length || len <= 0) continue;
      if (levenshtein(h.substring(i, i + len), k, max: tol) <= tol) return true;
    }
  }
  return false;
}

const _toDigit = {'O': '0', 'Q': '0', 'D': '0', 'U': '0', 'o': '0', 'I': '1', 'L': '1', 'l': '1', 'i': '1', '|': '1', '!': '1',
  'T': '1', 'Z': '2', 'z': '2', 'S': '5', 's': '5', 'B': '8', 'G': '6', 'b': '6', 'g': '9', 'q': '9', 'A': '4'};
const _toAlpha = {'0': 'O', '1': 'I', '2': 'Z', '5': 'S', '8': 'B', '6': 'G', '4': 'A', '7': 'T'};

/// Ép các ký tự dễ nhầm về chữ số (cho trường chỉ có số).
String asDigits(String s) => s.split('').map((c) => _toDigit[c] ?? c).join();

/// Ép các chữ số dễ nhầm về chữ cái (cho trường chỉ có chữ).
String asAlpha(String s) => s.split('').map((c) => _toAlpha[c] ?? c).join();

/// Tìm dãy đúng [n] chữ số, chịu được ký tự nhầm (O→0, I→1…) và khoảng trắng/dấu chấm chen giữa.
String? digitRun(String s, int n, {bool Function(String)? accept}) {
  final re = RegExp('(?<![0-9A-Za-z])([0-9OQDIlL|SBZ][0-9OQDIlL|SBZ .]{${n - 2},${n * 2}}[0-9OQDIlL|SBZ])(?![0-9A-Za-z])');
  for (final m in re.allMatches(s)) {
    final raw = m[1]!;
    final digits = asDigits(raw.replaceAll(RegExp(r'[ .]'), ''));
    // phải có đa số là chữ số thật, tránh bắt nhầm chữ
    final real = raw.split('').where((c) => RegExp(r'\d').hasMatch(c)).length;
    if (digits.length == n && RegExp(r'^\d+$').hasMatch(digits) && real >= (n * .7).ceil() && (accept?.call(digits) ?? true)) {
      return digits;
    }
  }
  // ngắt cứng: dãy số dài hơn có thể là 2 số dính nhau — không nhận
  return null;
}

String titleCase(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Có giống họ tên người không (≥2 từ, không có số, toàn chữ).
bool looksLikeName(String s) {
  final t = s.trim();
  if (t.length < 4 || t.length > 50) return false;
  if (RegExp(r'[0-9:/<>@#]').hasMatch(t)) return false;
  final words = t.split(RegExp(r'\s+'));
  if (words.length < 2 || words.length > 7) return false;
  return words.every((w) => RegExp(r'^\p{L}+$', unicode: true).hasMatch(w) || w == '-');
}
