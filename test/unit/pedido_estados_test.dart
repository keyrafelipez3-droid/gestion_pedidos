import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/carrito_models.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';

/// Reglas de negocio de los estados del pedido: qué cambios se permiten.
void main() {
  group('PedidoEstado.puedePasar', () {
    test('flujo normal de cocina', () {
      expect(PedidoEstado.puedePasar(PedidoEstado.pendiente, PedidoEstado.enPreparacion), isTrue);
      expect(PedidoEstado.puedePasar(PedidoEstado.enPreparacion, PedidoEstado.listo), isTrue);
      expect(PedidoEstado.puedePasar(PedidoEstado.listo, PedidoEstado.entregado), isTrue);
    });

    test('flujo de delivery', () {
      expect(PedidoEstado.puedePasar(PedidoEstado.listo, PedidoEstado.enCamino), isTrue);
      expect(PedidoEstado.puedePasar(PedidoEstado.enCamino, PedidoEstado.llego), isTrue);
      expect(PedidoEstado.puedePasar(PedidoEstado.llego, PedidoEstado.entregado), isTrue);
    });

    test('no se salta pasos ni se vuelve atrás', () {
      expect(PedidoEstado.puedePasar(PedidoEstado.pendiente, PedidoEstado.listo), isFalse);
      expect(PedidoEstado.puedePasar(PedidoEstado.pendiente, PedidoEstado.entregado), isFalse);
      expect(PedidoEstado.puedePasar(PedidoEstado.listo, PedidoEstado.pendiente), isFalse);
      expect(PedidoEstado.puedePasar(PedidoEstado.enPreparacion, PedidoEstado.pendiente), isFalse);
    });

    test('un pedido terminado ya no cambia', () {
      for (final destino in PedidoEstado.todos) {
        expect(PedidoEstado.puedePasar(PedidoEstado.entregado, destino), isFalse);
        expect(PedidoEstado.puedePasar(PedidoEstado.cancelado, destino), isFalse);
      }
    });

    test('se puede cancelar en cualquier momento antes de entregar', () {
      for (final origen in [
        PedidoEstado.pendiente,
        PedidoEstado.enPreparacion,
        PedidoEstado.listo,
        PedidoEstado.enCamino,
        PedidoEstado.llego,
      ]) {
        expect(PedidoEstado.puedePasar(origen, PedidoEstado.cancelado), isTrue, reason: origen);
      }
    });
  });

  group('PedidoModel', () {
    PedidoModel pedido({
      double total = 90,
      double descuento = 10,
      double propina = 5,
      DateTime? programadoPara,
      List<String> alergias = const [],
    }) =>
        PedidoModel(
          id: 'abcdef123456',
          idCliente: 'c1',
          idNegocio: 'n1',
          idSucursal: 's1',
          modalidad: PedidoModalidad.delivery,
          metodoPago: MetodoPago.efectivo,
          total: total,
          descuento: descuento,
          propina: propina,
          programadoPara: programadoPara,
          alergias: alergias,
        );

    test('el total no incluye la propina, pero el cobro sí', () {
      final p = pedido();
      expect(p.subtotalProductos, 100);
      expect(p.totalACobrar, 95);
    });

    test('pedido programado para más tarde', () {
      expect(pedido(programadoPara: DateTime.now().add(const Duration(hours: 2))).esParaMasTarde, isTrue);
      expect(pedido(programadoPara: DateTime.now().add(const Duration(minutes: 20))).esParaMasTarde, isFalse);
      expect(pedido().esParaMasTarde, isFalse);
    });

    test('toMap guarda alergias, idioma, descuento y propina', () {
      final m = pedido(alergias: const ['mani']).toMap();
      expect(m['alergias'], ['mani']);
      expect(m['idiomaCliente'], 'es');
      expect(m['descuento'], 10);
      expect(m['propina'], 5);
      expect(m['estado'], PedidoEstado.pendiente);
      // Los datos del repartidor nunca los escribe el cliente.
      expect(m.containsKey('idRepartidor'), isFalse);
    });

    test('las líneas van dentro del pedido y se leen de vuelta', () {
      const lineas = [
        DetallePedidoModel(
            id: '', idProducto: 'p1', nombreProducto: 'Pollo', precioUnitario: 35, cantidad: 2, subtotal: 70),
        DetallePedidoModel(
            id: '', idProducto: 'p2', nombreProducto: 'Soda', precioUnitario: 8, cantidad: 1, subtotal: 8),
      ];
      final campos = DetallePedidoModel.camposDeLineas(lineas);
      expect(campos['lineasIds'], ['p1', 'p2']);
      expect(campos['lineasCant'], [2, 1]);
      expect(campos['precios'], {'p1': 35, 'p2': 8});
      final leidas = DetallePedidoModel.desdePedido(campos);
      expect(leidas.length, 2);
      expect(leidas.first.subtotal, 70);
      expect(leidas.last.nombreProducto, 'Soda');
      expect(DetallePedidoModel.desdePedido(const {}), isEmpty);
    });

    test('los extras van como líneas propias y se juntan al leerlas', () {
      const lineas = [
        DetallePedidoModel(
          id: '',
          idProducto: 'p1',
          nombreProducto: 'Pollo',
          precioUnitario: 35,
          cantidad: 2,
          variantes: [OpcionSeleccionada(id: 'v1', nombre: 'Grande', precio: 5)],
          complementos: [OpcionSeleccionada(id: 'c1', nombre: 'Queso', precio: 3)],
          subtotal: 86,
        ),
        DetallePedidoModel(
            id: '', idProducto: 'p2', nombreProducto: 'Soda', precioUnitario: 8, cantidad: 1, subtotal: 8),
      ];
      final campos = DetallePedidoModel.camposDeLineas(lineas);
      expect(campos['lineasIds'], ['p1', 'v1', 'c1', 'p2']);
      expect(campos['lineasCant'], [2, 2, 2, 1]);
      expect(campos['lineasTipo'], ['p', 'v', 'c', 'p']);
      expect(campos['precios'], {'p1': 35, 'v1': 5, 'c1': 3, 'p2': 8});
      expect(DetallePedidoModel.contarLineas(lineas), 4);
      // El subtotal incluye los extras: 2 × (35 + 5 + 3) + 8.
      expect(DetallePedidoModel.sumar(lineas), 94);
      final leidas = DetallePedidoModel.desdePedido(campos);
      expect(leidas.length, 2);
      expect(leidas.first.variantes.single.nombre, 'Grande');
      expect(leidas.first.complementos.single.precio, 3);
      expect(leidas.first.subtotal, 86);
      expect(leidas.last.subtotal, 8);
    });
  });
}
