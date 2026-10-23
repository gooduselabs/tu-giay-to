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
import '../widgets/common.dart';
import '../widgets/wallet_card.dart';
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
        WalletCard(doc: preview, ownerName: store.profiles[_profileId]?.name ?? '', compact: true, reveal: true),
        SectionLabel(tr('Ảnh & PDF')),
        _attachmentsRow(),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _srcBtn(Icons.photo_camera_outlined, tr('Chụp'), () => _add(Media.camera().then((x) => x == null ? <Picked>[] : [x])))),
          const SizedBox(width: 8),
          Expanded(child: _srcBtn(Icons.photo_library_outlined, tr('Thư viện'), () => _add(Media.gallery()))),
          const SizedBox(width: 8),
          Expanded(child: _srcBtn(Icons.picture_as_pdf_outlined, 'PDF', () => _add(Media.pdfs()))),
        ]),
        const SizedBox(height: 12),
        _ocrCard(t),
        SectionLabel(tr('Loại giấy tờ')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ty in DocType.values)
            ChoiceChip(
              avatar: Icon(ty.icon, size: 16, color: ty == _type ? Colors.white : null),
              label: Text(ty.label),
              selected: ty == _type,
              labelStyle: TextStyle(color: ty == _type ? Colors.white : t.colorScheme.onSurface),
              onSelected: (_) => setState(() {
                _type = ty;
                _reminders = List.of(ty.defaultReminderDays);
              }),
            ),
        ]),
        SectionLabel(tr('Thuộc hồ sơ')),
        _profilePicker(profiles),
        SectionLabel(tr('Thông tin')),
        TextField(controller: _title, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Tên gợi nhớ'), hintText: _type.label)),
        const SizedBox(height: 12),
        TextField(controller: _number, onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: tr('Số giấy tờ / biển số'), prefixIcon: const Icon(Icons.numbers))),
        const SizedBox(height: 12),
        TextField(controller: _holder, onChanged: (_) => setState(() {}), textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: tr('Họ tên trên giấy tờ'), prefixIcon: const Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _dateField(tr('Ngày cấp'), _issue, (d) => setState(() => _issue = d))),
          const SizedBox(width: 10),
          Expanded(child: _dateField(tr('Ngày hết hạn'), _expiry, (d) => setState(() => _expiry = d))),
        ]),
        if (_type == DocType.cccd) _cccdHelper(store),
        SectionLabel(tr('Nhắc trước hạn')),
        _reminderChips(),
        const SizedBox(height: 16),
        TextField(controller: _notes, maxLines: 3,
            decoration: InputDecoration(labelText: tr('Ghi chú'), alignLabelWithHint: true)),
        const SizedBox(height: 18),
        Text(tr('Dữ liệu và tệp được mã hoá, chỉ lưu trên máy này.'),
            textAlign: TextAlign.center,
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .5))),
      ]),
    );
  }

  Widget _srcBtn(IconData i, String label, VoidCallback onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(i, size: 18),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.brass.withValues(alpha: .5)),
          color: Palette.brass.withValues(alpha: .06),
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
                      borderRadius: BorderRadius.circular(14),
                      child: _pending[i].pdf
                          ? Container(color: t.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.picture_as_pdf_outlined, color: Palette.red, size: 34))
                          : Image.memory(_pending[i].bytes, fit: BoxFit.cover, cacheWidth: 300),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _pending.removeAt(i)),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Palette.brass, size: 20),
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
                style: t.textTheme.bodySmall?.copyWith(color: Palette.yellow))
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (g.type != null) _found(tr('Loại'), g.type!.label),
              if (g.number != null) _found(tr('Số'), g.number!),
              if (g.name != null) _found(tr('Tên'), g.name!),
              if (g.expiryDate != null) _found(tr('Hết hạn'), dmy.format(g.expiryDate!)),
              Text(tr('Đã điền sẵn — vui lòng kiểm tra lại.'),
                  style: t.textTheme.bodySmall?.copyWith(color: Palette.green, fontWeight: FontWeight.w600)),
            ]),
        ]),
      ),
    );
  }

  Widget _found(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Palette.green.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
        child: Text('$k: $v', style: const TextStyle(fontSize: 12.5, color: Palette.green, fontWeight: FontWeight.w600)),
      );

  Widget _profilePicker(List<Profile> profiles) {
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final p in profiles)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(p.kind.icon, size: 16, color: p.id == _profileId ? Colors.white : null),
              label: Text(p.name),
              selected: p.id == _profileId,
              labelStyle: TextStyle(color: p.id == _profileId ? Colors.white : Theme.of(context).colorScheme.onSurface),
              onSelected: (_) => setState(() => _profileId = p.id),
            ),
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
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

  Widget _dateField(String label, DateTime? v, ValueChanged<DateTime?> onChanged) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: v == null
              ? const Icon(Icons.event_outlined)
              : IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => onChanged(null)),
        ),
        child: Text(v == null ? '—' : dmy.format(v)),
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
        decoration: BoxDecoration(color: Palette.brass.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.cake_outlined, size: 18, color: Palette.brass),
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
          labelStyle: TextStyle(color: _reminders.contains(d) ? Colors.white : Theme.of(context).colorScheme.onSurface),
          onSelected: (s) => setState(() => s ? _reminders.add(d) : _reminders.remove(d)),
        ),
      ActionChip(
        avatar: const Icon(Icons.add, size: 16),
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

  Future<void> _add(Future<List<Picked>> f) async {
    LockGate.suppress = true;
    try {
      final xs = await f;
      if (xs.isEmpty) return;
      setState(() => _pending.addAll(xs));
      await _runOcr();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Không mở được tệp: {e}', {'e': e}))));
    } finally {
      LockGate.suppress = false;
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
    if (_number.text.isEmpty && g.number != null) _number.text = g.number!;
    if (_holder.text.isEmpty && g.name != null) _holder.text = g.name!;
    _issue ??= g.issueDate;
    _expiry ??= g.expiryDate;
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
        final me = Profile(id: store.newId(), name: _holder.text.isEmpty ? tr('Tôi') : _holder.text);
        await store.saveProfile(me);
        pid = me.id;
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
