import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/legal/textos_legales.dart';
import 'package:gestion_pedidos/models/negocio_model.dart';
import 'package:gestion_pedidos/models/pais.dart';
import 'package:gestion_pedidos/utils/formato.dart';
import 'package:gestion_pedidos/utils/telefono.dart';

String _todo(List<SeccionLegal> s) => [for (final x in s) ...[x.titulo, x.enSimple ?? '', ...x.parrafos]].join('\n');

void main() {
  tearDown(() => Paises.actual = Paises.bolivia);

  test('cada país muestra su moneda', () {
    expect(Paises.bolivia.formatear(12.5), 'Bs 12.50');
    expect(Paises.mexico.formatear(12.5), r'$12.50');
    expect(Paises.peru.formatear(8), 'S/ 8.00');
    expect(Paises.chile.formatear(12500), r'$12.500');
    expect(Paises.colombia.formatear(1500000), r'$1.500.000');
    expect(Paises.bolivia.formatear(-3), '-Bs 3.00');
  });

  test('dinero() sigue al país del restaurante abierto', () {
    expect(dinero(5), 'Bs 5.00');
    Paises.actual = Paises.estadosUnidos;
    expect(dinero(5), r'$5.00');
    expect(prefijoMoneda(), r'$');
    Paises.actual = Paises.paraguay;
    expect(dinero(25000), '₲ 25.000');
  });

  test('país desconocido o vacío: Bolivia', () {
    expect(Paises.porCodigo(null).codigo, 'BO');
    expect(Paises.porCodigo('xx').codigo, 'BO');
    expect(Paises.porCodigo('mx').codigo, 'MX');
    for (final p in Paises.todos) {
      expect(p.denominaciones, isNotEmpty, reason: p.codigo);
      expect(p.leyDatos, isNotEmpty, reason: p.codigo);
      expect(p.autoridadConsumidor, isNotEmpty, reason: p.codigo);
      for (var i = 1; i < p.denominaciones.length; i++) {
        expect(p.denominaciones[i] < p.denominaciones[i - 1], isTrue, reason: '${p.codigo} en orden');
      }
    }
  });

  test('los textos legales usan las leyes del país del restaurante', () {
    const taqueria = NegocioModel(idNegocio: 'n', nombre: 'Taquería', pais: 'MX', nit: 'TAQ010101AAA');
    final texto = _todo(TextosLegales.condicionesRestaurante(taqueria));
    expect(texto, contains('PROFECO'));
    expect(texto, contains('RFC TAQ010101AAA'));
    expect(texto, contains('pesos mexicanos'));
    expect(texto, isNot(contains('Ley 453')));

    Paises.actual = Paises.estadosUnidos;
    final privacidad = _todo(TextosLegales.politicaPrivacidad());
    expect(privacidad, contains('CCPA'));
    expect(privacidad, contains('13 años'));
    expect(privacidad, contains('Cookies'));
    expect(_todo(TextosLegales.terminos()), contains('sin los impuestos de venta'));
  });

  test('el teléfono nuevo propone el país del restaurante', () {
    expect(Telefono.separar('').pais.iso, 'BO');
    Paises.actual = Paises.mexico;
    expect(Telefono.separar('').pais.iso, 'MX');
    Paises.actual = Paises.canada;
    expect(Telefono.separar('').pais.iso, 'US');
    expect(Telefono.separar('71234567').pais.iso, 'BO');
  });
}
