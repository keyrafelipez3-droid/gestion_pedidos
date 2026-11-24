import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/widgets/campo_desplegable.dart';

void main() {
  Widget app({required ValueChanged<String?> alCambiar}) => MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                const TextField(decoration: InputDecoration(labelText: 'Sucursal')),
                SizedBox(
                  width: 300,
                  child: CampoDesplegable<String?>(
                    initialValue: null,
                    decoration: const InputDecoration(labelText: 'Modalidad'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Todas')),
                      DropdownMenuItem(value: 'mesa', child: Text('Mesa')),
                      DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                    ],
                    onChanged: alCambiar,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  testWidgets('el menú se abre debajo del campo, sin taparlo', (tester) async {
    await tester.pumpWidget(app(alCambiar: (_) {}));
    final campo = tester.getRect(find.byType(CampoDesplegable<String?>));

    await tester.tap(find.byType(CampoDesplegable<String?>));
    await tester.pumpAndSettle();

    final primera = tester.getRect(find.widgetWithText(MenuItemButton, 'Todas'));
    expect(primera.top, greaterThanOrEqualTo(campo.bottom));
    expect(primera.width, closeTo(campo.width, 1));
  });

  testWidgets('elegir una opción la muestra en el campo y avisa al padre', (tester) async {
    String? elegido;
    await tester.pumpWidget(app(alCambiar: (v) => elegido = v));

    await tester.tap(find.byType(CampoDesplegable<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, 'Delivery'));
    await tester.pumpAndSettle();

    expect(elegido, 'delivery');
    expect(find.byType(MenuItemButton), findsNothing);
    expect(
      find.descendant(of: find.byType(CampoDesplegable<String?>), matching: find.text('Delivery')),
      findsOneWidget,
    );
  });
}
