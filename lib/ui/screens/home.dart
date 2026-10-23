import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../data/sample_data.dart';
import '../../data/store.dart';
import '../../l10n/l10n.dart';
import '../app.dart';
import '../sample_art.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dossier.dart';
import '../widgets/glyphs.dart';
import 'doc_detail.dart';

enum HomeFilter { all, soon, expired, noExpiry }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _q = TextEditingController();
  HomeFilter _filter = HomeFilter.all;
  String? _profileId;
  DocType? _type;

  Set<Urgency>? get _urg => switch (_filter) {
        HomeFilter.all => null,
        HomeFilter.soon => {Urgency.red, Urgency.yellow},
        HomeFilter.expired => {Urgency.expired},
        HomeFilter.noExpiry => {Urgency.none},
      };

  void _open(Document d) => Navigator.of(context).push(FolderRoute(builder: (_) => DocDetailScreen(docId: d.id)));

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final a = context.ar;
    final t = Theme.of(context);
    final docs = store.search(_q.text, urgencies: _urg, profileId: _profileId, type: _type);
    final due = store.sortedDocs.where((d) => d.expiryDate != null).toList();
    final upcoming = due.where((d) => const {Urgency.expired, Urgency.red, Urgency.yellow}.contains(urgencyOf(d))).toList();
    final next = due.where((d) => (daysLeft(d) ?? -1) >= 0).toList()..sort((x, y) => x.expiryDate!.compareTo(y.expiryDate!));
    final counts = store.urgencyCounts;
    final searching = _q.text.isNotEmpty || _filter != HomeFilter.all || _profileId != null || _type != null;
    final loc = L10n.locale.value;

    return Scaffold(
      floatingActionButton: _NewButton(onTap: () => openNewDocument(context)),
      body: NotebookBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(children: [
                  Text(tr('SỔ LƯU TRỮ GIA ĐÌNH'), style: t.textTheme.labelSmall?.copyWith(color: a.ink)),
                  const SizedBox(width: 8),
                  Text('Nº ${store.docs.length.toString().padLeft(3, '0')}',
                      style: t.textTheme.labelSmall?.copyWith(color: a.cinnabar, fontFeatures: tabular)),
                  const Spacer(),
                  Text(DateFormat('EEEE, d.M.y', loc).format(DateTime.now()),
                      style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 13, color: a.inkSoft)),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Container(height: 1.5, color: a.ink),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 60, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('Tủ Giấy Tờ'), style: t.textTheme.displaySmall?.copyWith(fontSize: 44)),
                  const SizedBox(height: 2),
                  Text(tr('Giấy tờ cả nhà — có số, có hạn, có chỗ.'),
                      style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 15, color: a.inkSoft)),
                ]),
              ),
            ),
            if (store.docs.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  icon: Ic.folderOpen,
                  title: tr('Tủ còn trống'),
                  body: tr('Chụp CCCD, bằng lái, đăng kiểm… ứng dụng tự đọc số & ngày hết hạn và nhắc bạn trước hạn.'),
                  action: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    FilledButton(onPressed: () => openNewDocument(context), child: Text(tr('Lập hồ sơ đầu tiên'))),
                    const SizedBox(height: 6),
                    InkLink(tr('Xem thử với dữ liệu mẫu'), onTap: () => seedSamples(store, art: sampleArt)),
                  ]),
                ),
              )
            else ...[
              if (!searching && next.isNotEmpty) SliverToBoxAdapter(child: _NextUp(doc: next.first, store: store, onTap: () => _open(next.first))),
              SliverToBoxAdapter(child: _Tally(counts: counts, onTap: (f) => setState(() => _filter = f))),
              SliverToBoxAdapter(child: _searchBar(a)),
              SliverToBoxAdapter(child: _filters(store, a)),
              if (!searching && upcoming.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionLabel(tr('Sổ hạn'), index: 'i.')),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      for (final d in upcoming.take(5)) _RegisterRow(doc: d, owner: store.profiles[d.profileId]?.name, onTap: () => _open(d)),
                    ]),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionLabel(searching ? tr('Kết quả ({n})', {'n': docs.length}) : tr('Tủ hồ sơ'), index: searching ? null : 'ii.'),
              ),
              if (docs.isEmpty)
                SliverToBoxAdapter(
                    child: EmptyState(icon: Ic.search, title: tr('Không tìm thấy'), body: tr('Thử từ khoá hoặc bộ lọc khác.'))),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (c, i) {
                    final p = store.profiles[docs[i].profileId];
                    return DossierCard(
                        doc: docs[i], compact: true, ownerName: p?.name, ownerSub: p?.isPerson == false ? p?.subtitle : null, onTap: () => _open(docs[i]));
                  },
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _searchBar(Archive a) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        child: TextField(
          controller: _q,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: tr('Tra cứu: tên, số giấy tờ, biển số…'),
            prefixIcon: Padding(padding: const EdgeInsets.only(right: 10), child: Gl(Ic.search, size: 20, color: a.ink)),
            prefixIconConstraints: const BoxConstraints(minWidth: 30),
            suffixIcon: _q.text.isEmpty
                ? null
                : IconButton(icon: Gl(Ic.close, size: 18, color: a.inkSoft), onPressed: () => setState(() => _q.clear())),
          ),
        ),
      );

  Widget _filters(AppStore store, Archive a) {
    Widget tab(String label, bool sel, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 18, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(fontSize: 13.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? a.ink : a.inkSoft)),
              const SizedBox(height: 4),
              AnimatedContainer(duration: const Duration(milliseconds: 180), height: 2, width: sel ? 18 : 0, color: a.cinnabar),
            ]),
          ),
        );
    Widget menu<T>(String label, bool sel, Map<T?, String> items, ValueChanged<T?> on) => PopupMenuButton<T?>(
          onSelected: on,
          itemBuilder: (_) => [for (final e in items.entries) PopupMenuItem<T?>(value: e.key, child: Text(e.value))],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 18, 12),
            child: Row(children: [
              Text(label, style: TextStyle(fontSize: 13.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w400, color: sel ? a.cinnabar : a.inkSoft)),
              Gl(Ic.chevronDown, size: 14, color: a.inkSoft),
            ]),
          ),
        );
    return SizedBox(
      height: 46,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
        tab(tr('Tất cả'), _filter == HomeFilter.all, () => setState(() => _filter = HomeFilter.all)),
        tab(tr('Sắp hết hạn'), _filter == HomeFilter.soon, () => setState(() => _filter = HomeFilter.soon)),
        tab(tr('Quá hạn'), _filter == HomeFilter.expired, () => setState(() => _filter = HomeFilter.expired)),
        tab(tr('Không thời hạn'), _filter == HomeFilter.noExpiry, () => setState(() => _filter = HomeFilter.noExpiry)),
        Container(width: 1, margin: const EdgeInsets.fromLTRB(0, 14, 18, 14), color: a.rule),
        menu<String>(_profileId == null ? tr('Hồ sơ') : store.profiles[_profileId]?.name ?? '', _profileId != null,
            {null: tr('Mọi hồ sơ'), for (final p in store.profileList) p.id: p.name}, (v) => setState(() => _profileId = v)),
        menu<DocType>(_type == null ? tr('Loại') : _type!.label, _type != null,
            {null: tr('Mọi loại'), for (final t in DocType.values) t: t.label}, (v) => setState(() => _type = v)),
      ]),
    );
  }
}

/// Khối "Việc gần nhất": số đếm ngược lớn bên trái, chi tiết bên phải — bố cục lệch.
class _NextUp extends StatelessWidget {
  final Document doc;
  final AppStore store;
  final VoidCallback onTap;
  const _NextUp({required this.doc, required this.store, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final left = daysLeft(doc)!;
    final u = urgencyOf(doc);
    final c = u == Urgency.green ? a.ink : urgencyColor(u, a);
    final p = store.profiles[doc.profileId];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('VIỆC GẦN NHẤT'), style: TextStyle(fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: a.cinnabar)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(left.toString().padLeft(2, '0'),
                style: TextStyle(fontFamily: serif, fontSize: 96, height: .9, fontWeight: FontWeight.w400, color: c, fontFeatures: tabular, letterSpacing: -4)),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('ngày nữa'), style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 15, color: a.inkSoft)),
                  const SizedBox(height: 4),
                  Text(doc.title.isEmpty ? doc.type.label : doc.title,
                      maxLines: 2, style: TextStyle(fontFamily: serif, fontSize: 19, height: 1.15, color: a.ink)),
                  Text('${p?.name ?? ''} · ${dmy.format(doc.expiryDate!)}', style: TextStyle(fontSize: 12.5, color: a.inkSoft)),
                ]),
              ),
            ),
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Stamp(u, animate: true)),
          ]),
        ]),
      ),
    );
  }
}

/// Bảng kiểm đếm: 4 cột ngăn bằng nét mảnh.
class _Tally extends StatelessWidget {
  final Map<Urgency, int> counts;
  final ValueChanged<HomeFilter> onTap;
  const _Tally({required this.counts, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    Widget cell(String label, int n, Color c, HomeFilter f, {bool last = false}) => Expanded(
          child: InkWell(
            onTap: () => onTap(f),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
              decoration: BoxDecoration(border: last ? null : Border(right: BorderSide(color: a.rule))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.toString().padLeft(2, '0'),
                    style: TextStyle(fontFamily: serif, fontSize: 26, height: 1, color: n == 0 ? a.inkFaint : c, fontFeatures: tabular)),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: a.inkSoft)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Container(
        decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: a.ruleStrong))),
        child: Row(children: [
          cell(tr('Quá hạn'), counts[Urgency.expired]!, a.cinnabar, HomeFilter.expired),
          cell(tr('Dưới 1 tuần'), counts[Urgency.red]!, a.cinnabar, HomeFilter.soon),
          cell(tr('Sắp tới'), counts[Urgency.yellow]!, a.ochre, HomeFilter.soon),
          cell(tr('Còn hạn'), counts[Urgency.green]!, a.olive, HomeFilter.all, last: true),
        ]),
      ),
    );
  }
}

/// Một dòng trong "Sổ hạn": ngày | tên | đếm ngược.
class _RegisterRow extends StatelessWidget {
  final Document doc;
  final String? owner;
  final VoidCallback onTap;
  const _RegisterRow({required this.doc, this.owner, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final u = urgencyOf(doc);
    final c = urgencyColor(u, a);
    final e = doc.expiryDate!;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule))),
        child: Row(children: [
          SizedBox(
            width: 54,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('dd.MM').format(e), style: TextStyle(fontFamily: serif, fontSize: 17, color: a.ink, fontFeatures: tabular)),
              Text('${e.year}', style: TextStyle(fontSize: 10.5, color: a.inkFaint, fontFeatures: tabular)),
            ]),
          ),
          Container(width: 3, height: 30, color: c, margin: const EdgeInsets.only(right: 12)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc.title.isEmpty ? doc.type.label : doc.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
              Text('${fileNumber(doc)} · ${owner ?? ''}', maxLines: 1, style: TextStyle(fontSize: 12, color: a.inkSoft, fontFeatures: tabular)),
            ]),
          ),
          Text(statusText(doc), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c, fontFeatures: tabular)),
        ]),
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _NewButton({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return Material(
      color: a.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 20, 14),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Gl(Ic.add, size: 18, color: a.paper),
            const SizedBox(width: 10),
            Text(tr('LẬP HỒ SƠ'), style: TextStyle(color: a.paper, fontWeight: FontWeight.w700, letterSpacing: 1.8, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}
