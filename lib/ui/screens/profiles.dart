import 'package:flutter/material.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../app.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dossier.dart';
import '../widgets/glyphs.dart';
import 'doc_detail.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final a = context.ar;
    final people = store.profileList.where((p) => p.isPerson).toList();
    final assets = store.profileList.where((p) => !p.isPerson).toList();
    return Scaffold(
      body: NotebookBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.only(bottom: 60), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(children: [
                Text(tr('SỔ HỘ TỊCH'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: a.ink)),
                const Spacer(),
                InkLink(tr('Thêm hồ sơ'), icon: Ic.personAdd, onTap: () => showProfileEditor(context)),
              ]),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(height: 1.5, color: a.ink)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 70, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Gia đình'), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 44)),
                Text(tr('Người và tài sản — mỗi hồ sơ một ngăn.'),
                    style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 15, color: a.inkSoft)),
              ]),
            ),
            if (store.profiles.isEmpty)
              EmptyState(icon: Ic.people, title: tr('Chưa có hồ sơ'), body: tr('Tạo hồ sơ cho từng người và tài sản để gom giấy tờ theo chủ sở hữu.')),
            if (people.isNotEmpty) SectionLabel(tr('Thành viên'), index: 'i.'),
            for (var i = 0; i < people.length; i++) _ProfileRow(people[i], n: i + 1),
            if (assets.isNotEmpty) SectionLabel(tr('Tài sản'), index: 'ii.'),
            for (var i = 0; i < assets.length; i++) _ProfileRow(assets[i], n: i + 1),
          ]),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final Profile p;
  final int n;
  const _ProfileRow(this.p, {required this.n});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final a = context.ar;
    final docs = store.docsOf(p.id);
    final worst = docs.isEmpty ? Urgency.none : urgencyOf(docs.first);
    return InkWell(
      onTap: () => Navigator.of(context).push(FolderRoute(builder: (_) => ProfileDetailScreen(profileId: p.id))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule))),
        child: Row(children: [
          SizedBox(width: 26, child: Text(n.toString().padLeft(2, '0'), style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, color: a.inkFaint, fontFeatures: tabular))),
          ProfileAvatar(p, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: serif, fontSize: 18, color: a.ink))),
                if (p.isSample) ...[const SizedBox(width: 8), Text(tr('MẪU'), style: TextStyle(fontSize: 9.5, color: a.cinnabar, fontWeight: FontWeight.w700, letterSpacing: 1.2))],
              ]),
              Text([p.kind.label, if (p.subtitle.isNotEmpty) p.subtitle].join(' · '), style: TextStyle(fontSize: 12.5, color: a.inkSoft)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(docs.length.toString().padLeft(2, '0'), style: TextStyle(fontFamily: serif, fontSize: 22, height: 1, color: a.ink, fontFeatures: tabular)),
            const SizedBox(height: 2),
            if (worst != Urgency.none && worst != Urgency.green)
              Text(stampText(worst), style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: urgencyColor(worst, a)))
            else
              Text(tr('GIẤY TỜ'), style: TextStyle(fontSize: 9, letterSpacing: 1.2, color: a.inkFaint)),
          ]),
        ]),
      ),
    );
  }
}

class ProfileDetailScreen extends StatelessWidget {
  final String profileId;
  const ProfileDetailScreen({super.key, required this.profileId});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final p = store.profiles[profileId];
    if (p == null) return const Scaffold();
    final a = context.ar;
    final docs = store.docsOf(p.id);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Gl(Ic.close, size: 22, color: a.ink), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(p.isPerson ? tr('HỒ SƠ THÀNH VIÊN') : tr('HỒ SƠ TÀI SẢN')),
        actions: [
          IconButton(icon: Gl(Ic.pen, size: 20, color: a.ink), onPressed: () => showProfileEditor(context, existing: p)),
          IconButton(
            icon: Gl(Ic.trash, size: 20, color: a.ink),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(tr('Xoá hồ sơ?')),
                  content: Text(tr('Toàn bộ {n} giấy tờ của hồ sơ này cũng sẽ bị xoá.', {'n': docs.length})),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Giữ lại'), style: TextStyle(color: a.ink))),
                    FilledButton(style: FilledButton.styleFrom(backgroundColor: a.cinnabar), onPressed: () => Navigator.pop(c, true), child: Text(tr('Xoá'))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await store.deleteProfile(p.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: NotebookBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 60), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ProfileAvatar(p, size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 30)),
                Text([p.kind.label, if (p.subtitle.isNotEmpty) p.subtitle].join(' · '),
                    style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, color: a.inkSoft, fontSize: 15)),
              ]),
            ),
          ]),
          const SizedBox(height: 18),
          if (p.birthDate != null) LedgerRow(tr('Ngày sinh'), dmy.format(p.birthDate!)),
          if (p.isPerson && p.birthDate != null && nextCccdMilestone(p.birthDate!) != null)
            LedgerRow(tr('Mốc đổi CCCD'), () {
              final m = nextCccdMilestone(p.birthDate!)!;
              return tr('{age} tuổi · {date}', {'age': m.age, 'date': dmy.format(m.date)});
            }()),
          LedgerRow(tr('Số giấy tờ'), docs.length.toString(), last: true),
          SectionLabel(tr('Giấy tờ ({n})', {'n': docs.length}), index: 'i.', padding: const EdgeInsets.fromLTRB(0, 26, 0, 12),
              trailing: InkLink(tr('Thêm'), icon: Ic.add, onTap: () => openNewDocument(context, profileId: p.id,
                  type: switch (p.kind) {
                    ProfileKind.car || ProfileKind.motorbike => DocType.inspection,
                    ProfileKind.device => DocType.warranty,
                    ProfileKind.person => DocType.cccd,
                    _ => DocType.other,
                  }))),
          if (docs.isEmpty) Text(tr('Chưa có giấy tờ nào.'), style: TextStyle(color: a.inkSoft)),
          for (final d in docs)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DossierCard(
                doc: d, compact: true, ownerName: p.name,
                onTap: () => Navigator.of(context).push(FolderRoute(builder: (_) => DocDetailScreen(docId: d.id))),
              ),
            ),
        ]),
      ),
    );
  }
}

Future<Profile?> showProfileEditor(BuildContext context, {Profile? existing, ProfileKind? kind}) {
  return showModalBottomSheet<Profile>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProfileEditor(existing: existing, kind: kind),
  );
}

class _ProfileEditor extends StatefulWidget {
  final Profile? existing;
  final ProfileKind? kind;
  const _ProfileEditor({this.existing, this.kind});
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late ProfileKind _kind = widget.existing?.kind ?? widget.kind ?? ProfileKind.person;
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _sub = TextEditingController(text: widget.existing?.subtitle);
  late DateTime? _birth = widget.existing?.birthDate;
  late int _color = widget.existing?.colorIndex ?? DateTime.now().millisecond % Palette.profileColors.length;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.existing == null ? tr('Hồ sơ mới') : tr('Sửa hồ sơ'), style: t.textTheme.titleLarge),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in ProfileKind.values)
            ChoiceChip(
              avatar: Gl(k.icon, size: 16, color: k == _kind ? context.ar.paper : context.ar.ink),
              label: Text(k.label),
              selected: k == _kind,
              labelStyle: TextStyle(color: k == _kind ? context.ar.paper : context.ar.ink),
              onSelected: (_) => setState(() => _kind = k),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: widget.existing == null,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _kind == ProfileKind.person ? tr('Họ và tên') : tr('Tên tài sản')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _sub,
          decoration: InputDecoration(
              labelText: switch (_kind) {
            ProfileKind.person => tr('Quan hệ (bố, mẹ, con…)'),
            ProfileKind.car || ProfileKind.motorbike => tr('Biển số'),
            ProfileKind.house => tr('Địa chỉ'),
            _ => tr('Mô tả / model'),
          }),
        ),
        if (_kind == ProfileKind.person) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  initialDate: _birth ?? DateTime(1990),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now());
              if (d != null) setState(() => _birth = d);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: tr('Ngày sinh (để nhắc mốc đổi CCCD)'), suffixIcon: Padding(padding: const EdgeInsets.all(10), child: Gl(Ic.calendar, size: 18, color: context.ar.inkSoft))),
              child: Text(_birth == null ? '—' : dmy.format(_birth!)),
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          for (var i = 0; i < Palette.profileColors.length; i++)
            GestureDetector(
              onTap: () => setState(() => _color = i),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Palette.profileColors[i],
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: i == _color ? context.ar.ink : Colors.transparent, width: 2),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: () async {
            if (_name.text.trim().isEmpty) return;
            final store = AppScope.store(context);
            final p = widget.existing ?? Profile(id: store.newId(), name: '');
            p
              ..name = _name.text.trim()
              ..kind = _kind
              ..subtitle = _sub.text.trim()
              ..birthDate = _kind == ProfileKind.person ? _birth : null
              ..colorIndex = _color;
            await store.saveProfile(p);
            if (context.mounted) Navigator.of(context).pop(p);
          },
          child: Text(tr('Lưu hồ sơ')),
        ),
      ]),
    );
  }
}
