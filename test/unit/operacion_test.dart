import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/models/sucursal_model.dart';
import 'package:gestion_pedidos/screens/cajero/cajero_rendicion_screen.dart';
import 'package:gestion_pedidos/screens/cocina/cocina_tablero_screen.dart';
import 'package:gestion_pedidos/utils/comanda_cocina.dart';

PedidoModel _delivery(
  String id, {
  double total = 50,
  double envio = 0,
  double propina = 0,
  String pago = MetodoPago.efectivo,
  String? repartidor = 'r1',
  bool cobrado = false,
}) =>
    PedidoModel(
      id: id,
      idCliente: 'c',
      idNegocio: 'n',
      idSucursal: 's',
      modalidad: PedidoModalidad.delivery,
      metodoPago: pago,
      estado: PedidoEstado.entregado,
      total: total,
      costoEnvio: envio,
      propina: propina,
      idRepartidor: repartidor,
      nombreRepartidor: repartidor == null ? null : 'Juan',
      cobrado: cobrado,
    );

void main() {
  group('Costo de envío', () {
    test('el cliente paga productos + envío + propina; la caja recibe sin la propina', () {
      final p = _delivery('aaaaaa111111', total: 40, envio: 5, propina: 3);
      expect(p.totalACobrar, 48);
      expect(p.montoNegocio, 45);
    });

    test('las zonas se ordenan por costo', () {
      const s = SucursalModel(id: 's', nombre: 'Sur', zonasDelivery: {'Norte': 8, 'Centro': 5, 'Este': 5});
      expect(s.cobraEnvio, isTrue);
      expect(s.zonasOrdenadas.map((e) => e.key), ['Centro', 'Este', 'Norte']);
      expect(const SucursalModel(id: 'x', nombre: 'X').cobraEnvio, isFalse);
    });
  });

  group('Rendición de repartidores', () {
    test('agrupa por repartidor y separa efectivo, QR y propinas', () {
      final grupos = RendicionRepartidor.agrupar([
        _delivery('p1aaaaaaaaaa', total: 40, envio: 5, propina: 2),
        _delivery('p2aaaaaaaaaa', total: 30, pago: MetodoPago.qr),
        _delivery('p3aaaaaaaaaa', cobrado: true), // ya pasó por caja
        _delivery('p4aaaaaaaaaa', repartidor: null), // sin repartidor
      ]);
      expect(grupos, hasLength(1));
      final r = grupos.single;
      expect(r.pedidos, hasLength(2));
      expect(r.efectivo, 45);
      expect(r.digital, 30);
      expect(r.propinas, 2);
    });
  });

  test('tiempo de espera en cocina: verde, amarillo y rojo', () {
    expect(colorEspera(3), const Color(0xFF2E7D32));
    expect(colorEspera(12), const Color(0xFFF9A825));
    expect(colorEspera(25), const Color(0xFFC62828));
  });

  test('la comanda de cocina no lleva precios y resalta las alergias', () {
    final pedido = PedidoModel(
      id: 'abcdef123456',
      idCliente: 'c',
      idNegocio: 'n',
      idSucursal: 's',
      modalidad: PedidoModalidad.recoger,
      metodoPago: MetodoPago.efectivo,
      total: 70,
      notas: 'Sin <sal>',
      alergias: const ['mani'],
      fechaCreacion: DateTime(2026, 10, 24, 12, 30),
    );
    const detalle = [
      DetallePedidoModel(
        id: 'd1',
        idProducto: 'x',
        nombreProducto: 'Pollo broaster',
        precioUnitario: 35,
        cantidad: 2,
        subtotal: 70,
      ),
    ];
    final html = htmlComanda(pedido, detalle);
    expect(html, contains('COMANDA #ABCDEF'));
    expect(html, contains('2×</span> Pollo broaster'));
    expect(html, contains('ALERGIA: MANÍ'));
    expect(html, contains('Sin &lt;sal&gt;'));
    expect(html, isNot(contains('Bs')));
  });
}
