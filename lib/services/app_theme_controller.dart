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

  /// Corrección pedida por el docente (multi-tenant): ya no existe UN
  /// negocio global, así que hay que indicar de cuál cargar el tema (el
  /// del Administrador/empleado logueado). Sin `idNegocio` (antes de
  /// iniciar sesión, o para un SuperAdmin que no tiene uno fijo) se queda
  /// con el tema por defecto.
  Future<void> cargar({String? idNegocio}) async {
    if (idNegocio == null) {
      negocio.value = null;
      return;
    }
    try {
      negocio.value = await NegocioService.instancia.obtenerNegocioPorId(idNegocio);
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

  /// Texto legible (oscuro o blanco) sobre un color de fondo cualquiera.
  Color _textoSobre(Color fondo) =>
      fondo.computeLuminance() > 0.40 ? AppBrand.tinta : Colors.white;

  /// En modo oscuro, un color de marca muy oscuro no se vería: se aclara.
  Color _ajustarParaOscuro(Color c) {
    if (c.computeLuminance() >= 0.22) return c;
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(hsl.lightness < 0.6 ? 0.6 : hsl.lightness).toColor();
  }

  /// Esquema de color: se parte de fromSeed (para que todos los tonos de
  /// apoyo combinen) pero el color de marca se usa TAL CUAL como primario,
  /// con superficies cálidas y tarjetas planas estilo apps de delivery.
  ColorScheme _buildScheme(Color marca, Color secundario, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final primary = isDark ? _ajustarParaOscuro(marca) : marca;
    final base = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      secondary: secundario,
    );
    final onPrimary = _textoSobre(primary);
    if (isDark) {
      return base.copyWith(
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: Color.alphaBlend(primary.withValues(alpha: 0.22), const Color(0xFF1C1C1C)),
        onPrimaryContainer: primary,
        surface: const Color(0xFF121212),
        onSurface: const Color(0xFFF2EDE4),
        onSurfaceVariant: const Color(0xFFB8B0A2),
        surfaceContainerLowest: const Color(0xFF0B0B0B),
        surfaceContainerLow: const Color(0xFF1A1A1A),
        surfaceContainer: const Color(0xFF202020),
        surfaceContainerHigh: const Color(0xFF262626),
        surfaceContainerHighest: const Color(0xFF2E2E2E),
        outlineVariant: const Color(0xFF3A3630),
        error: const Color(0xFFFF6B66),
      );
    }
    return base.copyWith(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: Color.alphaBlend(primary.withValues(alpha: 0.16), Colors.white),
      onPrimaryContainer: Color.lerp(primary, Colors.black, 0.55)!,
      surface: AppBrand.crema,
      onSurface: const Color(0xFF1F1B16),
      onSurfaceVariant: const Color(0xFF6B6459),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF6F0E6),
      surfaceContainerHigh: const Color(0xFFF1EADF),
      surfaceContainerHighest: const Color(0xFFECE4D6),
      outlineVariant: const Color(0xFFE6DDCD),
      error: const Color(0xFFD32F2F),
    );
  }

  /// Construye el ThemeData completo de la app: color, tipografía y el
  /// estilo de cada componente, todo derivado del color de marca del
  /// negocio (o de la marca Caro si todavía no hay negocio cargado), para
  /// que la app se sienta coherente sin repetir estilos pantalla por
  /// pantalla.
  ThemeData buildTheme(Brightness brightness) {
    final data = negocio.value;
    final marca = _color(data?.colorPrimario ?? '', AppBrand.dorado);
    final secundario = _color(data?.colorSecundario ?? '', const Color(0xFFFFF3E0));
    final scheme = _buildScheme(marca, secundario, brightness);
    final isDark = brightness == Brightness.dark;
    final textTheme = _buildTextTheme(scheme);
    // HU-10 (Fase 5): "Fondo" es opcional — si el negocio no eligió uno,
    // se usa la superficie cálida del tema. Solo reemplaza el fondo del
    // Scaffold (no el de tarjetas/inputs, que siguen leyendo del esquema
    // de color para no perder contraste).
    final fondoPersonalizado = _colorOpcional(data?.colorFondo);
    final bordeSuave = BorderSide(color: scheme.outlineVariant);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: AppBrand.fuente,
      scaffoldBackgroundColor: fondoPersonalizado ?? scheme.surface,
      textTheme: textTheme,
      extensions: [isDark ? AppSemanticColors.dark : AppSemanticColors.light],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: fondoPersonalizado ?? scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),

      // Tarjetas planas con borde fino (en vez de sombras fuertes).
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.10),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll, side: bordeSuave),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? scheme.surfaceContainerHigh : Colors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: bordeSuave,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: bordeSuave,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: AppBrand.fuente,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          minimumSize: const Size(0, 50),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: AppBrand.fuente,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? scheme.primary : scheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          textStyle: const TextStyle(
            fontFamily: AppBrand.fuente,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: const StadiumBorder(),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge,
        shape: StadiumBorder(side: bordeSuave),
        side: bordeSuave,
        showCheckmark: false,
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? scheme.primary : scheme.onPrimaryContainer,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
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
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? scheme.surfaceContainerHighest : const Color(0xFF26211A),
        contentTextStyle: const TextStyle(
          fontFamily: AppBrand.fuente,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlAll),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
    );
  }

  TextTheme _buildTextTheme(ColorScheme scheme) {
    final base = ThemeData(
      brightness: scheme.brightness,
      useMaterial3: true,
      fontFamily: AppBrand.fuente,
    ).textTheme.apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    return base.copyWith(
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
      headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
