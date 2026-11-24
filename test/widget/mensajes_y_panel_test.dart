import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/widgets/mensajero_nami.dart';
import 'package:gestion_pedidos/widgets/panel_lateral.dart';
import 'package:gestion_pedidos/widgets/selector_imagen.dart';

/// La app como en main.dart: MensajeroNami y AnfitrionPanelLateral en el
/// `builder`, alrededor del Navigator.
Widget _app({required Widget home}) => MaterialApp(
      builder: (context, child) => MensajeroNami(
        child: AnfitrionPanelLateral(child: child ?? const SizedBox.shrink()),
      ),
      home: home,
    );

Future<void> _tamano(WidgetTester tester, Size s) async {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Pantalla extends StatelessWidget {
  const _Pantalla();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicio')),
      body: Builder(
        builder: (context) => Column(
          children: [
            Text('ancho ${MediaQuery.sizeOf(context).width.round()}', key: const Key('ancho')),
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Guardado'),
                  action: SnackBarAction(label: 'Deshacer', onPressed: () {}),
                ),
              ),
              child: const Text('mensaje'),
            ),
            ElevatedButton(
              onPressed: () => abrirPanelLateral(
                context,
                id: 'prueba',
                constructor: (ctx, cerrar) => Column(
                  children: [
                    EncabezadoPanelLateral(titulo: 'Avisos', icono: Icons.notifications, cerrar: cerrar),
                    const Text('Pedido listo'),
                  ],
                ),
              ),
              child: const Text('campana'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  for (final (nombre, tamano) in const [('celular 360', Size(360, 740)), ('computadora', Size(1366, 800))]) {
    testWidgets('$nombre: el mensaje aparece ARRIBA, no abajo tapando el contenido', (tester) async {
      await _tamano(tester, tamano);
      await tester.pumpWidget(_app(home: const _Pantalla()));
      await tester.tap(find.text('mensaje'));
      await tester.pumpAndSettle();

      final mensaje = find.text('Guardado');
      expect(mensaje, findsOneWidget);
      expect(tester.getTopLeft(mensaje).dy, lessThan(tamano.height / 3));
      if (tamano.width > 720) {
        // En la computadora va a la derecha.
        expect(tester.getTopLeft(mensaje).dx, greaterThan(tamano.width / 2));
      }

      // No tapa nada: la barra superior y los botones quedan DEBAJO del
      // mensaje, no detrás.
      final tarjeta = tester.getRect(find.ancestor(of: mensaje, matching: find.byType(Material)).first);
      for (final f in [find.byType(AppBar), find.text('mensaje'), find.text('campana')]) {
        expect(tester.getRect(f).overlaps(tarjeta), isFalse, reason: '$f queda tapado');
      }
      // Letras negras sobre fondo blanco.
      final estilo = tester.widget<DefaultTextStyle>(
        find.ancestor(of: mensaje, matching: find.byType(DefaultTextStyle)).first,
      );
      expect(estilo.style.color, const Color(0xFF111111));

      // La X lo cierra.
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Guardado'), findsNothing);
      // Y todo vuelve a su lugar.
      expect(tester.getTopLeft(find.byType(AppBar)).dy, 0);
    });
  }

  testWidgets('el botón del mensaje hace su acción y lo cierra', (tester) async {
    await _tamano(tester, const Size(360, 740));
    var deshecho = false;
    await tester.pumpWidget(_app(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Producto borrado'),
                action: SnackBarAction(label: 'Deshacer', onPressed: () => deshecho = true),
              ),
            ),
            child: const Text('borrar'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('borrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    expect(deshecho, isTrue);
    expect(find.text('Producto borrado'), findsNothing);
  });

  testWidgets('el mensaje se va solo cuando pasa su tiempo', (tester) async {
    await _tamano(tester, const Size(360, 740));
    await tester.pumpWidget(_app(home: const _Pantalla()));
    await tester.tap(find.text('mensaje'));
    await tester.pumpAndSettle();
    expect(find.text('Guardado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Guardado'), findsNothing);
  });

  testWidgets('computadora: la campanita abre el panel a la derecha y el contenido se corre a la izquierda',
      (tester) async {
    await _tamano(tester, const Size(1366, 800));
    await tester.pumpWidget(_app(home: const _Pantalla()));
    expect(find.text('ancho 1366'), findsOneWidget);

    await tester.tap(find.text('campana'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido listo'), findsOneWidget);
    // El panel queda pegado a la derecha...
    expect(tester.getTopLeft(find.text('Pedido listo')).dx, greaterThan(1366 - anchoPanelLateral - 1));
    // ...y la pantalla de atrás ahora es más angosta (no queda tapada).
    expect(find.text('ancho ${(1366 - anchoPanelLateral).round()}'), findsOneWidget);
    expect(tester.getTopRight(find.text('Inicio')).dx, lessThan(1366 - anchoPanelLateral));

    // La X lo cierra y el contenido vuelve a todo el ancho.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Pedido listo'), findsNothing);
    expect(find.text('ancho 1366'), findsOneWidget);
  });

  testWidgets('celular 360: el panel se desliza desde la derecha y se cierra tocando afuera', (tester) async {
    await _tamano(tester, const Size(360, 740));
    await tester.pumpWidget(_app(home: const _Pantalla()));
    await tester.tap(find.text('campana'));
    await tester.pumpAndSettle();
    expect(find.text('Pedido listo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(const Offset(5, 400));
    await tester.pumpAndSettle();
    expect(find.text('Pedido listo'), findsNothing);
  });

  testWidgets('celular 360: el selector de foto pone el link debajo, a todo el ancho, sin desbordes',
      (tester) async {
    await _tamano(tester, const Size(360, 740));
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectorImagen(etiqueta: 'Foto de perfil', controller: ctrl, rutaStorage: 'x/y'),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final campo = tester.getRect(find.byType(TextField));
    expect(campo.width, greaterThan(300));
  });
}
