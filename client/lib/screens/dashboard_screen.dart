import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';
import '../widgets/common_widgets.dart';
import 'set_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.api, required this.user, required this.onSignOut, super.key});

  final ApiClient api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<VocabularySet>> _sets;
  late Future<DailyMotivation> _motivation;

  @override
  void initState() {
    super.initState();
    _sets = widget.api.getSets();
    _motivation = widget.api.getDailyMotivation();
  }

  void _reload() => setState(() {
        _sets = widget.api.getSets();
        _motivation = widget.api.getDailyMotivation();
      });

  Future<void> _editDailyGoal(int currentGoal) async {
    final controller = TextEditingController(text: '$currentGoal');
    final goal = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tagesziel festlegen'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Karten pro Tag', helperText: 'Wähle ein Ziel zwischen 1 und 100.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 1 && value <= 100) Navigator.pop(context, value);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (goal == null) return;
    try {
      await widget.api.setDailyGoal(goal);
      if (mounted) setState(() => _motivation = widget.api.getDailyMotivation());
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _createSet() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final details = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Lernbox'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Name', hintText: 'z. B. Englisch – Unit 1')),
          TextField(controller: descriptionController, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'Beschreibung (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, (nameController.text.trim(), descriptionController.text.trim())), child: const Text('Erstellen')),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (details == null || details.$1.isEmpty) return;
    try {
      await widget.api.createSet(details.$1, description: details.$2);
      _reload();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _renameSet(VocabularySet set) async {
    final nameController = TextEditingController(text: set.name);
    final descriptionController = TextEditingController(text: set.description);
    final details = await showDialog<(String, String)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lernbox bearbeiten'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, autofocus: true, maxLength: 120, decoration: const InputDecoration(labelText: 'Name der Lernbox')),
          TextField(controller: descriptionController, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'Beschreibung (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, (nameController.text.trim(), descriptionController.text.trim())), child: const Text('Speichern')),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    if (details == null || details.$1.isEmpty || (details.$1 == set.name && details.$2 == set.description)) return;
    try {
      await widget.api.renameSet(set.id, details.$1, description: details.$2);
      _reload();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));

  @override
  Widget build(BuildContext context) {
    final username = widget.user['username'] as String? ?? '';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: vokabelPaper,
        title: const BrandMark(),
        actions: [
          if (MediaQuery.sizeOf(context).width > 520) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text(username, style: const TextStyle(color: vokabelMuted)))),
          IconButton(tooltip: 'Abmelden', onPressed: widget.onSignOut, icon: const Icon(Icons.logout_rounded)),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final horizontal = constraints.maxWidth > 900 ? 56.0 : 24.0;
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(horizontal, 40, horizontal, 64),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FutureBuilder<DailyMotivation>(
                  future: _motivation,
                  builder: (context, snapshot) {
                    final progress = snapshot.data;
                    if (progress == null) return const SizedBox.shrink();
                    final ratio = (progress.reviewsToday / progress.dailyGoal).clamp(0.0, 1.0).toDouble();
                    final reached = progress.reviewsToday >= progress.dailyGoal;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(reached ? Icons.emoji_events_outlined : Icons.today_rounded),
                            const SizedBox(width: 10),
                            Expanded(child: Text(reached ? 'Tagesziel erreicht!' : 'Dein Tagesziel', style: Theme.of(context).textTheme.titleMedium)),
                            TextButton.icon(onPressed: () => _editDailyGoal(progress.dailyGoal), icon: const Icon(Icons.edit_outlined), label: const Text('Ändern')),
                          ]),
                          Text('${progress.reviewsToday} von ${progress.dailyGoal} Karten heute bewertet'),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(value: ratio, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                          if (!reached) ...[
                            const SizedBox(height: 8),
                            Text('Noch ${progress.dailyGoal - progress.reviewsToday} ${progress.dailyGoal - progress.reviewsToday == 1 ? 'Karte' : 'Karten'} bis zum Ziel.', style: const TextStyle(color: vokabelMuted)),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
                if (constraints.maxWidth < 620) ...[
                  const Text('Deine Lernboxen', style: TextStyle(fontSize: 34, color: vokabelInk, fontWeight: FontWeight.w700, letterSpacing: -1)),
                  const SizedBox(height: 8),
                  const Text('Ein guter Moment, um ein paar Wörter zu lernen.', style: TextStyle(color: vokabelMuted, fontSize: 15)),
                  const SizedBox(height: 18),
                  Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _createSet, icon: const Icon(Icons.add_rounded), label: const Text('Lernbox erstellen'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))),
                ] else
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Deine Lernboxen', style: TextStyle(fontSize: 34, color: vokabelInk, fontWeight: FontWeight.w700, letterSpacing: -1)),
                      SizedBox(height: 8),
                      Text('Ein guter Moment, um ein paar Wörter zu lernen.', style: TextStyle(color: vokabelMuted, fontSize: 15)),
                    ])),
                    FilledButton.icon(onPressed: _createSet, icon: const Icon(Icons.add_rounded), label: const Text('Lernbox erstellen'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
                  ]),
                const SizedBox(height: 30),
                FutureBuilder<List<VocabularySet>>(
                  future: _sets,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator()));
                    if (snapshot.hasError) return EmptyPanel(title: 'Lernboxen konnten nicht geladen werden', subtitle: snapshot.error.toString(), action: TextButton(onPressed: _reload, child: const Text('Erneut versuchen')));
                    final sets = snapshot.data ?? [];
                    if (sets.isEmpty) return EmptyPanel(title: 'Deine erste Lernbox wartet', subtitle: 'Lege eine Liste an und sammle darin deine ersten Vokabeln.', action: FilledButton.icon(onPressed: _createSet, icon: const Icon(Icons.add_rounded), label: const Text('Lernbox erstellen')));
                    final contentWidth = (constraints.maxWidth - 2 * horizontal).clamp(0.0, 1120.0).toDouble();
                    final columns = contentWidth > 980 ? 3 : contentWidth > 620 ? 2 : 1;
                    final cardWidth = (contentWidth - (columns - 1) * 16) / columns;
                    return Wrap(spacing: 16, runSpacing: 16, children: sets.map((set) => SizedBox(width: cardWidth, child: SetCard(set: set, onRename: () => _renameSet(set), onTap: () async {
                      await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => SetScreen(api: widget.api, vocabularySet: set)));
                      _reload();
                    }))).toList());
                  },
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}

