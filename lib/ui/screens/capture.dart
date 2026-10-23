import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../services/media.dart';
import '../theme.dart';
import '../widgets/glyphs.dart';

/// Một bước chụp: tiêu đề, gợi ý, tỉ lệ khung (rộng/cao).
typedef CaptureStep = ({String title, String hint, double aspect, bool optional});

const _card = 85.6 / 53.98; // thẻ ID-1 (CCCD, GPLX, BHYT, cà-vẹt mới)
const _passport = 125 / 88;
const _a4 = 210 / 297;

List<CaptureStep> captureSteps(DocType t) => switch (t) {
      DocType.cccd => [
          (title: tr('Mặt trước'), hint: tr('Mặt có ảnh chân dung và mã QR. Giữ mã QR rõ nét, không bị loá.'), aspect: _card, optional: false),
          (title: tr('Mặt sau'), hint: tr('Mặt có 3 dòng ký tự <<< ở dưới cùng (vùng MRZ). Chụp đủ cả 3 dòng.'), aspect: _card, optional: true),
        ],
      DocType.driverLicense => [
          (title: tr('Mặt trước'), hint: tr('Mặt có ảnh. Thẻ PET mới có mã QR, giữ mã QR rõ nét.'), aspect: _card, optional: false),
          (title: tr('Mặt sau'), hint: tr('Mặt sau có bảng hạng xe và thời hạn.'), aspect: _card, optional: true),
        ],
      DocType.passport => [
          (title: tr('Trang thông tin'), hint: tr('Trang có ảnh, chụp đủ 2 dòng ký tự <<< ở cuối trang.'), aspect: _passport, optional: false),
        ],
      DocType.bhyt || DocType.vehicleReg => [
          (title: tr('Mặt trước'), hint: tr('Đặt thẻ vừa khung, đủ sáng, không bị loá.'), aspect: _card, optional: false),
          (title: tr('Mặt sau'), hint: tr('Mặt sau nếu có thông tin thêm.'), aspect: _card, optional: true),
        ],
      _ => [
          (title: tr('Toàn trang'), hint: tr('Chụp thẳng, đủ cả trang. Có mã QR thì để mã QR rõ nét.'), aspect: _a4, optional: false),
        ],
    };

/// Màn chụp có hướng dẫn: khung hình thẻ/trang, từng mặt một.
/// Không có camera (hoặc lỗi) thì chuyển sang ứng dụng camera của hệ thống.
class CaptureScreen extends StatefulWidget {
  final DocType type;
  final Widget? debugPreview; // cho golden test
  const CaptureScreen({super.key, required this.type, this.debugPreview});

  static Future<List<Picked>> open(BuildContext context, DocType type) async {
    final r = await Navigator.of(context).push<List<Picked>>(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => CaptureScreen(type: type)));
    return r ?? const [];
  }

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _cam;
  late final steps = captureSteps(widget.type);
  final _shots = <Picked>[];
  bool _busy = false, _flash = false, _failed = false;
  int get _step => _shots.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.debugPreview == null) _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await c.initialize();
      try {
        await c.setFocusMode(FocusMode.auto);
      } catch (_) {}
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _cam = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      await _fallback();
    }
  }

  /// Dùng camera hệ thống (image_picker) khi camera trong ứng dụng không chạy được.
  Future<void> _fallback() async {
    final x = await Media.camera();
    if (!mounted) return;
    Navigator.of(context).pop(x == null ? <Picked>[] : [x]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final c = _cam;
    if (c == null) return;
    if (s == AppLifecycleState.inactive || s == AppLifecycleState.paused) {
      _cam = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (s == AppLifecycleState.resumed && _cam == null && !_failed) {
      _init();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = _cam;
    if (c == null || _busy || !c.value.isInitialized) return;
    setState(() => _busy = true);
    try {
      final x = await c.takePicture();
      final bytes = await x.readAsBytes();
      _shots.add((bytes: bytes, pdf: false, name: 'scan-${_shots.length + 1}.jpg'));
      if (_shots.length >= steps.length) {
        if (mounted) Navigator.of(context).pop(List<Picked>.of(_shots));
        return;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = steps[_step.clamp(0, steps.length - 1)];
    final canFinish = _shots.isNotEmpty && (_step >= steps.length || steps[_step].optional);
    final c = _cam;
    final preview = widget.debugPreview ??
        (c != null && c.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: c.value.previewSize!.height, height: c.value.previewSize!.width, child: CameraPreview(c)))
            : const SizedBox());
    return Scaffold(
      backgroundColor: Palette.night,
      body: Stack(fit: StackFit.expand, children: [
        preview,
        LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth * (step.aspect >= 1 ? .88 : .78);
          var h = w / step.aspect;
          if (h > box.maxHeight * .62) h = box.maxHeight * .62;
          final rect = Rect.fromCenter(center: Offset(box.maxWidth / 2, box.maxHeight * .46), width: h * step.aspect, height: h);
          return CustomPaint(painter: _FramePainter(rect, Palette.paper, Palette.cinnabar), size: box.biggest);
        }),
        SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(children: [
                IconButton(onPressed: () => Navigator.pop(context, List<Picked>.of(_shots)), icon: Gl(Ic.close, color: Palette.paper)),
                const Spacer(),
                IconButton(
                  onPressed: c == null
                      ? null
                      : () async {
                          _flash = !_flash;
                          try {
                            await c.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
                          } catch (_) {}
                          setState(() {});
                        },
                  icon: Gl(Ic.brightness, color: _flash ? Palette.ochre : Palette.paper),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.type.label.toUpperCase()} · ${_step + 1 > steps.length ? steps.length : _step + 1}/${steps.length}',
                    style: TextStyle(fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: Palette.paper.withValues(alpha: .7))),
                const SizedBox(height: 6),
                Text(step.title, style: const TextStyle(fontFamily: serif, fontSize: 30, height: 1.05, color: Palette.paper)),
                const SizedBox(height: 6),
                Text(step.hint,
                    style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 15, height: 1.35, color: Palette.paper.withValues(alpha: .85))),
              ]),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                SizedBox(
                  width: 96,
                  child: Row(children: [
                    for (var i = 0; i < steps.length; i++)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 26,
                        height: 18,
                        decoration: BoxDecoration(
                          border: Border.all(color: Palette.paper.withValues(alpha: i < _shots.length ? 1 : .4), width: 1.2),
                          color: i < _shots.length ? Palette.paper.withValues(alpha: .9) : null,
                        ),
                        child: i < _shots.length ? Gl(Ic.check, size: 12, color: Palette.night) : null,
                      ),
                  ]),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _shoot,
                  child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Palette.paper, width: 3)),
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _busy ? Palette.cinnabar : Palette.paper)),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 96,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: canFinish ? () => Navigator.pop(context, List<Picked>.of(_shots)) : null,
                      child: Text(_shots.isEmpty ? '' : tr('Xong'),
                          style: const TextStyle(color: Palette.paper, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _FramePainter extends CustomPainter {
  final Rect r;
  final Color paper, accent;
  _FramePainter(this.r, this.paper, this.accent);
  @override
  void paint(Canvas canvas, Size s) {
    final scrim = Path()
      ..addRect(Offset.zero & s)
      ..addRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = const Color(0xB0141210));
    final edge = Paint()
      ..color = paper.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)), edge);
    final corner = Paint()
      ..color = paper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    const k = 26.0;
    for (final (o, dx, dy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawLine(o, o.translate(k * dx, 0), corner);
      canvas.drawLine(o, o.translate(0, k * dy), corner);
    }
    // vạch gợi ý vùng MRZ/QR
    final tick = Paint()
      ..color = accent.withValues(alpha: .8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(r.left + 14, r.bottom - r.height * .26), Offset(r.left + 38, r.bottom - r.height * .26), tick);
  }

  @override
  bool shouldRepaint(_FramePainter o) => o.r != r;
}
