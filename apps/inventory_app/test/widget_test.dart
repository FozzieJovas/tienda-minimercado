import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_app/main.dart';

void main() {
  testWidgets('La app arranca mostrando la pantalla de login', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const InventoryApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Ingresar'), findsOneWidget);
  });
}
