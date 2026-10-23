import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/cupon_model.dart';
import 'package:gestion_pedidos/services/cupon_service.dart';

void main() {
  group('CuponModel.descuentoPara', () {
    test('porcentaje', () {
      const c = CuponModel(codigo: 'CARO10', tipo: CuponModel.porcentaje, valor: 10);
      expect(c.descuentoPara(85), 8.5);
    });

    test('porcentaje se redondea hacia abajo (nunca regala centavos)', () {
      const c = CuponModel(codigo: 'X', tipo: CuponModel.porcentaje, valor: 15);
      expect(c.descuentoPara(33.33), 4.99);
    });

    test('monto fijo', () {
      const c = CuponModel(codigo: 'BIENVENIDA', tipo: CuponModel.monto, valor: 5);
      expect(c.descuentoPara(40), 5);
    });

    test('nunca descuenta más que la compra', () {
      const c = CuponModel(codigo: 'GRANDE', tipo: CuponModel.monto, valor: 50);
      expect(c.descuentoPara(30), 30);
    });
  });

  group('vigencia', () {
    test('vencido', () {
      final c = CuponModel(codigo: 'A', valor: 10, vence: DateTime.now().subtract(const Duration(days: 1)));
      expect(c.vencido, isTrue);
      expect(c.vigente, isFalse);
    });

    test('pausado no es vigente', () {
      const c = CuponModel(codigo: 'A', valor: 10, activo: false);
      expect(c.vigente, isFalse);
    });

    test('sin fecha no vence', () {
      const c = CuponModel(codigo: 'A', valor: 10);
      expect(c.vencido, isFalse);
      expect(c.vigente, isTrue);
    });
  });

  test('el código se normaliza (mayúsculas, sin espacios ni símbolos)', () {
    expect(CuponService.normalizar('  caro 10! '), 'CARO10');
    expect(CuponService.normalizar('promo_2026-a'), 'PROMO_2026-A');
  });

  test('etiqueta del valor', () {
    expect(const CuponModel(codigo: 'A', valor: 10).etiquetaValor, '10 %');
    expect(const CuponModel(codigo: 'A', tipo: CuponModel.monto, valor: 5).etiquetaValor, 'Bs 5.00');
  });
}
