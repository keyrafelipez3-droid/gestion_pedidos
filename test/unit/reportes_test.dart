import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/utils/reporte_csv.dart';
import 'package:gestion_pedidos/utils/reporte_excel.dart';

PedidoModel _p(String id, double total, {double descuento = 0, double propina = 0, String pago = MetodoPago.efectivo}) =>
    PedidoModel(
      id: id,
      idCliente: 'c',
      idNegocio: 'n',
      idSucursal: 's1',
      modalidad: PedidoModalidad.recoger,
      metodoPago: pago,
      estado: PedidoEstado.entregado,
      total: total,
      descuento: descuento,
      propina: propina,
      fechaCreacion: DateTime(2026, 10, 22, 13, 5),
    );

void main() {
  final pedidos = [
    _p('pedidoA00000', 35),
    _p('pedidoB00000', 63, descuento: 7, pago: MetodoPago.qr),
    _p('pedidoC00000', 20, propina: 5),
  ];

  group('Excel (.xlsx)', () {
    final bytes = excelVentas(pedidos, nombresSucursal: const {'s1': 'Centro & Norte'}, periodo: 'Hoy');
    final zip = ZipDecoder().decodeBytes(bytes);
    String archivo(String nombre) => utf8.decode(zip.findFile(nombre)!.content as List<int>);

    test('tiene la estructura de un libro de Excel con 2 hojas', () {
      for (final f in [
        '[Content_Types].xml',
        'xl/workbook.xml',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
        'xl/worksheets/sheet2.xml',
      ]) {
        expect(zip.findFile(f), isNotNull, reason: f);
      }
      expect(archivo('xl/workbook.xml'), contains('name="Resumen"'));
    });

    test('las ventas van como números y con fila de TOTAL con fórmulas', () {
      final hoja = archivo('xl/worksheets/sheet1.xml');
      expect(hoja, contains('<f>SUM(J5:J7)</f><v>118</v>'));
      expect(hoja, contains('<f>SUM(I5:I7)</f><v>7</v>'));
      expect(hoja, contains('<f>SUM(K5:K7)</f><v>5</v>'));
      // Los textos se escapan (el "&" no rompe el archivo).
      expect(hoja, contains('Centro &amp; Norte'));
      expect(hoja, contains('autoFilter'));
    });
  });

  test('CSV con separador ; y fila de total', () {
    final csv = csvVentas(pedidos);
    final filas = csv.split('\r\n');
    expect(filas.first, startsWith('﻿Fecha;Hora;Pedido'));
    expect(filas.length, 5); // encabezado + 3 pedidos + total
    expect(filas.last, contains('118,00'));
  });
}
