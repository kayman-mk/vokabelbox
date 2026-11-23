import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: light ? const Color(0xFF34456F) : const Color(0xFFE9ECFF), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.style_rounded, color: light ? Colors.white : vokabelAccent, size: 22)),
        const SizedBox(width: 11),
        Text('VokabelBox', style: TextStyle(color: light ? Colors.white : vokabelInk, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      ]);
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: vokabelInk, fontWeight: FontWeight.w600, fontSize: 14));
}

class SetCard extends StatelessWidget {
  const SetCard({required this.set, required this.onTap});
  final VocabularySet set;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFEAECF2))),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(22), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF0F2FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.bookmark_outline_rounded, color: vokabelAccent)),
            const SizedBox(height: 18),
            Text(set.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: vokabelInk, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 7),
            Text('${set.wordCount} Vokabeln', style: const TextStyle(color: vokabelMuted, fontSize: 14)),
            const SizedBox(height: 16),
            const Row(children: [Text('Lernbox öffnen', style: TextStyle(color: vokabelAccent, fontWeight: FontWeight.w600)), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, color: vokabelAccent, size: 17)]),
          ])),
        ),
      );
}

class WordRow extends StatelessWidget {
  const WordRow({required this.word});
  final Vocabulary word;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAECF2))), child: Row(children: [Expanded(child: Text(word.prompt, style: const TextStyle(color: vokabelInk, fontWeight: FontWeight.w600))), const Icon(Icons.arrow_forward_rounded, color: Color(0xFFA2AAB9), size: 18), const SizedBox(width: 16), Expanded(child: Text(word.answer, style: const TextStyle(color: vokabelMuted)))]));
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel({required this.title, required this.subtitle, required this.action});
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFEAECF2)), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Icon(Icons.auto_stories_outlined, size: 34, color: vokabelAccent), const SizedBox(height: 14), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: vokabelInk, fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 7), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: vokabelMuted)), const SizedBox(height: 20), action]));
}
