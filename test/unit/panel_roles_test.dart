import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/config/app_config.dart';
import 'package:gestion_pedidos/legal/textos_legales.dart';
import 'package:gestion_pedidos/models/condiciones_negocio.dart';
import 'package:gestion_pedidos/models/negocio_model.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/screens/cliente/inicio_cliente.dart';
import 'package:gestion_pedidos/screens/repartidor/repartidor_entregas_screen.dart';

PedidoModel _pedido(String estado, {String pago = MetodoPago.efectivo, double total = 20, bool cobrado = false}) =>
    PedidoModel(
      id: 'p$estado',
      idCliente: 'c',
      idNegocio: 'n',
      idSucursal: 's',
      modalidad: PedidoModalidad.delivery,
      metodoPago: pago,
      estado: estado,
      total: total,
      cobrado: cobrado,
    );

void main() {
  test('el repartidor rinde solo el efectivo que todavía no entregó en caja', () {
    expect(
      efectivoPorRendir([
        _pedido(PedidoEstado.entregado, total: 30),
        _pedido(PedidoEstado.entregado, total: 50, cobrado: true),
        _pedido(PedidoEstado.entregado, total: 40, pago: MetodoPago.qr),
      ]),
      30,
    );
  });

  test('el cliente ve en palabras simples en qué va su pedido', () {
    expect(pedidoEnCurso(_pedido(PedidoEstado.enCamino)), isTrue);
    expect(pedidoEnCurso(_pedido(PedidoEstado.entregado)), isFalse);
    expect(mensajeEstadoCliente(_pedido(PedidoEstado.enPreparacion)), contains('preparando'));
    expect(mensajeEstadoCliente(_pedido(PedidoEstado.listo)), contains('pronto sale'));
  });

  test('acuerdo al día según las reglas internas del restaurante', () {
    const base = AppConfig.versionAcuerdoPersonal;
    const conReglas = NegocioModel(
      idNegocio: 'n',
      nombre: 'X',
      reglasPersonal: ReglasPersonal(version: 'v2', reglas: ['a']),
    );
    expect(TextosLegales.acuerdoAlDia(null, null), isFalse);
    expect(TextosLegales.acuerdoAlDia(base, null), isTrue);
    expect(TextosLegales.acuerdoAlDia('$base+v1', null), isTrue);
    expect(TextosLegales.acuerdoAlDia(base, conReglas), isFalse);
    expect(TextosLegales.acuerdoAlDia('$base+v2', conReglas), isTrue);
  });
}
