import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/guides.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';

class GuideScreen extends StatelessWidget {
  final DocType type;
  const GuideScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final g = guideFor(type);
    final t = Theme.of(context);
    Widget list(IconData icon, List<String> items) => Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (final s in items)
                ListTile(
                  dense: true,
                  leading: Icon(icon, size: 20, color: Palette.brass),
                  title: Text(s, style: t.textTheme.bodyMedium),
                  minLeadingWidth: 20,
                ),
            ]),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: Text(tr('Hướng dẫn gia hạn'))),
      body: NotebookBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
          Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16), gradient: LinearGradient(colors: type.gradient)),
              child: Icon(type.icon, color: Palette.brassLight),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(type.label, style: t.textTheme.headlineSmall)),
          ]),
          const SizedBox(height: 14),
          Text(g.summary, style: t.textTheme.bodyLarge?.copyWith(height: 1.5)),
          SectionLabel(tr('Cần mang theo')),
          list(Icons.check_circle_outline, g.bring),
          SectionLabel(tr('Làm ở đâu')),
          list(Icons.place_outlined, g.where),
          SectionLabel(tr('Lệ phí')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.payments_outlined, color: Palette.brass, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(g.fee, style: t.textTheme.bodyMedium?.copyWith(height: 1.45))),
              ]),
            ),
          ),
          if (g.tips.isNotEmpty) ...[
            SectionLabel(tr('Mẹo')),
            list(Icons.lightbulb_outline, g.tips),
          ],
          if (g.links.isNotEmpty) ...[
            SectionLabel(tr('Liên kết')),
            for (final l in g.links)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('${l.label} · ${Uri.parse(l.url).host}'),
                ),
              ),
          ],
          const SizedBox(height: 10),
          Text(
            tr('Thông tin mang tính tham khảo chung, có thể thay đổi theo quy định mới và từng địa phương. Hãy kiểm tra trên Cổng Dịch vụ công hoặc nơi làm thủ tục trước khi đi.'),
            style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .55), height: 1.4),
          ),
        ]),
      ),
    );
  }
}
