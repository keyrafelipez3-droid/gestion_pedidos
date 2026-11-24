import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/resena_model.dart';
import 'package:gestion_pedidos/services/resena_service.dart';

ResenaModel _r(String id, int estrellas, String comentario,
        {String cliente = '', int dia = 1, String estado = ResenaEstado.visible}) =>
    ResenaModel(
      id: id,
      idNegocio: 'n1',
      idCliente: cliente.isEmpty ? 'c$id' : cliente,
      nombreCliente: 'Ana P.',
      calificacion: estrellas,
      comentario: comentario,
      fecha: DateTime(2026, 11, dia),
      estado: estado,
    );

void main() {
  test('antes de entrar se muestran las mejores: 4 o 5 estrellas, con comentario', () {
    final elegidas = ResenaService.seleccionarDestacadas([
      _r('a', 4, 'Rico y rápido', dia: 20),
      _r('b', 5, 'Excelente atención', dia: 10),
      _r('c', 3, 'Normal'),
      _r('d', 5, ''),
      _r('e', 5, 'Me encantó', dia: 15),
      _r('f', 5, 'Oculta', estado: ResenaEstado.oculta),
    ]);
    expect(elegidas.map((r) => r.id), ['e', 'b', 'a']);
  });

  test('una sola reseña por cliente y como máximo las pedidas', () {
    final elegidas = ResenaService.seleccionarDestacadas([
      _r('a', 5, 'Muy bueno', cliente: 'ana', dia: 3),
      _r('b', 5, 'Otra vez bueno', cliente: 'ana', dia: 2),
      _r('c', 5, 'Buenísimo', cliente: 'luis', dia: 1),
    ], maximo: 5);
    expect(elegidas.map((r) => r.id), ['a', 'c']);
    expect(ResenaService.seleccionarDestacadas([_r('x', 5, 'Bien'), _r('y', 5, 'Bien')], maximo: 1).length, 1);
  });

  test('el mismo comentario en dos restaurantes se muestra una sola vez', () {
    final elegidas = ResenaService.seleccionarDestacadas([
      _r('a', 5, 'La mejor salteña de Sucre, sin exagerar.', dia: 3),
      _r('b', 5, '  la mejor salteña de Sucre,  sin exagerar. ', dia: 2),
      _r('c', 5, 'Café de verdad.', dia: 1),
    ]);
    expect(elegidas.map((r) => r.id), ['a', 'c']);
  });
}
