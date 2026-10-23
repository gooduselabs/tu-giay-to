import 'package:flutter/material.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../app.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/wallet_card.dart';
import 'doc_detail.dart';

class ProfilesScreen extends StatelessWidget {
  const ProfilesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final people = store.profileList.where((p) => p.isPerson).toList();
    final assets = store.profileList.where((p) => !p.isPerson).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showProfileEditor(context),
        child: const Icon(Icons.person_add_alt_1_outlined),
      ),
      body: NotebookBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(padding: const EdgeInsets.only(bottom: 100), children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 20, 0),
              child: Text(tr('Hồ sơ gia đình'), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 32)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 20, 0),
              child: Text(tr('Thành viên và tài sản: xe, nhà, thiết bị.'),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6))),
            ),
            if (store.profiles.isEmpty)
              EmptyState(
                icon: Icons.family_restroom,
                title: tr('Chưa có hồ sơ'),
                body: tr('Tạo hồ sơ cho từng người và tài sản để gom giấy tờ theo chủ sở hữu.'),
              ),
            if (people.isNotEmpty) SectionLabel(tr('Thành viên')),
            for (final p in people) _ProfileTile(p),
            if (assets.isNotEmpty) SectionLabel(tr('Tài sản')),
            for (final p in assets) _ProfileTile(p),
          ]),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final Profile p;
  const _ProfileTile(this.p);
  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final docs = store.docsOf(p.id);
    final t = Theme.of(context);
    final worst = docs.isEmpty ? Urgency.none : urgencyOf(docs.first);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileDetailScreen(profileId: p.id))),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              ProfileAvatar(p),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(p.name, style: t.textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
                    if (p.isSample) ...[
                      const SizedBox(width: 6),
                      Text(tr('MẪU'), style: const TextStyle(fontSize: 10, color: Palette.brass, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text([p.kind.label, if (p.subtitle.isNotEmpty) p.subtitle].join(' · '),
                      style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .6))),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${docs.length}', style: t.textTheme.titleLarge),
                Text(tr('giấy tờ'), style: t.textTheme.bodySmall),
              ]),
              const SizedBox(width: 8),
              Container(width: 4, height: 36, decoration: BoxDecoration(color: urgencyColor(worst), borderRadius: BorderRadius.circular(2))),
            ]),
          ),
        ),
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
    final docs = store.docsOf(p.id);
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(actions: [
        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showProfileEditor(context, existing: p)),
        PopupMenuButton<String>(
          onSelected: (v) async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(tr('Xoá hồ sơ?')),
                content: Text(tr('Toàn bộ {n} giấy tờ của hồ sơ này cũng sẽ bị xoá.', {'n': docs.length})),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Huỷ'))),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Xoá'))),
                ],
              ),
            );
            if (ok == true && context.mounted) {
              await store.deleteProfile(p.id);
              if (context.mounted) Navigator.of(context).pop();
            }
          },
          itemBuilder: (_) => [PopupMenuItem(value: 'del', child: Text(tr('Xoá hồ sơ')))],
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewDocument(context, profileId: p.id,
            type: switch (p.kind) {
              ProfileKind.car || ProfileKind.motorbike => DocType.inspection,
              ProfileKind.device => DocType.warranty,
              ProfileKind.person => DocType.cccd,
              _ => DocType.other,
            }),
        icon: const Icon(Icons.add),
        label: Text(tr('Thêm giấy tờ')),
      ),
      body: NotebookBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
          Row(children: [
            ProfileAvatar(p, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: t.textTheme.headlineSmall),
                Text([p.kind.label, if (p.subtitle.isNotEmpty) p.subtitle].join(' · '),
                    style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .6))),
                if (p.birthDate != null)
                  Text(tr('Sinh ngày {d}', {'d': dmy.format(p.birthDate!)}), style: t.textTheme.bodySmall),
              ]),
            ),
          ]),
          if (p.isPerson && p.birthDate != null) ...[
            const SizedBox(height: 14),
            Builder(builder: (_) {
              final m = nextCccdMilestone(p.birthDate!);
              if (m == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Palette.brass.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.badge_outlined, color: Palette.brass, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(tr('Mốc đổi CCCD tiếp theo: {age} tuổi — {date}', {'age': m.age, 'date': dmy.format(m.date)}),
                        style: t.textTheme.bodyMedium),
                  ),
                ]),
              );
            }),
          ],
          SectionLabel(tr('Giấy tờ ({n})', {'n': docs.length})),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(tr('Chưa có giấy tờ nào.'), textAlign: TextAlign.center),
            ),
          for (final d in docs)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: WalletCard(
                doc: d,
                compact: true,
                ownerName: p.name,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocDetailScreen(docId: d.id))),
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
              avatar: Icon(k.icon, size: 16, color: k == _kind ? Colors.white : null),
              label: Text(k.label),
              selected: k == _kind,
              labelStyle: TextStyle(color: k == _kind ? Colors.white : t.colorScheme.onSurface),
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
                  labelText: tr('Ngày sinh (để nhắc mốc đổi CCCD)'), suffixIcon: const Icon(Icons.cake_outlined)),
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
                  shape: BoxShape.circle,
                  border: Border.all(color: i == _color ? Palette.brass : Colors.transparent, width: 3),
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
