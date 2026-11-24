import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/negocio_model.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/screens/cliente/inicio_cliente.dart';
import 'package:gestion_pedidos/services/app_theme_controller.dart';

/// Pedido de UI/UX: un cliente puede tener varios restaurantes, y en su
/// inicio siempre ve claramente "Añadir restaurante" (por código o desde
/// la lista con logos), sin perder los que ya tiene.
Widget _inicio(List<NegocioModel> restaurantes, {double ancho = 390}) {
  AppThemeController.usarFuentesDeGoogle = false;
  return MaterialApp(
    theme: AppThemeController.instancia.buildTheme(Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(size: Size(ancho, 2400)),
      child: Scaffold(
        body: InicioCliente(
          nombre: 'Ana',
          restaurantes: restaurantes,
          pedidos: const Stream<List<PedidoModel>>.empty(),
          onIngresarCodigo: () {},
          onMiCuenta: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('con un restaurante se ve el botón "Añadir restaurante"', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_inicio([NegocioModel(idNegocio: 'n1', nombre: 'Pollos Nami')]));
    await tester.pump();
    expect(find.text('Ver el menú y pedir'), findsOneWidget);
    expect(find.text('Añadir restaurante'), findsOneWidget);
  });

  testWidgets('con varios restaurantes se ven todos y también "Añadir restaurante"', (tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_inicio([
      NegocioModel(idNegocio: 'n1', nombre: 'Pollos Nami'),
      NegocioModel(idNegocio: 'n2', nombre: 'Salteñas Sur'),
    ]));
    await tester.pump();
    expect(find.text('Pollos Nami'), findsOneWidget);
    expect(find.text('Salteñas Sur'), findsOneWidget);
    expect(find.text('Añadir restaurante'), findsOneWidget);
  });
}
