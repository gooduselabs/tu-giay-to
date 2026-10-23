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
import '../widgets/wallet_card.dart';
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

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    final t = Theme.of(context);
    final docs = store.search(_q.text, urgencies: _urg, profileId: _profileId, type: _type);
    final upcoming = store.sortedDocs
        .where((d) => const {Urgency.expired, Urgency.red, Urgency.yellow}.contains(urgencyOf(d)))
        .toList();
    final counts = store.urgencyCounts;
    final searching = _q.text.isNotEmpty || _filter != HomeFilter.all || _profileId != null || _type != null;
    final today = DateFormat.yMMMMEEEEd(L10n.locale.value).format(DateTime.now());

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewDocument(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Thêm giấy tờ')),
      ),
      body: NotebookBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 20, 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(today.toUpperCase(),
                      style: t.textTheme.labelSmall?.copyWith(color: Palette.brass, letterSpacing: 1.6)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text(tr('Tủ Giấy Tờ'), style: t.textTheme.displaySmall?.copyWith(fontSize: 34))),
                    if (!store.isPro)
                      Text('${store.userDocCount}/${AppStore.freeLimit}',
                          style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .5))),
                  ]),
                  const SizedBox(height: 2),
                  Text(tr('Giấy tờ cả nhà, gọn trong một cuốn sổ.'),
                      style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .6))),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: _SummaryStrip(counts: counts, onTap: (f) => setState(() => _filter = f))),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: tr('Tìm theo tên, số giấy tờ, biển số…'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _q.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _q.clear())),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _filters(store)),
            if (store.docs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: EmptyState(
                    icon: Icons.style_outlined,
                    title: tr('Cuốn sổ đang trống'),
                    body: tr('Chụp CCCD, bằng lái, đăng kiểm… ứng dụng tự đọc số & ngày hết hạn và nhắc bạn trước hạn.'),
                    action: Column(children: [
                      FilledButton.icon(
                          onPressed: () => openNewDocument(context),
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: Text(tr('Thêm giấy tờ đầu tiên'))),
                      TextButton(
                          onPressed: () => seedSamples(store, art: sampleArt),
                          child: Text(tr('Xem thử với dữ liệu mẫu'))),
                    ]),
                  ),
                ),
              )
            else ...[
              if (!searching && upcoming.isNotEmpty) ...[
                SliverToBoxAdapter(child: SectionLabel(tr('Sắp đến hạn'))),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: PageView.builder(
                      controller: PageController(viewportFraction: .86),
                      padEnds: false,
                      itemCount: upcoming.length,
                      itemBuilder: (c, i) => Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 20 : 6, right: 6, bottom: 14),
                        child: WalletCard(
                          doc: upcoming[i],
                          ownerName: store.profiles[upcoming[i].profileId]?.name,
                          onTap: () => _open(upcoming[i]),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: SectionLabel(searching ? tr('Kết quả ({n})', {'n': docs.length}) : tr('Tất cả giấy tờ')),
              ),
              if (docs.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(icon: Icons.search_off, title: tr('Không tìm thấy'), body: tr('Thử từ khoá hoặc bộ lọc khác.')),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (c, i) => WalletCard(
                    doc: docs[i],
                    compact: true,
                    ownerName: store.profiles[docs[i].profileId]?.name,
                    onTap: () => _open(docs[i]),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  void _open(Document d) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocDetailScreen(docId: d.id)));

  Widget _filters(AppStore store) {
    Widget chip(String label, bool sel, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
              label: Text(label),
              selected: sel,
              labelStyle: TextStyle(color: sel ? Colors.white : Theme.of(context).colorScheme.onSurface),
              onSelected: (_) => onTap()),
        );
    final profiles = store.profileList;
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
        children: [
          chip(tr('Tất cả'), _filter == HomeFilter.all, () => setState(() => _filter = HomeFilter.all)),
          chip(tr('Sắp hết hạn'), _filter == HomeFilter.soon, () => setState(() => _filter = HomeFilter.soon)),
          chip(tr('Đã hết hạn'), _filter == HomeFilter.expired, () => setState(() => _filter = HomeFilter.expired)),
          chip(tr('Không thời hạn'), _filter == HomeFilter.noExpiry, () => setState(() => _filter = HomeFilter.noExpiry)),
          _menuChip<String>(
            label: _profileId == null ? tr('Hồ sơ') : store.profiles[_profileId]?.name ?? '',
            selected: _profileId != null,
            items: {null: tr('Mọi hồ sơ'), for (final p in profiles) p.id: p.name},
            onSelected: (v) => setState(() => _profileId = v),
          ),
          _menuChip<DocType>(
            label: _type == null ? tr('Loại') : _type!.label,
            selected: _type != null,
            items: {null: tr('Mọi loại'), for (final t in DocType.values) t: t.label},
            onSelected: (v) => setState(() => _type = v),
          ),
        ],
      ),
    );
  }

  Widget _menuChip<T>({required String label, required bool selected, required Map<T?, String> items, required ValueChanged<T?> onSelected}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<T?>(
        onSelected: onSelected,
        itemBuilder: (_) => [for (final e in items.entries) PopupMenuItem<T?>(value: e.key, child: Text(e.value))],
        child: Chip(
          label: Text(label),
          avatar: const Icon(Icons.expand_more, size: 18),
          backgroundColor: selected ? Theme.of(context).chipTheme.selectedColor : null,
          labelStyle: selected ? const TextStyle(color: Colors.white) : null,
        ),
      ),
    );
  }
}

class AppStoreLimit {
  static const free = 10;
}

class _SummaryStrip extends StatelessWidget {
  final Map<Urgency, int> counts;
  final ValueChanged<HomeFilter> onTap;
  const _SummaryStrip({required this.counts, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget cell(String label, int n, Color c, HomeFilter f) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onTap(f),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.labelSmall?.copyWith(letterSpacing: 0, fontSize: 11.5, color: t.colorScheme.onSurface.withValues(alpha: .65))),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('$n', style: t.textTheme.headlineMedium?.copyWith(fontSize: 26, color: c)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            cell(tr('Quá hạn'), counts[Urgency.expired]!, urgencyColor(Urgency.expired), HomeFilter.expired),
            cell(tr('Gấp'), counts[Urgency.red]!, Palette.red, HomeFilter.soon),
            cell(tr('Sắp tới'), counts[Urgency.yellow]!, Palette.yellow, HomeFilter.soon),
            cell(tr('Ổn'), counts[Urgency.green]!, Palette.green, HomeFilter.all),
          ]),
        ),
      ),
    );
  }
}
