import 'package:flutter/material.dart';

/// Tokens de diseño reutilizables por toda la app: espaciado, radios y
/// colores semánticos. Centralizarlos acá evita "números mágicos"
/// repetidos en cada pantalla y hace que el diseño sea consistente en
/// todas las pantallas de cliente y de administración.
class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Identidad de la marca "Nami" (de "ñam": el sonido de comer rico).
///
/// La paleta sale de la cocina boliviana:
/// - berenjena: la "tinta" de la marca (texto, logo, fondos de acento).
/// - locoto: el rojo del ají fresco; color principal de acción.
/// - ají amarillo: acentos pequeños (vapor del logo, estrellas, avisos).
/// - huacataya: el verde de la hierba; éxito / disponible.
/// - masa: fondo general, un blanco apenas teñido de berenjena.
///
/// Es la paleta por defecto de la app; cada negocio la reemplaza con su
/// propio color de marca (ver AppThemeController).
class AppBrand {
  AppBrand._();
  static const String nombre = 'Nami';
  static const String eslogan = 'Pedidos de comida';

  /// Un logo para cada momento del día: mañana (plato verde), tarde
  /// (plato locoto con vapor) y noche (cuchara sobre verde oliva).
  static const String logoManana = 'assets/images/logo_dia.png';
  static const String logoTarde = 'assets/images/logo_nami.png';
  static const String logoNoche = 'assets/images/logo_noche.png';

  /// 'manana' de 6:00 a 11:59, 'tarde' de 12:00 a 18:59 y 'noche' de
  /// 19:00 a 5:59.
  static String momento([DateTime? ahora]) {
    final hora = (ahora ?? DateTime.now()).hour;
    if (hora >= 6 && hora < 12) return 'manana';
    if (hora >= 12 && hora < 19) return 'tarde';
    return 'noche';
  }

  static String get logoAsset {
    switch (momento()) {
      case 'manana':
        return logoManana;
      case 'tarde':
        return logoTarde;
      default:
        return logoNoche;
    }
  }

  static const String fuente = 'Poppins';

  /// Tipografía de la marca (Google Fonts): titulares con carácter y
  /// texto corrido muy legible. Si no hay internet se usa Poppins.
  static const String fuenteTitulos = 'Bricolage Grotesque';
  static const String fuenteTexto = 'Figtree';

  static const Color berenjena = Color(0xFF2A1730);
  static const Color berenjenaSuave = Color(0xFF4A3550);
  /// Rojo de acción. Un poco más profundo que el de la propuesta original
  /// (#D93A22): con letras blancas quedaba justo en el límite de lectura
  /// (4,6 : 1) y como texto sobre el fondo masa no llegaba al mínimo.
  /// Así: 5,6 : 1 con blanco y 5,2 : 1 sobre masa.
  static const Color locoto = Color(0xFFC2301A);
  static const Color locotoOscuro = Color(0xFFB42D18);

  /// Locoto para el modo oscuro: más claro, para que se lea sobre el fondo
  /// de noche (7 : 1); los botones llevan letras berenjena.
  static const Color locotoClaro = Color(0xFFFF7A5C);
  static const Color aji = Color(0xFFFFB020);
  static const Color huacataya = Color(0xFF2F7D5B);
  static const Color masa = Color(0xFFF7F4F8);
  static const Color leche = Color(0xFFFFFFFF);

  /// Fondo del modo oscuro: berenjena muy oscura (no negro puro).
  static const Color noche = Color(0xFF1C1220);
}

/// Duraciones de animación: cortas y suaves (150-250 ms), nada llamativo.
class AppMotion {
  AppMotion._();
  static const Duration rapida = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve curva = Curves.easeOutCubic;
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
}

/// Breakpoints simples para adaptar layouts (grids, sidebar) al ancho de
/// pantalla disponible. Se usan a partir de la Fase 6 (responsive), pero
/// viven acá desde ya junto al resto de los tokens.
class AppBreakpoints {
  AppBreakpoints._();
  static const double compact = 600; // celular
  static const double medium = 1000; // tablet / ventana chica
  static const double expanded = 1000; // desktop / ventana grande

  static bool isCompact(double width) => width < compact;
  static bool isMedium(double width) => width >= compact && width < expanded;
  static bool isExpanded(double width) => width >= expanded;
}

/// Colores que no dependen del color de marca del negocio (éxito,
/// advertencia, información) — antes se usaban sueltos como `Colors.red`
/// o `Colors.green` directo en varias pantallas; ahora tienen un único
/// lugar de origen y se acceden con `context.semanticColors`.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color info;
  final Color onInfo;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.info,
    required this.onInfo,
  });

  static const light = AppSemanticColors(
    success: Color(0xFF2F7D5B),
    onSuccess: Colors.white,
    warning: Color(0xFFED6C02),
    onWarning: Colors.white,
    info: Color(0xFF0288D1),
    onInfo: Colors.white,
  );

  static const dark = AppSemanticColors(
    success: Color(0xFF66BB6A),
    onSuccess: Color(0xFF00390D),
    warning: Color(0xFFFFB74D),
    onWarning: Color(0xFF4A2800),
    info: Color(0xFF4FC3F7),
    onInfo: Color(0xFF003547),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? info,
    Color? onInfo,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
    );
  }
}

/// Acceso corto desde cualquier pantalla: `context.semanticColors.success`.
extension AppThemeTokensX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
