import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/pedido_models.dart';
import 'package:gestion_pedidos/utils/motivo_obligatorio.dart';

/// Pestaña "Cancelados" del Cajero y motivo obligatorio del Administrador.
void main() {
  PedidoModel pedido(String id, {DateTime? creado, DateTime? cancelado}) => PedidoModel(
        id: id,
        idCliente: 'c',
        idNegocio: 'n',
        idSucursal: 's',
        modalidad: PedidoModalidad.recoger,
        metodoPago: MetodoPago.efectivo,
        estado: PedidoEstado.cancelado,
        fechaCreacion: creado,
        fechaCancelacion: cancelado,
      );

  group('unirCancelados', () {
    final hoy = DateTime(2026, 11, 23, 18);

    test('un pedido viejo cancelado hoy aparece primero', () {
      final viejo = pedido('viejo', creado: hoy.subtract(const Duration(days: 33)), cancelado: hoy);
      final reciente = pedido('reciente', creado: hoy.subtract(const Duration(hours: 5)));
      final lista = unirCancelados([viejo], [reciente]);
      expect(lista.map((p) => p.id), ['viejo', 'reciente']);
    });

    test('si sale en las dos consultas, aparece una sola vez', () {
      final p = pedido('p1', creado: hoy.subtract(const Duration(hours: 2)), cancelado: hoy);
      final lista = unirCancelados([p], [p]);
      expect(lista.length, 1);
      expect(lista.single.fechaCancelacion, hoy);
    });

    test('los cancelados antes de esta versión se ordenan por su creación', () {
      final a = pedido('a', creado: hoy.subtract(const Duration(days: 1)));
      final b = pedido('b', creado: hoy.subtract(const Duration(days: 3)));
      final c = pedido('c', creado: hoy.subtract(const Duration(days: 10)), cancelado: hoy.subtract(const Duration(days: 2)));
      expect(unirCancelados([c], [b, a]).map((p) => p.id), ['a', 'c', 'b']);
    });

    test('listas vacías', () {
      expect(unirCancelados(const [], const []), isEmpty);
    });
  });

  group('validarMotivo', () {
    test('vacío, solo espacios o muy corto no vale', () {
      expect(validarMotivo(null), isNotNull);
      expect(validarMotivo(''), isNotNull);
      expect(validarMotivo('     '), isNotNull);
      expect(validarMotivo('abc'), isNotNull);
    });

    test('muy largo no vale', () {
      expect(validarMotivo('x' * (motivoMaximo + 1)), isNotNull);
      expect(validarMotivo('x' * motivoMaximo), isNull);
    });

    test('un motivo normal vale', () {
      expect(validarMotivo('Pedidos falsos repetidos'), isNull);
      expect(validarMotivo('  Insultos  '), isNull);
    });

    test('exigirMotivo devuelve el texto limpio o lanza un error', () {
      expect(exigirMotivo('  Insultos  '), 'Insultos');
      expect(() => exigirMotivo(''), throwsA(isA<MotivoInvalidoException>()));
    });
  });
}
