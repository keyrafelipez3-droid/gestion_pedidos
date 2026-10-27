import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/models/mesa_model.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/screens/cajero/cajero_caja_screen.dart';
import 'package:gestion_pedidos/screens/cajero/cajero_mesas_screen.dart';
import 'package:gestion_pedidos/screens/cajero/cajero_pedidos_screen.dart';
import 'package:gestion_pedidos/utils/acciones_pedido.dart';
import 'package:gestion_pedidos/utils/formato.dart';
import 'package:gestion_pedidos/widgets/tarjeta_pedido_personal.dart';

PedidoModel _pedido(
  String id, {
  String estado = PedidoEstado.pendiente,
  String modalidad = PedidoModalidad.recoger,
  double total = 10,
  String origen = PedidoOrigen.cliente,
  bool cobrado = false,
  String? repartidor,
  String? nombre,
  String? mesa,
  String? idMesa,
  DateTime? fecha,
  DateTime? programado,
}) =>
    PedidoModel(
      id: id,
      idCliente: 'c',
      idNegocio: 'n1',
      idSucursal: 's1',
      modalidad: modalidad,
      metodoPago: MetodoPago.efectivo,
      estado: estado,
      total: total,
      origen: origen,
      cobrado: cobrado,
      idRepartidor: repartidor,
      nombreCliente: nombre,
      numeroMesa: mesa,
      idMesa: idMesa,
      fechaCreacion: fecha,
      programadoPara: programado,
    );

void main() {
  group('Tablero del Cajero', () {
    test('cada estado va a su columna', () {
      expect(grupoDePedido(_pedido('a')), GrupoPedidos.nuevos);
      expect(grupoDePedido(_pedido('a', estado: PedidoEstado.enPreparacion)), GrupoPedidos.preparando);
      expect(grupoDePedido(_pedido('a', estado: PedidoEstado.listo)), GrupoPedidos.listos);
      expect(grupoDePedido(_pedido('a', estado: PedidoEstado.enCamino)), GrupoPedidos.reparto);
      expect(grupoDePedido(_pedido('a', estado: PedidoEstado.llego)), GrupoPedidos.reparto);
      expect(grupoDePedido(_pedido('a', estado: PedidoEstado.cancelado)), GrupoPedidos.cancelados);
    });

    test('el buscador encuentra por número, cliente o mesa', () {
      final p = _pedido('abc123xyz', nombre: 'Ana Rojas', mesa: '4');
      expect(coincideBusqueda(p, ''), isTrue);
      expect(coincideBusqueda(p, '#ABC1'), isTrue);
      expect(coincideBusqueda(p, 'rojas'), isTrue);
      expect(coincideBusqueda(p, '4'), isTrue);
      expect(coincideBusqueda(p, 'luis'), isFalse);
    });

    test('por cobrar en caja: solo pedidos de la app que cobra el Cajero', () {
      final total = porCobrarEnCaja([
        _pedido('a', total: 30),
        _pedido('b', total: 20, cobrado: true),
        _pedido('c', total: 50, modalidad: PedidoModalidad.delivery, repartidor: 'r1'),
        _pedido('d', total: 15, origen: PedidoOrigen.cajero),
        _pedido('e', total: 12, modalidad: PedidoModalidad.delivery),
      ]);
      expect(total, 42);
    });

    test('un pedido que no está listo a los 20 minutos está atrasado', () {
      final ahora = DateTime(2026, 10, 27, 12, 30);
      expect(pedidoAtrasado(_pedido('a', fecha: DateTime(2026, 10, 27, 12, 5)), ahora: ahora), isTrue);
      expect(pedidoAtrasado(_pedido('a', fecha: DateTime(2026, 10, 27, 12, 20)), ahora: ahora), isFalse);
      expect(
        pedidoAtrasado(_pedido('a', estado: PedidoEstado.listo, fecha: DateTime(2026, 10, 27, 11)), ahora: ahora),
        isFalse,
      );
    });

    test('el número corto del pedido va en mayúsculas', () {
      expect(numeroPedido(_pedido('abc123xyz')), '#ABC123');
    });

    test('flujo del pedido y quién lo cobra', () {
      expect(siguienteEstadoFlujo(PedidoEstado.pendiente), PedidoEstado.enPreparacion);
      expect(siguienteEstadoFlujo(PedidoEstado.listo), PedidoEstado.entregado);
      expect(siguienteEstadoFlujo(PedidoEstado.enCamino), PedidoEstado.entregado);
      expect(siguienteEstadoFlujo(PedidoEstado.entregado), isNull);
      expect(loCobraLaCaja(_pedido('a', modalidad: PedidoModalidad.delivery, repartidor: 'r')), isFalse);
      expect(loCobraLaCaja(_pedido('a', modalidad: PedidoModalidad.delivery)), isTrue);
      expect(requiereCobroEnCaja(_pedido('a', estado: PedidoEstado.listo)), isTrue);
      expect(requiereCobroEnCaja(_pedido('a', estado: PedidoEstado.listo, origen: PedidoOrigen.cajero)), isFalse);
    });
  });

  group('Plano de mesas', () {
    const ocupada = MesaModel(id: 'm1', numero: '1', estado: MesaEstado.ocupada);

    test('una mesa con todo entregado queda "por cobrar"', () {
      expect(estadoVisualMesa(const MesaModel(id: 'm', numero: '2'), const []), EstadoVisualMesa.libre);
      expect(
        estadoVisualMesa(const MesaModel(id: 'm', numero: '2', estado: MesaEstado.reservada), const []),
        EstadoVisualMesa.reservada,
      );
      expect(estadoVisualMesa(ocupada, const []), EstadoVisualMesa.ocupada);
      expect(
        estadoVisualMesa(ocupada, [_pedido('a', estado: PedidoEstado.listo)]),
        EstadoVisualMesa.ocupada,
      );
      expect(
        estadoVisualMesa(ocupada, [
          _pedido('a', estado: PedidoEstado.entregado),
          _pedido('b', estado: PedidoEstado.cancelado),
        ]),
        EstadoVisualMesa.porCobrar,
      );
    });

    test('el total de la cuenta no suma los cancelados', () {
      expect(
        totalCuentaMesa([
          _pedido('a', total: 40, estado: PedidoEstado.entregado),
          _pedido('b', total: 25, estado: PedidoEstado.cancelado),
          _pedido('c', total: 10),
        ]),
        50,
      );
    });
  });

  group('Conteo de caja', () {
    test('suma billetes y monedas sin errores de redondeo', () {
      expect(totalConteo({200: 3, 100: 4, 50: 3, 0.1: 3, 0.2: 1}), 1150.5);
      expect(totalConteo(const {}), 0);
    });

    test('nombres de las denominaciones', () {
      expect(etiquetaDenominacion(200), 'Bs 200');
      expect(etiquetaDenominacion(0.5), '50 ctvs');
      expect(denominacionesBs.first, 200);
    });
  });

  group('Tiempos', () {
    final ahora = DateTime(2026, 10, 27, 15, 0);

    test('hace cuánto', () {
      expect(haceTiempo(ahora, ahora: ahora), 'recién');
      expect(haceTiempo(DateTime(2026, 10, 27, 14, 52), ahora: ahora), 'hace 8 min');
      expect(haceTiempo(DateTime(2026, 10, 27, 13, 55), ahora: ahora), 'hace 1 h 05');
      expect(haceTiempo(DateTime(2026, 10, 25, 15, 0), ahora: ahora), 'hace 2 d');
      expect(haceTiempo(null), '');
    });

    test('duración corta y minutos', () {
      expect(duracionCorta(35), '35 min');
      expect(duracionCorta(65), '1 h 05');
      expect(minutosTranscurridos(DateTime(2026, 10, 27, 16), ahora: ahora), 0);
      expect(dinero(12.5), 'Bs 12.50');
    });
  });
}
