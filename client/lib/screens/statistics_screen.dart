import 'package:flutter/material.dart';

import '../api.dart';
import 'fsrs_reference_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({required this.api, required this.vocabularySet, super.key});

  final ApiClient api;
  final VocabularySet vocabularySet;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  String _direction = 'foreign_to_local';
  late Future<LearningStatistics> _statistics;

  bool get _foreignToLocal => _direction == 'foreign_to_local';

  @override
  void initState() {
    super.initState();
    _statistics = widget.api.getLearningStatistics(widget.vocabularySet.id, _direction);
  }

  void _selectDirection(Set<String> selection) {
    final direction = selection.first;
    setState(() {
      _direction = direction;
      _statistics = widget.api.getLearningStatistics(widget.vocabularySet.id, direction);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lernstatistik'),
          actions: [
            IconButton(
              tooltip: 'FSRS Referenz',
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const FsrsReferenceScreen()),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: FutureBuilder<LearningStatistics>(
              future: _statistics,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
                final statistics = snapshot.data!;
                final progress = statistics.progress;
                final reviews = statistics.reviews;
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(widget.vocabularySet.name, style: Theme.of(context).textTheme.headlineSmall)),
                        const Chip(label: Text('FSRS')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'foreign_to_local', label: Text('Fremd → lokal')),
                        ButtonSegment(value: 'local_to_foreign', label: Text('Lokal → fremd')),
                      ],
                      selected: {_direction},
                      onSelectionChanged: _selectDirection,
                    ),
                    const SizedBox(height: 8),
                    Text(_foreignToLocal ? 'Fremdsprache → Muttersprache' : 'Muttersprache → Fremdsprache', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _metric(context, 'Bearbeitete Karten', '${progress.reviewedCount} / ${progress.total}'),
                        _metric(context, 'Jetzt fällig', '${progress.dueCount}'),
                        _metric(context, 'Noch neu', '${progress.newCount}'),
                        _metric(context, 'Bewertungen', '${reviews.total}'),
                        _metric(context, 'Nochmal nötig', '${progress.lapses}'),
                        _metric(context, 'Lerntage · 14 Tage', '${statistics.dailyActivity.length}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _sectionCard(
                      context,
                      title: 'Bewertungen',
                      child: Column(
                        children: [
                          _ratingRow(context, 'Nochmal', reviews.againCount, reviews.total, Colors.red),
                          _ratingRow(context, 'Schwer', reviews.hardCount, reviews.total, Colors.orange),
                          _ratingRow(context, 'Gut', reviews.goodCount, reviews.total, Colors.green),
                          _ratingRow(context, 'Einfach', reviews.easyCount, reviews.total, Colors.blue),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionCard(
                      context,
                      title: 'Lernaktivität · letzte 14 Tage',
                      child: _activityChart(context, statistics.dailyActivity),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

  Widget _metric(BuildContext context, String label, String value) => SizedBox(
        width: 150,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      );

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      );

  Widget _ratingRow(BuildContext context, String label, int count, int total, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            SizedBox(width: 92, child: Text(label)),
            Expanded(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : count / total,
                color: color,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            SizedBox(width: 42, child: Text('$count', textAlign: TextAlign.end)),
          ],
        ),
      );

  Widget _activityChart(BuildContext context, List<DailyReviewActivity> activity) {
    final byDay = {for (final item in activity) item.day: item.reviews};
    final today = DateTime.now().toUtc();
    final dates = List.generate(14, (index) {
      final date = DateTime.utc(today.year, today.month, today.day).subtract(Duration(days: 13 - index));
      final key = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return (date, byDay[key] ?? 0);
    });
    final maximum = dates.fold<int>(1, (maxValue, item) => item.$2 > maxValue ? item.$2 : maxValue);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in dates)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(item.$2 == 0 ? '' : '${item.$2}', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: item.$2 == 0 ? 0.025 : item.$2 / maximum,
                          widthFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: item.$2 == 0 ? Theme.of(context).colorScheme.surfaceContainerHighest : Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${item.$1.day}', style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
