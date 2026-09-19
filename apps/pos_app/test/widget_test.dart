import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pos_app/main.dart';

void main() {
  testWidgets('La app arranca mostrando la pantalla de login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const TiendaPosApp());
    // Deja resolver el Future de SharedPreferences sin esperar a que se
    // "asiente" (pumpAndSettle nunca termina mientras se ve el spinner inicial,
    // que tiene una animación continua).
    await tester.pump();
    await tester.pump();

    expect(find.text('Ingresar'), findsOneWidget);
  });
}
