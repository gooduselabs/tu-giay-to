import 'package:flutter/material.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../core/ocr_parser.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../../services/media.dart';
import '../app.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/attachment_thumb.dart';
import '../widgets/glyphs.dart';
import '../widgets/common.dart';
import '../widgets/dossier.dart';
import 'capture.dart';
import 'profiles.dart';
import 'settings.dart';

class DocEditScreen extends StatefulWidget {
  final Document? existing;
  final List<Picked> initialFiles;
  final String? profileId;
  final DocType? initialType;
  final OcrGuess? initialGuess; // cho demo/golden
  const DocEditScreen(
      {super.key, this.existing, this.initialFiles = const [], this.profileId, this.initialType, this.initialGuess});
  @override
  State<DocEditScreen> createState() => _DocEditScreenState();
}

class _DocEditScreenState extends State<DocEditScreen> {
  late DocType _type;
  String? _profileId;
  final _title = TextEditingController();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _issue, _expiry;
  late List<int> _reminders;
  late List<Attachment> _existing;
  final List<Picked> _pending = [];
  final List<Attachment> _removed = [];
  bool _ocrBusy = false;
  OcrGuess? _guess;
  final _review = <String>{}; // ô do máy điền với độ tin cậy thấp, chưa được người dùng sửa
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? widget.initialType ?? DocType.cccd;
    _profileId = e?.profileId ?? widget.profileId;
    _title.text = e?.title ?? '';
    _number.text = e?.number ?? '';
    _holder.text = e?.holderName ?? '';
    _notes.text = e?.notes ?? '';
    _issue = e?.issueDate;
    _expiry = e?.expiryDate;
    _reminders = List.of(e?.reminderDays ?? _type.defaultReminderDays);
    _existing = List.of(e?.attachments ?? []);
    _pending.addAll(widget.initialFiles);
    if (widget.initialGuess != null) _applyGuess(widget.initialGuess!);
    if (widget.initialFiles.isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _runOcr());
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final t = Theme.of(context);
    final profiles = store.profileList;
    _profileId ??= profiles.isNotEmpty ? profiles.first.id : null;
    final preview = Document(
      id: 'preview',
      profileId: _profileId ?? '',
      type: _type,
      title: _title.text,
      number: _number.text,
      holderName: _holder.text,
      expiryDate: _expiry,
      reminderDays: _reminders,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? tr('Thêm giấy tờ') : tr('Sửa giấy tờ')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
              child: Text(tr('Lưu')),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        DossierCard(doc: preview, ownerName: store.profiles[_profileId]?.name ?? '', compact: true, reveal: true),
        SectionLabel(tr('Ảnh & PDF'), index: 'i.', padding: const EdgeInsets.fromLTRB(0, 26, 0, 10)),
        _attachmentsRow(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _srcBtn(Ic.camera, tr('Chụp'), () => _add(() => CaptureScreen.open(context, _type)))),
          const SizedBox(width: 8),
          Expanded(child: _srcBtn(Ic.image, tr('Thư viện'), () => _add(Media.gallery))),
          const SizedBox(width: 8),
          Expanded(child: _srcBtn(Ic.pdf, 'PDF', () => _add(Media.pdfs))),
        ]),
        const SizedBox(height: 12),
        _ocrCard(t),
        SectionLabel(tr('Loại giấy tờ'), index: 'ii.', padding: const EdgeInsets.fromLTRB(0, 26, 0, 10)),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ty in DocType.values)
            ChoiceChip(
              avatar: Gl(ty.icon, size: 15, color: ty == _type ? context.ar.paper : context.ar.ink),
              label: Text(ty.label),
              selected: ty == _type,
              labelStyle: TextStyle(color: ty == _type ? context.ar.paper : t.colorScheme.onSurface),
              onSelected: (_) => setState(() {
                _type = ty;
                _reminders = List.of(ty.defaultReminderDays);
              }),
            ),
        ]),
        SectionLabel(tr('Thuộc hồ sơ'), index: 'iii.', padding: const EdgeInsets.fromLTRB(0, 26, 0, 10)),
        _profilePicker(profiles),
        SectionLabel(tr('Thông tin'), index: 'iv.', padding: const EdgeInsets.fromLTRB(0, 26, 0, 10)),
        TextField(controller: _title, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Tên gợi nhớ'), hintText: _type.label)),
        const SizedBox(height: 12),
        TextField(controller: _number, onChanged: (_) => setState(() => _review.remove('number')),
            decoration: _dec(InputDecoration(labelText: tr('Số giấy tờ / biển số'), prefixIcon: Gl(Ic.hash)), 'number')),
        const SizedBox(height: 12),
        TextField(controller: _holder, onChanged: (_) => setState(() => _review.remove('name')), textCapitalization: TextCapitalization.words,
            decoration: _dec(InputDecoration(labelText: tr('Họ tên trên giấy tờ'), prefixIcon: Gl(Ic.person)), 'name')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateField(tr('Ngày cấp'), _issue, (d) => setState(() {
                _issue = d;
                _review.remove('issue');
              }), key: 'issue')),
          const SizedBox(width: 10),
          Expanded(child: _dateField(tr('Ngày hết hạn'), _expiry, (d) => setState(() {
                _expiry = d;
                _review.remove('expiry');
              }), key: 'expiry', empty: _guess?.noExpiry == true ? tr('Không thời hạn') : '—')),
        ]),
        if (_type == DocType.cccd) _cccdHelper(store),
        SectionLabel(tr('Nhắc trước hạn'), index: 'v.', padding: const EdgeInsets.fromLTRB(0, 26, 0, 10)),
        _reminderChips(),
        const SizedBox(height: 16),
        TextField(controller: _notes, maxLines: 3,
            decoration: InputDecoration(labelText: tr('Ghi chú'), alignLabelWithHint: true)),
        const SizedBox(height: 18),
        Text(tr('Dữ liệu và tệp được mã hoá, chỉ lưu trên máy này.'),
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .5))),
      ]),
    );
  }

  Widget _srcBtn(Ic i, String label, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Gl(i, size: 18, color: context.ar.ink),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
      );

  Widget _attachmentsRow() {
    final t = Theme.of(context);
    if (_existing.isEmpty && _pending.isEmpty) {
      return Container(
        height: 96,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: context.ar.manilaEdge),
          color: context.ar.manila.withValues(alpha: .35),
        ),
        child: Text(tr('Chụp mặt trước & mặt sau để tự nhận dạng'),
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .6))),
      );
    }
    return SizedBox(
      height: 120,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final a in _existing)
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AttachmentThumb(attachment: a, onRemove: () => setState(() {
                _existing.remove(a);
                _removed.add(a);
              })),
            ),
          ),
        for (var i = 0; i < _pending.length; i++)
          SizedBox(
            width: 96,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Column(children: [
                Expanded(
                  child: Stack(fit: StackFit.expand, children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: _pending[i].pdf
                          ? Container(color: t.colorScheme.surfaceContainerHighest,
                              child: Gl(Ic.pdf, color: Palette.red, size: 34))
                          : Image.memory(_pending[i].bytes, fit: BoxFit.cover, cacheWidth: 300),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _pending.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: context.ar.ink),
                          child: Gl(Ic.close, size: 14, color: context.ar.paper),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(_labelFor(_existing.length + i, _pending[i]),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.labelMedium),
              ]),
            ),
          ),
      ]),
    );
  }

  String _labelFor(int index, Picked p) {
    if (p.pdf) return p.name.isEmpty ? 'PDF' : p.name;
    final imgsBefore = _existing.where((a) => a.kind == AttachmentKind.image).length +
        _pending.take(_pending.indexOf(p)).where((x) => !x.pdf).length;
    return switch (imgsBefore) { 0 => tr('Mặt trước'), 1 => tr('Mặt sau'), _ => tr('Ảnh {n}', {'n': imgsBefore + 1}) };
  }

  Widget _ocrCard(ThemeData t) {
    final g = _guess;
    final hasFiles = _pending.isNotEmpty || _existing.isNotEmpty;
    final canOcr = AppScope.of(context).ocr != null;
    return Container(
      decoration: BoxDecoration(color: context.ar.card, border: Border.all(color: context.ar.ruleStrong, width: .8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Gl(Ic.spark, color: Palette.cinnabar, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(tr('Nhận dạng tự động (trên máy)'), style: t.textTheme.titleSmall)),
            if (_ocrBusy)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              TextButton(onPressed: hasFiles && canOcr ? _runOcr : null, child: Text(tr('Quét lại'))),
          ]),
          const SizedBox(height: 4),
          if (g == null)
            Text(tr('Thêm ảnh hoặc PDF — ứng dụng sẽ đọc loại giấy tờ, số, họ tên và ngày hết hạn. Bạn kiểm tra lại trước khi lưu.'),
                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .6)))
          else if (g.isEmpty)
            Text(tr('Không đọc được thông tin. Hãy chụp rõ, đủ sáng, hoặc nhập tay.'),
                style: t.textTheme.bodySmall?.copyWith(color: Palette.ochre))
          else
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (g.type != null) _found('type', tr('Loại'), g.type!.label),
              if (g.number != null) _found('number', tr('Số'), g.number!),
              if (g.name != null) _found('name', tr('Họ tên'), g.name!),
              if (g.birthDate != null) _found('birth', tr('Ngày sinh'), dmy.format(g.birthDate!)),
              if (g.sex != null) _found('sex', tr('Giới tính'), g.sex!),
              if (g.vehicleClass != null) _found('class', tr('Hạng'), g.vehicleClass!),
              if (g.plate != null && g.plate != g.number) _found('plate', tr('Biển số'), g.plate!),
              if (g.issueDate != null) _found('issue', tr('Ngày cấp'), dmy.format(g.issueDate!)),
              if (g.expiryDate != null) _found('expiry', tr('Hết hạn'), dmy.format(g.expiryDate!)),
              if (g.noExpiry) _found('expiry', tr('Hết hạn'), tr('Không thời hạn')),
              if (g.address != null) _found('address', tr('Nơi cư trú'), g.address!),
              const SizedBox(height: 8),
              Text(
                  g.conf.values.any((c) => c < OcrGuess.review)
                      ? tr('Đã điền sẵn. Ô viền vàng có độ tin cậy thấp, hãy kiểm tra.')
                      : tr('Đã điền sẵn, vui lòng kiểm tra lại.'),
                  style: t.textTheme.bodySmall?.copyWith(color: context.ar.inkSoft, fontStyle: FontStyle.italic)),
            ]),
        ]),
      ),
    );
  }

  /// Một dòng kết quả: nhãn · giá trị · nguồn (QR/MRZ/OCR) · thước độ tin cậy 3 vạch.
  Widget _found(String key, String k, String v) {
    final a = context.ar;
    final c = _guess?.conf[key] ?? 0;
    final src = _guess?.source[key] ?? (key == 'type' ? tr('từ khoá') : '');
    final lvl = c >= .9 ? 3 : (c >= OcrGuess.review ? 2 : 1);
    final col = lvl == 3 ? a.olive : (lvl == 2 ? a.ink : a.ochre);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule, width: .6))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 78, child: Text(k.toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: a.inkSoft))),
        Expanded(
            child: Text(v,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: a.ink, fontWeight: FontWeight.w500))),
        if (src.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(src, style: TextStyle(fontSize: 9.5, letterSpacing: 1, color: a.inkFaint, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(width: 8),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 4,
              height: 6.0 + i * 3,
              margin: const EdgeInsets.only(left: 2),
              color: i < lvl ? col : a.rule,
            ),
        ]),
      ]),
    );
  }

  Widget _profilePicker(List<Profile> profiles) {
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final p in profiles)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Gl(p.kind.icon, size: 15, color: p.id == _profileId ? context.ar.paper : context.ar.ink),
              label: Text(p.name),
              selected: p.id == _profileId,
              labelStyle: TextStyle(color: p.id == _profileId ? context.ar.paper : Theme.of(context).colorScheme.onSurface),
              onSelected: (_) => setState(() => _profileId = p.id),
            ),
          ),
        ActionChip(
          avatar: Gl(Ic.add, size: 16),
          label: Text(tr('Hồ sơ mới')),
          onPressed: () async {
            final p = await showProfileEditor(context,
                kind: _type.belongsToVehicle ? ProfileKind.car : (_type == DocType.warranty ? ProfileKind.device : ProfileKind.person));
            if (p != null) setState(() => _profileId = p.id);
          },
        ),
      ]),
    );
  }

  /// Tô viền vàng đất + nhắc kiểm tra cho ô máy điền nhưng độ tin cậy thấp.
  InputDecoration _dec(InputDecoration d, String key) {
    if (!_review.contains(key)) return d;
    final c = context.ar.ochre;
    return d.copyWith(
      helperText: tr('Độ tin cậy thấp — hãy kiểm tra lại'),
      helperStyle: TextStyle(color: c, fontWeight: FontWeight.w600),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c, width: 2)),
      labelStyle: TextStyle(color: c),
    );
  }

  Widget _dateField(String label, DateTime? v, ValueChanged<DateTime?> onChanged, {String? key, String empty = '—'}) {
    return InkWell(
      borderRadius: BorderRadius.circular(2),
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: v ?? now,
          firstDate: DateTime(1950),
          lastDate: DateTime(now.year + 30),
          locale: Locale(L10n.locale.value),
        );
        if (d != null) onChanged(d);
      },
      child: InputDecorator(
        decoration: _dec(
            InputDecoration(
              labelText: label,
              suffixIcon: v == null
                  ? Gl(Ic.calendar)
                  : IconButton(icon: Gl(Ic.close, size: 18), onPressed: () => onChanged(null)),
            ),
            key ?? ''),
        child: Text(v == null ? empty : dmy.format(v)),
      ),
    );
  }

  Widget _cccdHelper(AppStore store) {
    final p = store.profiles[_profileId];
    final t = Theme.of(context);
    String text;
    DateTime? suggestion;
    if (p?.birthDate == null) {
      text = tr('Thêm ngày sinh cho hồ sơ để tính mốc đổi thẻ (14, 25, 40, 60 tuổi).');
    } else if (_issue == null) {
      final m = nextCccdMilestone(p!.birthDate!);
      text = m == null
          ? tr('Đã qua mốc 60 tuổi: thẻ thường không thời hạn.')
          : tr('Mốc đổi thẻ tiếp theo: {age} tuổi ({date}). Nhập ngày cấp để tính chính xác.', {'age': m.age, 'date': dmy.format(m.date)});
    } else {
      suggestion = cccdExpiryFor(p!.birthDate!, _issue!);
      text = suggestion == null
          ? tr('Theo mốc tuổi, thẻ này không thời hạn.')
          : tr('Theo mốc tuổi, thẻ có giá trị đến {d}.', {'d': dmy.format(suggestion)});
    }
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Palette.cinnabar.withValues(alpha: .1), borderRadius: BorderRadius.circular(2)),
        child: Row(children: [
          Gl(Ic.calendar, size: 18, color: Palette.cinnabar),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: t.textTheme.bodySmall)),
          if (suggestion != null && suggestion != _expiry)
            TextButton(onPressed: () => setState(() => _expiry = suggestion), child: Text(tr('Dùng'))),
        ]),
      ),
    );
  }

  Widget _reminderChips() {
    final presets = {..._type.defaultReminderDays, 1, 7, 14, 30, 60, 90, 180, ..._reminders}.toList()
      ..sort((a, b) => b.compareTo(a));
    String label(int d) => d >= 30 && d % 30 == 0 ? tr('{n} tháng', {'n': d ~/ 30}) : tr('{n} ngày', {'n': d});
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final d in presets)
        FilterChip(
          label: Text(label(d)),
          selected: _reminders.contains(d),
          labelStyle: TextStyle(color: _reminders.contains(d) ? context.ar.paper : Theme.of(context).colorScheme.onSurface),
          onSelected: (s) => setState(() => s ? _reminders.add(d) : _reminders.remove(d)),
        ),
      ActionChip(
        avatar: Gl(Ic.add, size: 16),
        label: Text(tr('Tuỳ chỉnh')),
        onPressed: () async {
          final c = TextEditingController();
          final v = await showDialog<int>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr('Nhắc trước bao nhiêu ngày?')),
              content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true,
                  decoration: InputDecoration(suffixText: tr('ngày'))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Huỷ'))),
                FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: Text(tr('Thêm'))),
              ],
            ),
          );
          if (v != null && v >= 0 && v <= 3650 && !_reminders.contains(v)) setState(() => _reminders.add(v));
        },
      ),
    ]);
  }

  Future<void> _add(Future<List<Picked>> Function() pick) async {
    try {
      final xs = await LockGate.guard(pick);
      if (xs.isEmpty) return;
      setState(() => _pending.addAll(xs));
      await _runOcr();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Không mở được tệp: {e}', {'e': e}))));
    }
  }

  Future<void> _runOcr() async {
    final ocr = AppScope.of(context).ocr;
    if (ocr == null) return;
    setState(() => _ocrBusy = true);
    try {
      final store = AppScope.store(context);
      final files = [
        for (final a in _existing) (bytes: await store.readAttachment(a), pdf: a.kind == AttachmentKind.pdf),
        for (final p in _pending) (bytes: p.bytes, pdf: p.pdf),
      ];
      final g = await ocr(files);
      if (!mounted) return;
      setState(() => _applyGuess(g));
    } catch (_) {
      if (mounted) setState(() => _guess = OcrGuess());
    } finally {
      if (mounted) setState(() => _ocrBusy = false);
    }
  }

  /// Chỉ điền vào ô còn trống (không ghi đè dữ liệu người dùng đã nhập).
  void _applyGuess(OcrGuess g) {
    _guess = g;
    if (g.type != null && widget.existing == null && _number.text.isEmpty) {
      _type = g.type!;
      _reminders = List.of(_type.defaultReminderDays);
    }
    void mark(String key) {
      if (g.low(key)) _review.add(key);
    }

    if (_number.text.isEmpty && g.number != null) {
      _number.text = g.number!;
      mark('number');
    }
    if (_holder.text.isEmpty && g.name != null) {
      _holder.text = g.name!;
      mark('name');
    }
    if (_issue == null && g.issueDate != null) {
      _issue = g.issueDate;
      mark('issue');
    }
    if (_expiry == null && g.expiryDate != null) {
      _expiry = g.expiryDate;
      mark('expiry');
    }
    // Thông tin thêm (ngày sinh, giới tính, nơi cư trú, hạng xe, biển số, QR) vào ghi chú nếu còn trống.
    if (_notes.text.isEmpty) {
      final extra = [
        if (g.birthDate != null) '${tr('Ngày sinh')}: ${dmy.format(g.birthDate!)}',
        if (g.sex != null) '${tr('Giới tính')}: ${g.sex}',
        if (g.vehicleClass != null) '${tr('Hạng')}: ${g.vehicleClass}',
        if (g.plate != null && g.plate != g.number) '${tr('Biển số')}: ${g.plate}',
        if (g.oldId != null) '${tr('Số CMND cũ')}: ${g.oldId}',
        if (g.address != null) '${tr('Nơi cư trú')}: ${g.address}',
        if (g.url != null) 'QR: ${g.url}',
      ];
      _notes.text = extra.join('\n');
    }
    if (_type == DocType.cccd && _expiry == null && g.birthDate != null && g.issueDate != null) {
      _expiry = cccdExpiryFor(g.birthDate!, g.issueDate!);
    }
  }

  Future<void> _save() async {
    final store = AppScope.store(context);
    setState(() => _saving = true);
    try {
      var pid = _profileId;
      if (pid == null) {
        final me = Profile(id: store.newId(), name: _holder.text.isEmpty ? tr('Tôi') : _holder.text, birthDate: _guess?.birthDate);
        await store.saveProfile(me);
        pid = me.id;
      }
      // CCCD: điền ngày sinh cho hồ sơ người nếu còn trống (để tính mốc đổi thẻ).
      final owner = store.profiles[pid];
      if (_type == DocType.cccd && owner != null && owner.isPerson && owner.birthDate == null && _guess?.birthDate != null) {
        owner.birthDate = _guess!.birthDate;
        await store.saveProfile(owner);
      }
      final atts = List.of(_existing);
      for (var i = 0; i < _pending.length; i++) {
        final p = _pending[i];
        atts.add(await store.addAttachment(p.bytes, p.pdf ? AttachmentKind.pdf : AttachmentKind.image,
            _labelFor(_existing.length + i, p)));
      }
      final d = widget.existing ?? Document(id: store.newId(), profileId: pid, type: _type);
      d
        ..profileId = pid
        ..type = _type
        ..title = _title.text.trim()
        ..number = _number.text.trim()
        ..holderName = _holder.text.trim()
        ..issueDate = _issue
        ..expiryDate = _expiry
        ..reminderDays = (_reminders.toSet().toList()..sort((a, b) => b.compareTo(a)))
        ..notes = _notes.text.trim()
        ..attachments = atts;
      await store.saveDocument(d);
      for (final a in _removed) {
        await store.vault.delete(a.fileName);
      }
      if (mounted) Navigator.of(context).pop();
    } on LimitReachedException {
      if (mounted) {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen(reason: true)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
