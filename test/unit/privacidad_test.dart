import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';

/// La dirección, el teléfono y la factura del cliente se guardan aparte
/// (pedidos/{id}/privado/contacto), no dentro del pedido que ve la Cocina.
void main() {
  const pedido = PedidoModel(
    id: 'p1',
    idCliente: 'c1',
    idNegocio: 'n1',
    idSucursal: 's1',
    modalidad: PedidoModalidad.delivery,
    metodoPago: MetodoPago.efectivo,
    direccionEntrega: {'direccion': 'Calle 1'},
    telefonoCliente: '70000000',
    facturaNit: '1234567',
    facturaRazonSocial: 'Ana SRL',
    nombreCliente: 'Ana',
  );

  test('la dirección, el teléfono y la factura no van dentro del pedido', () {
    final m = pedido.toMap();
    for (final campo in ['direccionEntrega', 'telefonoCliente', 'facturaNit', 'facturaRazonSocial']) {
      expect(m.containsKey(campo), isFalse, reason: campo);
    }
    expect(m['conFactura'], isTrue);
  });

  test('van juntos en privado/contacto', () {
    expect(pedido.contactoMap(), {
      'direccionEntrega': {'direccion': 'Calle 1'},
      'telefonoCliente': '70000000',
      'facturaNit': '1234567',
      'facturaRazonSocial': 'Ana SRL',
    });
  });

  test('un pedido sin delivery ni factura no tiene datos de contacto', () {
    const simple = PedidoModel(
      id: 'p2',
      idCliente: 'c1',
      idNegocio: 'n1',
      idSucursal: 's1',
      modalidad: PedidoModalidad.recoger,
      metodoPago: MetodoPago.efectivo,
    );
    expect(simple.contactoMap(), isEmpty);
    expect(simple.toMap().containsKey('conFactura'), isFalse);
  });
}
