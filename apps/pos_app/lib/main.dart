import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'models/cash_session.dart';
import 'screens/login_screen.dart';
import 'screens/open_session_screen.dart';
import 'screens/pos_screen.dart';
import 'services/api_client.dart';
import 'services/session_service.dart';
import 'services/settings_service.dart';

void main() {
  runApp(const TiendaPosApp());
}

class TiendaPosApp extends StatelessWidget {
  const TiendaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tienda POS',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const _AppRoot(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  final _session = SessionService();
  final _api = ApiClient(SettingsService());

  bool _checking = true;
  AppUser? _user;
  CashSession? _cashSession;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = await _session.getCurrentUser();
    CashSession? cashSession;
    if (user != null) {
      try {
        cashSession = await _api.fetchCurrentSession();
      } catch (_) {
        // sin conexión al iniciar; se reintenta desde la pantalla correspondiente
      }
    }
    setState(() {
      _user = user;
      _cashSession = cashSession;
      _checking = false;
    });
  }

  void _onLoggedOut() {
    setState(() {
      _user = null;
      _cashSession = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = _user;
    if (user == null) {
      return LoginScreen(onLoggedIn: (u) => setState(() => _user = u));
    }

    final cashSession = _cashSession;
    if (cashSession == null) {
      return OpenSessionScreen(
        user: user,
        onOpened: (session) => setState(() => _cashSession = session),
      );
    }

    return PosScreen(
      user: user,
      sessionId: cashSession.id,
      onLoggedOut: _onLoggedOut,
      onSessionClosed: () => setState(() => _cashSession = null),
    );
  }
}
