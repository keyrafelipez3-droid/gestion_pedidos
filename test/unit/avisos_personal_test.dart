import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/models/usuario_model.dart';
import 'package:gestion_pedidos/services/avisos_personal_service.dart';

PedidoModel _pedido(String id, String estado, {String modalidad = PedidoModalidad.recoger, String? creadoPor}) =>
    PedidoModel(
      id: id,
      idCliente: 'c1',
      idNegocio: 'n1',
      idSucursal: 's1',
      modalidad: modalidad,
      metodoPago: 'Efectivo',
      estado: estado,
      creadoPor: creadoPor,
    );

final _ahora = DateTime(2026, 11, 24, 12);

List<ElementoVigilado> _enCurso(List<PedidoModel> l, String rol) => [
      for (final p in l) ReglasAvisoPersonal.pedidoEnCurso(p, rol: rol, uid: 'yo', ahora: _ahora),
    ];

void main() {
  test('cada rol del personal tiene sus avisos; el cliente usa su propia campanita', () {
    expect(TipoAvisoPersonal.delRol(Rol.cocina), contains(TipoAvisoPersonal.pedidoNuevo));
    expect(TipoAvisoPersonal.delRol(Rol.cajero), contains(TipoAvisoPersonal.pedidoListo));
    expect(TipoAvisoPersonal.delRol(Rol.repartidor), contains(TipoAvisoPersonal.entregaDisponible));
    expect(TipoAvisoPersonal.delRol(Rol.administrador), contains(TipoAvisoPersonal.resenaNueva));
    expect(TipoAvisoPersonal.delRol(Rol.superAdmin), [TipoAvisoPersonal.solicitudNueva]);
    expect(TipoAvisoPersonal.delRol(Rol.cliente), isEmpty);
  });

  test('la primera vez en el dispositivo no avisa de lo que ya existía', () {
    final avisos = detectarAvisos(null, _enCurso([_pedido('abcdef1', PedidoEstado.pendiente)], Rol.cajero));
    expect(avisos, isEmpty);
  });

  test('avisa el pedido nuevo, una sola vez', () {
    final vistos = <String, String>{'viejo01': PedidoEstado.pendiente};
    final lista = _enCurso([
      _pedido('viejo01', PedidoEstado.pendiente),
      _pedido('nuevo01', PedidoEstado.pendiente),
    ], Rol.cocina);
    final avisos = detectarAvisos(vistos, lista);
    expect(avisos.length, 1);
    expect(avisos.single.tipo, TipoAvisoPersonal.pedidoNuevo);
    expect(avisos.single.texto, contains('#nuevo0'));
    expect(avisos.single.texto, contains('para preparar'));
    vistos['nuevo01'] = PedidoEstado.pendiente;
    expect(detectarAvisos(vistos, lista), isEmpty);
  });

  test('el pedido de mesa que registró la misma persona no le avisa', () {
    final avisos = detectarAvisos(
      const {},
      _enCurso([_pedido('mesa001', PedidoEstado.pendiente, creadoPor: 'yo')], Rol.cajero),
    );
    expect(avisos, isEmpty);
  });

  test('al cajero le avisa cuando un pedido queda listo; a la cocina no', () {
    const vistos = {'p000001': PedidoEstado.enPreparacion};
    final listo = [_pedido('p000001', PedidoEstado.listo, modalidad: PedidoModalidad.delivery)];
    final cajero = detectarAvisos(vistos, _enCurso(listo, Rol.cajero));
    expect(cajero.single.tipo, TipoAvisoPersonal.pedidoListo);
    expect(cajero.single.texto, contains('repartidor'));
    expect(detectarAvisos(vistos, _enCurso(listo, Rol.cocina)), isEmpty);
  });

  test('avisa los cancelados de hoy con el número del pedido', () {
    final avisos = detectarAvisos(const {}, [
      ReglasAvisoPersonal.cancelado(_pedido('canc001', PedidoEstado.cancelado), ahora: _ahora),
    ]);
    expect(avisos.single.tipo, TipoAvisoPersonal.pedidoCancelado);
    expect(avisos.single.texto, contains('#canc00'));
  });

  test('al repartidor: entrega disponible y la que le asignaron, no la que él tomó', () {
    final disponible = detectarAvisos(const {}, [
      ReglasAvisoPersonal.entregaDisponible(
          _pedido('ent0001', PedidoEstado.listo, modalidad: PedidoModalidad.delivery),
          ahora: _ahora),
    ]);
    expect(disponible.single.tipo, TipoAvisoPersonal.entregaDisponible);

    final asignada = detectarAvisos(const {}, [
      ReglasAvisoPersonal.entregaMia(
          _pedido('asg0001', PedidoEstado.listo, modalidad: PedidoModalidad.delivery),
          ahora: _ahora),
    ]);
    expect(asignada.single.tipo, TipoAvisoPersonal.entregaAsignada);

    final tomada = detectarAvisos(const {}, [
      ReglasAvisoPersonal.entregaMia(
          _pedido('tom0001', PedidoEstado.enCamino, modalidad: PedidoModalidad.delivery),
          ahora: _ahora),
    ]);
    expect(tomada, isEmpty);
  });

  test('reseñas, reclamos y solicitudes nuevas', () {
    final avisos = detectarAvisos(const {}, [
      ReglasAvisoPersonal.resena('r1', 5, 'Ana P.', ahora: _ahora),
      ReglasAvisoPersonal.reclamo('q1', 'Demora en la entrega', ahora: _ahora),
      ReglasAvisoPersonal.solicitud('u1', 'Pollos Rosa', ahora: _ahora),
    ]);
    expect(avisos.map((a) => a.tipo), [
      TipoAvisoPersonal.resenaNueva,
      TipoAvisoPersonal.reclamoNuevo,
      TipoAvisoPersonal.solicitudNueva,
    ]);
    expect(avisos.first.texto, 'Nueva reseña de 5 estrellas de Ana P.');
    expect(avisos.first.esDePedido, isFalse);
  });

  test('el aviso se guarda y se recupera igual', () {
    final a = AvisoPersonal(
      tipo: TipoAvisoPersonal.pedidoNuevo,
      idRef: 'abc',
      texto: 'Nuevo pedido #abc',
      fecha: _ahora,
    );
    final b = AvisoPersonal.fromJson(a.toJson());
    expect(b.clave, a.clave);
    expect(b.texto, a.texto);
    expect(b.fecha, a.fecha);
    expect(b.leido, isFalse);
    expect(b.esDePedido, isTrue);
  });
}
