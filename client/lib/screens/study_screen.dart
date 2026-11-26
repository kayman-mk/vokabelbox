import 'package:flutter/material.dart';

import '../api.dart';

class StudyScreen extends StatefulWidget {
  const StudyScreen({required this.api, required this.vocabularySet, required this.direction, this.limit = 20, super.key});

  final ApiClient api;
  final VocabularySet vocabularySet;
  final String direction;
  final int limit;

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  late Future<StudySession> _session;
  int _index = 0;
  bool _revealed = false;
  bool _saving = false;
  final List<int> _ratings = [0, 0, 0, 0, 0];

  bool get _foreignToLocal => widget.direction == 'foreign_to_local';

  @override
  void initState() {
    super.initState();
    _session = widget.api.getStudySession(widget.vocabularySet.id, widget.direction, limit: widget.limit);
  }

  Future<void> _rate(StudyCard card, int rating) async {
    setState(() => _saving = true);
    try {
      await widget.api.reviewStudyCard(widget.vocabularySet.id, card.id, widget.direction, rating);
      if (mounted) setState(() {
        _ratings[rating]++;
        _index++;
        _revealed = false;
        _saving = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_foreignToLocal ? 'Fremdsprache → Muttersprache' : 'Muttersprache → Fremdsprache')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FutureBuilder<StudySession>(
              future: _session,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
                if (snapshot.hasError) return Text(snapshot.error.toString());
                final session = snapshot.data!;
                final cards = session.cards;
                final hasMore = _index < cards.length;
                final dueNew = session.stats.dueCount + session.stats.newCount;
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('FSRS · ${widget.vocabularySet.name}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text('${session.stats.reviewedCount} / ${session.stats.total} gelernt  ·  ${session.stats.dueCount} fällig  ·  ${session.stats.newCount} neu', textAlign: TextAlign.center),
                      Text('${session.stats.repetitions} Wiederholungen  ·  ${session.stats.lapses} Fehler', textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      if (hasMore) ...[
                        Text('Karte ${_index + 1} von ${cards.length}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                            child: Column(
                              children: [
                                Text(cards[_index].front, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                                if (_revealed) ...[
                                  const Divider(height: 36),
                                  Text(cards[_index].back, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!_revealed)
                          FilledButton(onPressed: () => setState(() => _revealed = true), child: const Text('Übersetzung anzeigen'))
                        else
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ratingButton(cards[_index], 'Nochmal', 1, Colors.red),
                              _ratingButton(cards[_index], 'Schwer', 2, Colors.orange),
                              _ratingButton(cards[_index], 'Gut', 3, Colors.green),
                              _ratingButton(cards[_index], 'Einfach', 4, Colors.blue),
                            ],
                          ),
                      ] else ...[
                        Icon(dueNew == 0 ? Icons.check_circle_outline_rounded : Icons.school_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(dueNew == 0 ? 'Alles gelernt' : 'Lernsitzung beendet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                        Text(dueNew == 0 && _index == 0 ? 'Für diese Richtung sind gerade keine Karten fällig.' : 'Alle Karten dieser Sitzung sind bewertet.', textAlign: TextAlign.center),
                        if (_index > 0) ...[
                          const SizedBox(height: 20),
                          Card(child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Dein Ergebnis', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              Text('$_index ${_index == 1 ? 'Karte' : 'Karten'} bewertet · ${_ratings[1]} nochmal · ${_ratings[2]} schwer · ${_ratings[3]} gut · ${_ratings[4]} einfach'),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: _index / cards.length, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                              const SizedBox(height: 8),
                              Text(_ratings[1] == 0 ? 'Stark! Heute waren alle Antworten mindestens gut.' : 'Gut gemacht. Die schwierigen Karten kommen passend wieder.', style: const TextStyle(height: 1.4)),
                            ]),
                          )),
                        ],
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

  Widget _ratingButton(StudyCard card, String label, int rating, Color color) => OutlinedButton(
        onPressed: _saving ? null : () => _rate(card, rating),
        style: OutlinedButton.styleFrom(foregroundColor: color),
        child: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(label),
      );

}
