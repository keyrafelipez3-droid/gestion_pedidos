import 'dart:math' as math;

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

  test('sin negocio se usa la marca Nami: fondo masa, locoto y texto berenjena', () {
    final t = ctrl.buildThemeFor(null, Brightness.light);
    expect(t.colorScheme.brightness, Brightness.light);
    expect(t.scaffoldBackgroundColor, AppBrand.masa);
    expect(t.colorScheme.primary, AppBrand.locoto);
    expect(t.colorScheme.onSurface, AppBrand.berenjena);
    // Botón locoto con letras blancas.
    expect(t.colorScheme.onPrimary, Colors.white);
    expect(t.extension<BrandStyle>()!.tarjeta, 'plato');
  });

  test('un negocio guardado con el estilo anterior "caro" usa el estilo Nami', () {
    final b = BrandStyle.desde(forma: 'pildora', estilo: 'caro', primary: AppBrand.locoto);
    expect(b.tarjeta, 'plato');
  });

  test('modo oscuro de la marca: fondo noche, texto masa y locoto claro', () {
    final t = ctrl.buildThemeFor(null, Brightness.dark);
    expect(t.colorScheme.brightness, Brightness.dark);
    expect(t.scaffoldBackgroundColor, AppBrand.noche);
    expect(t.colorScheme.onSurface, AppBrand.masa);
    expect(t.colorScheme.primary, AppBrand.locotoClaro);
    expect(t.colorScheme.onPrimary, AppBrand.berenjena);
    // Tarjetas con borde fino (la sombra no se ve en oscuro).
    final forma = t.cardTheme.shape as RoundedRectangleBorder;
    expect(forma.side, isNot(BorderSide.none));
  });

  test('el rojo de los botones se lee bien (contraste de 4,5 : 1 o más)', () {
    double contraste(Color a, Color b) {
      final la = a.computeLuminance(), lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }
    expect(contraste(AppBrand.locoto, Colors.white), greaterThanOrEqualTo(4.5));
    expect(contraste(AppBrand.locoto, AppBrand.masa), greaterThanOrEqualTo(4.5));
    expect(contraste(AppBrand.locotoClaro, AppBrand.noche), greaterThanOrEqualTo(4.5));
    expect(contraste(AppBrand.locotoClaro, AppBrand.berenjena), greaterThanOrEqualTo(4.5));
  });

  test('un logo para cada momento del día', () {
    expect(AppBrand.momento(DateTime(2026, 1, 1, 8)), 'manana');
    expect(AppBrand.momento(DateTime(2026, 1, 1, 12)), 'tarde');
    expect(AppBrand.momento(DateTime(2026, 1, 1, 18, 59)), 'tarde');
    expect(AppBrand.momento(DateTime(2026, 1, 1, 19)), 'noche');
    expect(AppBrand.momento(DateTime(2026, 1, 1, 5, 59)), 'noche');
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

  test('el texto sobre un color siempre es el que más se lee', () {
    // Dorado medio: letras oscuras (antes salían blancas y no se leían).
    expect(colorSobre(const Color(0xFFC9A45C)), const Color(0xFF111111));
    // Azul oscuro y negro: letras blancas.
    expect(colorSobre(const Color(0xFF0A2E5C)), Colors.white);
    expect(colorSobre(AppBrand.berenjena), Colors.white);
  });

  test('en fondo oscuro las tarjetas llevan borde fino', () {
    const n = NegocioModel(idNegocio: 'x', nombre: 'X', colorFondo: '#101820');
    final t = ctrl.buildThemeFor(n, Brightness.dark);
    final forma = t.cardTheme.shape as RoundedRectangleBorder;
    expect(forma.side, isNot(BorderSide.none));
  });
}
