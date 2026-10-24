import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/permisos_negocio.dart';

void main() {
  test('sin configurar: el cajero puede todo y la cocina no cancela', () {
    final p = PermisosNegocio.desde(null);
    expect(p.cajeroCancelaPedidos, isTrue);
    expect(p.cajeroRegistraEgresos, isTrue);
    expect(p.cajeroTomaPedidosMesa, isTrue);
    expect(p.cocinaCancelaPedidos, isFalse);
  });

  test('lee lo guardado e ignora valores raros', () {
    final p = PermisosNegocio.desde({'cajeroRegistraEgresos': false, 'cocinaCancelaPedidos': 'si'});
    expect(p.cajeroRegistraEgresos, isFalse);
    expect(p.cocinaCancelaPedidos, isFalse);
  });

  test('cambiar un permiso no toca los demás', () {
    final p = PermisosNegocio.porDefecto.con('cajeroCancelaPedidos', false);
    expect(p.cajeroCancelaPedidos, isFalse);
    expect(p.cajeroTomaPedidosMesa, isTrue);
    expect(p.toMap().keys, hasLength(4));
  });

  test('cada permiso de la pantalla existe en el modelo', () {
    for (final d in PermisosNegocio.descripciones) {
      expect(PermisosNegocio.porDefecto.toMap().containsKey(d.$1), isTrue, reason: d.$1);
    }
  });
}
