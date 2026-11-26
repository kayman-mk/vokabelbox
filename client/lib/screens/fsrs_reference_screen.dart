import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FsrsReferenceScreen extends StatelessWidget {
  const FsrsReferenceScreen({super.key});

  static final Uri _algorithmReference = Uri.parse(
    'https://github.com/open-spaced-repetition/awesome-fsrs/wiki/The-Algorithm',
  );
  static final Uri _projectReference = Uri.parse(
    'https://github.com/open-spaced-repetition/py-fsrs',
  );

  Future<void> _copyReference(BuildContext context, Uri uri) async {
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referenzlink kopiert.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('FSRS Referenz')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('Free Spaced Repetition Scheduler', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                const Text(
                  'FSRS plant Wiederholungen anhand der bisherigen Bewertungen und des geschätzten Gedächtniszustands einer Karte. '
                  'Es steht für Free Spaced Repetition Scheduler.',
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verwendung in VokabelBox', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        const Text('Algorithmusversion: FSRS-4.5'),
                        const Text('Parameter: veröffentlichte Standardwerte'),
                        const Text('Gewünschte Erinnerungsrate: 90 %'),
                        const Text('Bewertungen: Nochmal, Schwer, Gut und Einfach'),
                        const SizedBox(height: 12),
                        const Text(
                          'Der PHP-Scheduler in VokabelBox ist eine eigenständige Implementierung der veröffentlichten Formeln.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.menu_book_outlined),
                        title: const Text('FSRS-Algorithmus'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Formeln und Beschreibung des Scheduling-Modells'),
                            SelectableText(_algorithmReference.toString()),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: 'Referenzlink kopieren',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => _copyReference(context, _algorithmReference),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.code_rounded),
                        title: const Text('Open Spaced Repetition · Referenzprojekt'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('FSRS-Referenzimplementierung und Projektinformationen'),
                            SelectableText(_projectReference.toString()),
                          ],
                        ),
                        trailing: IconButton(
                          tooltip: 'Referenzlink kopieren',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () => _copyReference(context, _projectReference),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
