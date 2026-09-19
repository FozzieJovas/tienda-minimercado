import 'package:flutter_test/flutter_test.dart';

import 'package:pos_app/main.dart';

void main() {
  testWidgets('La app arranca y muestra el punto de venta', (WidgetTester tester) async {
    await tester.pumpWidget(const TiendaPosApp());
    await tester.pump();

    expect(find.text('Punto de venta'), findsOneWidget);
  });
}
