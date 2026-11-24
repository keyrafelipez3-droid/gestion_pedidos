import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/models/usuario_model.dart';
import 'package:gestion_pedidos/utils/reporte_entregas.dart';

PedidoModel _p(String id, String estado, double total, {double propina = 0, int hora = 12}) => PedidoModel(
      id: id,
      idCliente: 'c1',
      idNegocio: 'n1',
      idSucursal: 's1',
      modalidad: PedidoModalidad.delivery,
      metodoPago: 'Efectivo',
      estado: estado,
      total: total,
      propina: propina,
      fechaCreacion: DateTime(2026, 11, 23, hora, 5),
      nombreCliente: 'Ana <Pérez>',
      nombreRepartidor: 'Luis',
      zonaEntrega: 'Centro',
      lineas: const [
        DetallePedidoModel(
            id: 'l1', idProducto: 'x', nombreProducto: 'Pollo', precioUnitario: 35, cantidad: 2, subtotal: 70),
      ],
    );

ReporteEntregas _reporte(String rol) => ReporteEntregas(
      negocio: 'Pollos Rosa',
      periodo: 'Últimos 7 días',
      persona: 'Juan Mamani',
      rol: rol,
      alcance: alcanceDelRol(rol),
      generado: DateTime(2026, 11, 24, 9, 30),
      nombresSucursal: const {'s1': 'Centro'},
      pedidos: [
        _p('ped0002', PedidoEstado.entregado, 50, propina: 5, hora: 14),
        _p('ped0001', PedidoEstado.entregado, 70, hora: 10),
        _p('ped0003', PedidoEstado.cancelado, 99),
      ],
    );

void main() {
  test('solo entran los pedidos entregados, del más antiguo al más nuevo', () {
    final r = _reporte(Rol.cajero);
    expect(r.pedidos.map((p) => p.id), ['ped0001', 'ped0002']);
    expect(r.filas.first[3], '#ped000');
    expect(r.datosCabecera, contains('Total de entregas: 2'));
  });

  test('cada rol ve sus columnas: la cocina no ve montos, el repartidor ve sus propinas', () {
    final caja = _reporte(Rol.cajero);
    expect(caja.columnas, contains('Repartidor'));
    expect(caja.totales!.last, '120.00');

    final cocina = _reporte(Rol.cocina);
    expect(cocina.columnas.last, 'Productos');
    expect(cocina.filas.first.last, '2 × Pollo');
    expect(cocina.totales, isNull);
    expect(cocina.columnas.any((c) => c.startsWith('Total')), isFalse);

    final repa = _reporte(Rol.repartidor);
    expect(repa.columnas.last, startsWith('Propina'));
    expect(repa.totales!.last, '5.00');
    expect(repa.totales![repa.totales!.length - 2], '125.00');
    for (final f in [...caja.filas, ...cocina.filas, ...repa.filas]) {
      expect(f.length, anyOf(caja.columnas.length, cocina.columnas.length, repa.columnas.length));
    }
  });

  test('el Word es un .docx válido con la tabla y el espacio para firmar', () {
    final bytes = docxEntregas(_reporte(Rol.administrador));
    final zip = ZipDecoder().decodeBytes(bytes);
    final nombres = zip.files.map((f) => f.name).toSet();
    expect(nombres, containsAll(['[Content_Types].xml', '_rels/.rels', 'word/document.xml']));
    final xml = utf8.decode(zip.findFile('word/document.xml')!.content as List<int>);
    expect(xml, contains('REPORTE DE ENTREGAS REALIZADAS'));
    expect(xml, contains('Ana &lt;Pérez&gt;'));
    expect(xml, contains('Recibido / revisado por'));
    expect(xml, contains('w:orient="landscape"'));
  });

  test('la página para imprimir escapa el texto y trae las firmas', () {
    final html = htmlEntregas(_reporte(Rol.repartidor));
    expect(html, contains('Ana &lt;Pérez&gt;'));
    expect(html, isNot(contains('<Pérez>')));
    expect(html, contains('Entregado por'));
    expect(html, contains('Juan Mamani (Repartidor)'));
  });
}
