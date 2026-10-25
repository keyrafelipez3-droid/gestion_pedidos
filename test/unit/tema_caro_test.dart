import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/models/negocio_model.dart';
import 'package:gestion_pedidos/services/app_theme_controller.dart';
import 'package:gestion_pedidos/theme/brand_style.dart';
import 'package:gestion_pedidos/theme/design_tokens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  AppThemeController.usarFuentesDeGoogle = false;
  final ctrl = AppThemeController.instancia;

  test('sin negocio se usa la marca Caro: fondo oscuro y dorado', () {
    final t = ctrl.buildThemeFor(null, Brightness.light);
    expect(t.colorScheme.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, AppBrand.fondoOscuro);
    expect(t.colorScheme.primary, AppBrand.dorado);
    expect(t.extension<BrandStyle>()!.tarjeta, 'borde');
  });

  test('un negocio sin fondo propio sigue en modo claro con su color', () {
    const n = NegocioModel(idNegocio: 'x', nombre: 'X', colorPrimario: '#1565C0');
    final t = ctrl.buildThemeFor(n, Brightness.light);
    expect(t.colorScheme.brightness, Brightness.light);
    expect(t.colorScheme.primary, const Color(0xFF1565C0));
  });

  test('un fondo oscuro elegido por el negocio vuelve oscuro todo el tema', () {
    const n = NegocioModel(idNegocio: 'x', nombre: 'X', colorFondo: '#101820');
    final t = ctrl.buildThemeFor(n, Brightness.light);
    expect(t.colorScheme.brightness, Brightness.dark);
  });

  test('en fondo oscuro las tarjetas llevan borde fino', () {
    final t = ctrl.buildThemeFor(null, Brightness.dark);
    final forma = t.cardTheme.shape as RoundedRectangleBorder;
    expect(forma.side, isNot(BorderSide.none));
  });
}
