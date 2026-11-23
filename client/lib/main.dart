import 'package:flutter/material.dart';

import 'api.dart';
import 'app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const VokabelBoxApp());
}


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
        scaffoldBackgroundColor: vokabelPaper,
        colorScheme: ColorScheme.fromSeed(seedColor: vokabelAccent, surface: vokabelPaper),
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
