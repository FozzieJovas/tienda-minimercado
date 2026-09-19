import 'package:flutter/material.dart';
import 'screens/pos_screen.dart';

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
      home: const PosScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
