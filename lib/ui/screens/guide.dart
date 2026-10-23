import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/guides.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

class GuideScreen extends StatelessWidget {
  final DocType type;
  const GuideScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final g = guideFor(type);
    final a = context.ar;
    Widget list(List<String> items, {bool numbered = false}) => Column(children: [
          for (var i = 0; i < items.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 30,
                  child: numbered
                      ? Text('${i + 1}.', style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, color: a.cinnabar, fontSize: 15))
                      : Padding(padding: const EdgeInsets.only(top: 2), child: Gl(Ic.check, size: 16, color: a.olive)),
                ),
                Expanded(child: Text(items[i], style: const TextStyle(fontSize: 14, height: 1.45))),
              ]),
            ),
        ]);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: Gl(Ic.close, size: 22, color: a.ink), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(tr('HƯỚNG DẪN GIA HẠN')),
      ),
      body: NotebookBackground(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 48), children: [
          Row(children: [
            Gl(type.icon, size: 22, color: a.cinnabar),
            const SizedBox(width: 10),
            Text(type.code, style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, color: a.cinnabar, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          Text(type.label, style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: a.cinnabar, width: 2))),
            child: Text(g.summary, style: TextStyle(fontFamily: serif, fontSize: 16.5, height: 1.5, color: a.ink)),
          ),
          SectionLabel(tr('Cần mang theo'), index: 'i.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
          list(g.bring),
          SectionLabel(tr('Làm ở đâu'), index: 'ii.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
          list(g.where, numbered: true),
          SectionLabel(tr('Lệ phí'), index: 'iii.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 10)),
          Text(g.fee, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (g.tips.isNotEmpty) ...[
            SectionLabel(tr('Mẹo'), index: 'iv.', padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            list(g.tips),
          ],
          if (g.links.isNotEmpty) ...[
            SectionLabel(tr('Liên kết'), padding: const EdgeInsets.fromLTRB(0, 30, 0, 4)),
            for (final l in g.links)
              InkWell(
                onTap: () => launchUrl(Uri.parse(l.url), mode: LaunchMode.externalApplication),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.rule))),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(Uri.parse(l.url).host, style: TextStyle(color: a.cinnabar, fontSize: 12.5)),
                      ]),
                    ),
                    Gl(Ic.external, size: 18, color: a.inkSoft),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 22),
          Text(
            tr('Thông tin mang tính tham khảo chung, có thể thay đổi theo quy định mới và từng địa phương. Hãy kiểm tra trên Cổng Dịch vụ công hoặc nơi làm thủ tục trước khi đi.'),
            style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 13, height: 1.5, color: a.inkSoft),
          ),
        ]),
      ),
    );
  }
}
