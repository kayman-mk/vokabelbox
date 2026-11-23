import 'package:flutter/material.dart';

import '../api.dart';
import '../app_theme.dart';
import '../widgets/common_widgets.dart';

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
                color: vokabelInk,
                padding: const EdgeInsets.all(56),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  BrandMark(light: true),
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
                      if (!wide) const BrandMark(),
                      if (!wide) const SizedBox(height: 56),
                      const Text('Willkommen zurück', style: TextStyle(color: vokabelInk, fontWeight: FontWeight.w700, fontSize: 30, letterSpacing: -0.7)),
                      const SizedBox(height: 8),
                      const Text('Melde dich an und mach dort weiter, wo du aufgehört hast.', style: TextStyle(color: vokabelMuted, height: 1.5)),
                      const SizedBox(height: 32),
                      const FieldLabel('Benutzername'),
                      const SizedBox(height: 8),
                      TextFormField(controller: _username, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Dein Benutzername'), validator: (value) => value == null || value.trim().isEmpty ? 'Bitte gib deinen Benutzernamen ein.' : null),
                      const SizedBox(height: 20),
                      const FieldLabel('Passwort'),
                      const SizedBox(height: 8),
                      TextFormField(controller: _password, obscureText: true, onFieldSubmitted: (_) => _submit(), decoration: const InputDecoration(hintText: 'Dein Passwort'), validator: (value) => value == null || value.isEmpty ? 'Bitte gib dein Passwort ein.' : null),
                      if (_error != null || widget.connectionError != null) ...[
                        const SizedBox(height: 16),
                        Text(_error ?? widget.connectionError!, style: const TextStyle(color: Color(0xFFB42318))),
                      ],
                      const SizedBox(height: 28),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(backgroundColor: vokabelInk, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Anmelden', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 18),
                      const Text('Konten werden durch die Administration angelegt.', textAlign: TextAlign.center, style: TextStyle(color: vokabelMuted, fontSize: 13)),
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

