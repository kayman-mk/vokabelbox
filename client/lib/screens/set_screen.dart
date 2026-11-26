import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';
import 'import_screen.dart';
import 'statistics_screen.dart';
import 'study_screen.dart';
import '../widgets/common_widgets.dart';

class SetScreen extends StatefulWidget {
  const SetScreen({required this.api, required this.vocabularySet, super.key});

  final ApiClient api;
  final VocabularySet vocabularySet;

  @override
  State<SetScreen> createState() => _SetScreenState();
}

class _SetScreenState extends State<SetScreen> {
  late Future<List<Vocabulary>> _words;

  @override
  void initState() {
    super.initState();
    _words = widget.api.getWords(widget.vocabularySet.id);
  }

  Future<void> _addWord() async {
    final prompt = TextEditingController();
    final answer = TextEditingController();
    final word = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vokabel hinzufügen'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: prompt, autofocus: true, decoration: const InputDecoration(labelText: 'Vorderseite', hintText: 'house')), const SizedBox(height: 12), TextField(controller: answer, decoration: const InputDecoration(labelText: 'Übersetzung', hintText: 'Haus'), onSubmitted: (_) => Navigator.pop(context, (prompt.text.trim(), answer.text.trim())))])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, (prompt.text.trim(), answer.text.trim())), child: const Text('Speichern'))],
      ),
    );
    prompt.dispose();
    answer.dispose();
    if (word == null || word.$1.isEmpty || word.$2.isEmpty) return;
    try {
      await widget.api.addWord(widget.vocabularySet.id, word.$1, word.$2);
      if (mounted) setState(() => _words = widget.api.getWords(widget.vocabularySet.id));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _importCsv() async {
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => ImportScreen(api: widget.api, vocabularySet: widget.vocabularySet)),
    );
    if (imported == true && mounted) {
      setState(() => _words = widget.api.getWords(widget.vocabularySet.id));
    }
  }

  Future<void> _startStudy(String direction) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StudyScreen(api: widget.api, vocabularySet: widget.vocabularySet, direction: direction),
      ),
    );
  }

  Future<void> _openStatistics() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StatisticsScreen(api: widget.api, vocabularySet: widget.vocabularySet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: vokabelPaper, title: Text(widget.vocabularySet.name, style: const TextStyle(color: vokabelInk, fontWeight: FontWeight.w600)), actions: [IconButton(tooltip: 'CSV importieren', onPressed: _importCsv, icon: const Icon(Icons.upload_file_rounded)), IconButton(tooltip: 'Vokabel hinzufügen', onPressed: _addWord, icon: const Icon(Icons.add_rounded)), const SizedBox(width: 8)]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: FutureBuilder<List<Vocabulary>>(
        future: _words,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
          if (snapshot.hasError) return Text(snapshot.error.toString());
          final words = snapshot.data ?? [];
          if (words.isEmpty) return EmptyPanel(title: 'Noch keine Vokabeln', subtitle: 'Füge ein Wortpaar hinzu, um deine Lernbox zu füllen.', action: FilledButton.icon(onPressed: _addWord, icon: const Icon(Icons.add_rounded), label: const Text('Vokabel hinzufügen')));
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: words.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mit FSRS lernen', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _startStudy('foreign_to_local'),
                              icon: const Icon(Icons.translate_rounded),
                              label: const Text('Fremdsprache → Muttersprache'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _startStudy('local_to_foreign'),
                              icon: const Icon(Icons.swap_horiz_rounded),
                              label: const Text('Muttersprache → Fremdsprache'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _openStatistics,
                              icon: const Icon(Icons.bar_chart_rounded),
                              label: const Text('Statistik'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              return WordRow(word: words[index - 1]);
            },
          );
        },
      ))),
    );
  }
}

