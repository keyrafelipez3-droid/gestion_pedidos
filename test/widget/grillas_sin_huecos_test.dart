import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/screens/admin/dashboard/dashboard_comun.dart';

Widget _caja(int i) => SizedBox(key: Key('c$i'), height: 60, child: const Placeholder());

Future<void> _ver(WidgetTester tester, double ancho, Widget grilla) async {
  tester.view.physicalSize = Size(ancho, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: grilla))));
}

void main() {
  testWidgets('KPI: con 5 tarjetas en la computadora, la última fila (2) llena todo el ancho', (tester) async {
    await _ver(tester, 1000, GrillaKpi(children: [for (var i = 0; i < 5; i++) _caja(i)]));
    final a = tester.getRect(find.byKey(const Key('c3')));
    final b = tester.getRect(find.byKey(const Key('c4')));
    expect(a.left, 0);
    expect(b.right, 1000);
    expect(tester.takeException(), isNull);
  });

  testWidgets('KPI: en un celular de 360 px van una debajo de otra, a todo el ancho', (tester) async {
    await _ver(tester, 360, GrillaKpi(children: [for (var i = 0; i < 3; i++) _caja(i)]));
    expect(tester.getSize(find.byKey(const Key('c2'))).width, 360);
  });

  testWidgets('Paneles: si son impares, el último ocupa todo el ancho', (tester) async {
    await _ver(tester, 1200, GrillaDashboard(children: [for (var i = 0; i < 3; i++) _caja(i)]));
    expect(tester.getSize(find.byKey(const Key('c2'))).width, 1200);
    expect(tester.getSize(find.byKey(const Key('c0'))).width, lessThan(700));
  });
}
