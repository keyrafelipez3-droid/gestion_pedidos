import 'package:flutter/material.dart';

import '../models/negocio_model.dart';
import 'negocio_service.dart';

class AppThemeController {
  AppThemeController._();
  static final instancia = AppThemeController._();

  final ValueNotifier<NegocioModel?> negocio = ValueNotifier(null);

  Future<void> cargar() async {
    try {
      negocio.value = await NegocioService.instancia.obtenerNegocio();
    } catch (_) {
      // Mantiene el tema por defecto si el negocio aún no puede consultarse.
    }
  }

  void limpiar() => negocio.value = null;

  void actualizar(NegocioModel value) => negocio.value = value;

  Color _color(String hex, Color fallback) {
    final clean = hex.replaceAll('#', '');
    if (clean.length != 6) return fallback;
    final value = int.tryParse('FF$clean', radix: 16);
    return value == null ? fallback : Color(value);
  }

  ThemeData buildTheme(Brightness brightness) {
    final data = negocio.value;
    final primary = _color(data?.colorPrimario ?? '#E65100', Colors.deepOrange);
    final secondary = _color(data?.colorSecundario ?? '#FFF3E0', const Color(0xFFFFF3E0));
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      secondary: secondary,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(backgroundColor: scheme.primaryContainer),
    );
  }
}
