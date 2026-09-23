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
    success: Color(0xFF2E7D32),
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
