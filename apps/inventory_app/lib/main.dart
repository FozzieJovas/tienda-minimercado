import 'package:flutter/material.dart';
import 'models/app_user.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/session_service.dart';

void main() {
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventario Tienda',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
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
  bool _checking = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _session.getCurrentUser().then((user) {
      setState(() {
        _user = user;
        _checking = false;
      });
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
    return HomeScreen(user: user, onLoggedOut: () => setState(() => _user = null));
  }
}
