import 'package:flutter/material.dart';

import '../models/negocio_model.dart';
import '../theme/design_tokens.dart';
import 'negocio_service.dart';

/// Controla el tema de toda la app a partir de los datos del negocio
/// (HU-07 / HU-10). Es un ValueNotifier para que cualquier widget se
/// reconstruya solo cuando el negocio cambia (ver `main.dart` y la
/// pantalla de personalización).
///
/// El color de marca (colorPrimario/colorSecundario) sigue viniendo de
/// Firestore exactamente igual que antes — lo que cambia acá es que ese
/// color ahora alimenta un ThemeData mucho más completo (tarjetas,
/// campos de texto, botones, tabs, etc.), en vez de solo el AppBar.
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

  /// Igual que `_color`, pero devuelve null (en vez de un fallback) cuando
  /// el hex está vacío o no es válido — así se puede distinguir "el
  /// negocio no eligió un color de fondo" de "eligió blanco".
  Color? _colorOpcional(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '');
    if (clean.length != 6) return null;
    final value = int.tryParse('FF$clean', radix: 16);
    return value == null ? null : Color(value);
  }

  /// Construye el ThemeData completo de la app: color, tipografía y el
  /// estilo de cada componente, todo derivado del mismo color semilla
  /// para que la app se sienta coherente sin repetir estilos pantalla
  /// por pantalla.
  ThemeData buildTheme(Brightness brightness) {
    final data = negocio.value;
    final primary = _color(data?.colorPrimario ?? '#FF7A00', const Color(0xFFFF7A00));
    final secondary =
        _color(data?.colorSecundario ?? '#FFF3E0', const Color(0xFFFFF3E0));
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      secondary: secondary,
    );
    final isDark = brightness == Brightness.dark;
    final textTheme = _buildTextTheme(scheme);
    // HU-10 (Fase 5): "Fondo" es opcional — si el negocio no eligió uno,
    // se sigue usando scheme.surface exactamente igual que antes. Solo
    // reemplaza el fondo del Scaffold (no el de tarjetas/inputs, que
    // siguen leyendo del esquema de color para no perder contraste).
    final fondoPersonalizado = _colorOpcional(data?.colorFondo);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: fondoPersonalizado ?? scheme.surface,
      textTheme: textTheme,
      extensions: [isDark ? AppSemanticColors.dark : AppSemanticColors.light],

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.3 : 0.5),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: BorderSide.none,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle:
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
        space: AppSpacing.lg,
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      ),
    );
  }

  TextTheme _buildTextTheme(ColorScheme scheme) {
    final base =
        ThemeData(brightness: scheme.brightness, useMaterial3: true).textTheme;
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
