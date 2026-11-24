import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/widgets/fila_adaptable.dart';

/// La fila de un cliente: nombre, teléfono, estado y botón, como en la
/// pantalla Clientes del Administrador.
Widget _lista(double ancho) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: ancho,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTileAdaptable(
                    leading: const CircleAvatar(child: Text('A')),
                    title: const Text('Ana Vargas Céspedes', key: Key('nombre')),
                    subtitle: const Text('+59170011223'),
                    onTap: () {},
                    trailing: Wrap(
                      key: const Key('acciones'),
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Chip(label: Text('Bloqueado')),
                        TextButton(onPressed: () {}, child: const Text('Desbloquear')),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('en un celular de 360 px el estado y el botón bajan a otra línea', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_lista(360));
    expect(tester.takeException(), isNull);

    final nombre = tester.getRect(find.byKey(const Key('nombre')));
    final acciones = tester.getRect(find.byKey(const Key('acciones')));
    // Las acciones quedan debajo del nombre, no a su lado.
    expect(acciones.top, greaterThanOrEqualTo(nombre.bottom));
    // El nombre usa casi todo el ancho de la tarjeta: no se parte letra por letra.
    expect(nombre.width, greaterThan(200));
    expect(find.text('Desbloquear'), findsOneWidget);
  });

  testWidgets('en una pantalla ancha todo sigue en una sola fila', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_lista(900));
    expect(tester.takeException(), isNull);

    final nombre = tester.getRect(find.byKey(const Key('nombre')));
    final acciones = tester.getRect(find.byKey(const Key('acciones')));
    expect(acciones.left, greaterThan(nombre.left));
    expect(acciones.top, lessThan(nombre.bottom));
  });
}
