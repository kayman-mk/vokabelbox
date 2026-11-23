import 'package:flutter/material.dart';

import 'api.dart';

void main() {
  runApp(const VokabelBoxApp());
}

const _ink = Color(0xFF18233D);
const _muted = Color(0xFF68738A);
const _accent = Color(0xFF4D65E8);
const _paper = Color(0xFFF7F8FC);

class VokabelBoxApp extends StatefulWidget {
  const VokabelBoxApp({super.key});

  @override
  State<VokabelBoxApp> createState() => _VokabelBoxAppState();
}

class _VokabelBoxAppState extends State<VokabelBoxApp> {
  final _api = ApiClient();
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _connectionError;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      _user = await _api.currentUser();
    } catch (_) {
      _connectionError = 'Could not connect to VokabelBox. Check that Docker Compose is running.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _signedIn(Map<String, dynamic> user) => setState(() {
        _user = user;
        _connectionError = null;
      });

  Future<void> _signedOut() async {
    try {
      await _api.logout();
    } finally {
      if (mounted) setState(() => _user = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VokabelBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(seedColor: _accent, surface: _paper),
        fontFamily: 'Roboto',
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null
              ? LoginScreen(api: _api, onSignedIn: _signedIn, connectionError: _connectionError)
              : DashboardScreen(api: _api, user: _user!, onSignOut: _signedOut),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.api, required this.onSignedIn, this.connectionError, super.key});

  final ApiClient api;
  final ValueChanged<Map<String, dynamic>> onSignedIn;
  final String? connectionError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.onSignedIn(await widget.api.login(_username.text.trim(), _password.text));
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        return Row(children: [
          if (wide)
            Expanded(
              child: Container(
                color: _ink,
                padding: const EdgeInsets.all(56),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  _BrandMark(light: true),
                  SizedBox(height: 70),
                  Text('Kleine Schritte.\nWörter, die bleiben.', style: TextStyle(color: Colors.white, fontSize: 48, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -1.5)),
                  SizedBox(height: 20),
                  Text('Dein ruhiger Ort zum Lernen — auf jedem Gerät.', style: TextStyle(color: Color(0xFFC3CBE0), fontSize: 17)),
                ]),
              ),
            ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (!wide) const _BrandMark(),
                      if (!wide) const SizedBox(height: 56),
                      const Text('Willkommen zurück', style: TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 30, letterSpacing: -0.7)),
                      const SizedBox(height: 8),
                      const Text('Melde dich an und mach dort weiter, wo du aufgehört hast.', style: TextStyle(color: _muted, height: 1.5)),
                      const SizedBox(height: 32),
                      const _FieldLabel('Benutzername'),
                      const SizedBox(height: 8),
                      TextFormField(controller: _username, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Dein Benutzername'), validator: (value) => value == null || value.trim().isEmpty ? 'Bitte gib deinen Benutzernamen ein.' : null),
                      const SizedBox(height: 20),
                      const _FieldLabel('Passwort'),
                      const SizedBox(height: 8),
                      TextFormField(controller: _password, obscureText: true, onFieldSubmitted: (_) => _submit(), decoration: const InputDecoration(hintText: 'Dein Passwort'), validator: (value) => value == null || value.isEmpty ? 'Bitte gib dein Passwort ein.' : null),
                      if (_error != null || widget.connectionError != null) ...[
                        const SizedBox(height: 16),
                        Text(_error ?? widget.connectionError!, style: const TextStyle(color: Color(0xFFB42318))),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Anmelden', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 18),
                      const Text('Konten werden durch die Administration angelegt.', textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _sets = widget.api.getSets();
  }

  void _reload() => setState(() => _sets = widget.api.getSets());

  Future<void> _createSet() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Lernbox'),
        content: TextField(controller: controller, autofocus: true, maxLength: 120, decoration: const InputDecoration(hintText: 'z. B. Englisch – Unit 1'), onSubmitted: (_) => Navigator.pop(context, controller.text.trim())),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')), FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Erstellen'))],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await widget.api.createSet(name.trim());
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
        backgroundColor: _paper,
        title: const _BrandMark(),
        actions: [
          if (MediaQuery.sizeOf(context).width > 520) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Center(child: Text(username, style: const TextStyle(color: _muted)))),
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
                if (constraints.maxWidth < 620) ...[
                  const Text('Deine Lernboxen', style: TextStyle(fontSize: 34, color: _ink, fontWeight: FontWeight.w700, letterSpacing: -1)),
                  const SizedBox(height: 8),
                  const Text('Ein guter Moment, um ein paar Wörter zu lernen.', style: TextStyle(color: _muted, fontSize: 15)),
                  const SizedBox(height: 18),
                  Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _createSet, icon: const Icon(Icons.add_rounded), label: const Text('Lernbox erstellen'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))))),
                ] else
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Deine Lernboxen', style: TextStyle(fontSize: 34, color: _ink, fontWeight: FontWeight.w700, letterSpacing: -1)),
                      SizedBox(height: 8),
                      Text('Ein guter Moment, um ein paar Wörter zu lernen.', style: TextStyle(color: _muted, fontSize: 15)),
                    ])),
                    FilledButton.icon(onPressed: _createSet, icon: const Icon(Icons.add_rounded), label: const Text('Lernbox erstellen'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)))),
                  ]),
                const SizedBox(height: 30),
                FutureBuilder<List<VocabularySet>>(
                  future: _sets,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(60), child: CircularProgressIndicator()));
                    if (snapshot.hasError) return _EmptyPanel(title: 'Lernboxen konnten nicht geladen werden', subtitle: snapshot.error.toString(), action: TextButton(onPressed: _reload, child: const Text('Erneut versuchen')));
                    final sets = snapshot.data ?? [];
                    if (sets.isEmpty) return _EmptyPanel(title: 'Deine erste Lernbox wartet', subtitle: 'Lege eine Liste an und sammle darin deine ersten Vokabeln.', action: FilledButton.icon(onPressed: _createSet, icon: const Icon(Icons.add_rounded), label: const Text('Lernbox erstellen')));
                    final contentWidth = (constraints.maxWidth - 2 * horizontal).clamp(0.0, 1120.0).toDouble();
                    final columns = contentWidth > 980 ? 3 : contentWidth > 620 ? 2 : 1;
                    final cardWidth = (contentWidth - (columns - 1) * 16) / columns;
                    return Wrap(spacing: 16, runSpacing: 16, children: sets.map((set) => SizedBox(width: cardWidth, child: _SetCard(set: set, onTap: () async {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _paper, title: Text(widget.vocabularySet.name, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)), actions: [IconButton(tooltip: 'Vokabel hinzufügen', onPressed: _addWord, icon: const Icon(Icons.add_rounded)), const SizedBox(width: 8)]),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: FutureBuilder<List<Vocabulary>>(
        future: _words,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const CircularProgressIndicator();
          if (snapshot.hasError) return Text(snapshot.error.toString());
          final words = snapshot.data ?? [];
          if (words.isEmpty) return _EmptyPanel(title: 'Noch keine Vokabeln', subtitle: 'Füge ein Wortpaar hinzu, um deine Lernbox zu füllen.', action: FilledButton.icon(onPressed: _addWord, icon: const Icon(Icons.add_rounded), label: const Text('Vokabel hinzufügen')));
          return ListView.separated(padding: const EdgeInsets.all(24), itemCount: words.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) => _WordRow(word: words[index]));
        },
      ))),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.light = false});

  final bool light;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: light ? const Color(0xFF34456F) : const Color(0xFFE9ECFF), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.style_rounded, color: light ? Colors.white : _accent, size: 22)),
        const SizedBox(width: 11),
        Text('VokabelBox', style: TextStyle(color: light ? Colors.white : _ink, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4)),
      ]);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600, fontSize: 14));
}

class _SetCard extends StatelessWidget {
  const _SetCard({required this.set, required this.onTap});
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
            Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFF0F2FF), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.bookmark_outline_rounded, color: _accent)),
            const SizedBox(height: 18),
            Text(set.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 7),
            Text('${set.wordCount} Vokabeln', style: const TextStyle(color: _muted, fontSize: 14)),
            const SizedBox(height: 16),
            const Row(children: [Text('Lernbox öffnen', style: TextStyle(color: _accent, fontWeight: FontWeight.w600)), SizedBox(width: 6), Icon(Icons.arrow_forward_rounded, color: _accent, size: 17)]),
          ])),
        ),
      );
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.word});
  final Vocabulary word;

  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEAECF2))), child: Row(children: [Expanded(child: Text(word.prompt, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600))), const Icon(Icons.arrow_forward_rounded, color: Color(0xFFA2AAB9), size: 18), const SizedBox(width: 16), Expanded(child: Text(word.answer, style: const TextStyle(color: _muted)))]));
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.subtitle, required this.action});
  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFEAECF2)), borderRadius: BorderRadius.circular(20)), child: Column(children: [const Icon(Icons.auto_stories_outlined, size: 34, color: _accent), const SizedBox(height: 14), Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)), const SizedBox(height: 7), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: _muted)), const SizedBox(height: 20), action]));
}
