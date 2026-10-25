import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/negocio_model.dart';
import '../theme/brand_style.dart';
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

  /// Las pruebas automáticas lo ponen en false: no hay internet para
  /// descargar las fuentes de Google y se usa la fuente del sistema.
  static bool usarFuentesDeGoogle = true;

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

  /// Construye el ThemeData completo de la app: color, tipografía y el
  /// estilo de cada componente, todo derivado del mismo color semilla
  /// para que la app se sienta coherente sin repetir estilos pantalla
  /// por pantalla.
  ThemeData buildTheme(Brightness brightness) =>
      buildThemeFor(negocio.value, brightness);

  /// Igual que [buildTheme] pero para un negocio cualquiera. Lo usa la
  /// vista previa de la pantalla de personalización, que pinta la maqueta
  /// con un Theme real aún sin guardar.
  ThemeData buildThemeFor(NegocioModel? data, Brightness brightness) {
    // Sin negocio (inicio de sesión, cliente, SuperAdmin) se usa la marca
    // Caro: fondo casi negro, dorado y tarjetas finas con borde.
    final primary = _color(data?.colorPrimario ?? '', AppBrand.dorado);
    final secondary = data == null
        ? AppBrand.doradoOscuro
        : _color(data.colorSecundario, const Color(0xFFFFF3E0));
    // HU-10 (Fase 5): "Fondo" es opcional. Si el negocio eligió uno, el
    // esquema entero se adapta a él (texto con buen contraste, superficies
    // mezcladas) para que un fondo oscuro tipo "Brasa" funcione aunque el
    // modo claro/oscuro del sistema diga otra cosa.
    final fondoPersonalizado =
        data == null ? AppBrand.fondoOscuro : _colorOpcional(data.colorFondo);
    if (fondoPersonalizado != null) {
      brightness = ThemeData.estimateBrightnessForColor(fondoPersonalizado);
    }
    var scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      secondary: secondary,
    );
    final base = fondoPersonalizado ?? scheme.surface;
    final onBase = fondoPersonalizado != null ? colorSobre(base) : scheme.onSurface;
    Color mezcla(double a) => Color.alphaBlend(onBase.withValues(alpha: a), base);
    // El color de marca se usa TAL CUAL (fromSeed lo transforma y la marca
    // deja de parecerse a la que eligió el SuperAdmin).
    scheme = scheme.copyWith(
      brightness: fondoPersonalizado != null
          ? ThemeData.estimateBrightnessForColor(base)
          : null,
      primary: primary,
      onPrimary: colorSobre(primary),
      secondary: secondary,
      onSecondary: colorSobre(secondary),
      primaryContainer: Color.alphaBlend(primary.withValues(alpha: 0.18), base),
      onPrimaryContainer: onBase,
      surface: base,
      onSurface: onBase,
      onSurfaceVariant: onBase.withValues(alpha: 0.68),
      outline: onBase.withValues(alpha: 0.32),
      outlineVariant: onBase.withValues(alpha: 0.12),
      surfaceContainerLowest: fondoPersonalizado != null ? mezcla(0.04) : null,
      surfaceContainerLow: mezcla(0.04),
      surfaceContainer: mezcla(0.06),
      surfaceContainerHigh: mezcla(0.08),
      surfaceContainerHighest: mezcla(0.11),
    );
    final isDark = scheme.brightness == Brightness.dark;
    final brand = BrandStyle.desde(
      forma: data?.formaBotones ?? 'redondeado',
      estilo: data?.estiloBase ?? 'caro',
      primary: primary,
    );
    final textTheme = _buildTextTheme(
      scheme,
      tipografia: data?.tipografia ?? 'redondeada',
      brand: brand,
    );
    // Las sombras no se ven sobre fondo oscuro: ahí las tarjetas llevan un
    // borde fino para separarse del fondo.
    final conBorde = brand.tarjeta == 'borde' || isDark;
    final bordeFino = BorderSide(color: scheme.outlineVariant, width: brand.grosorBorde);
    final formaBoton = RoundedRectangleBorder(borderRadius: brand.boton);
    final formaPequena = RoundedRectangleBorder(borderRadius: brand.pequeno);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: base,
      textTheme: textTheme,
      extensions: [
        isDark ? AppSemanticColors.dark : AppSemanticColors.light,
        brand,
      ],
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          // iOS usa su transición nativa por defecto (no se fija aquí para
          // no depender de dónde la exporta cada versión de Flutter).
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        },
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: base,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),

      cardTheme: CardThemeData(
        color: brand.tarjeta == 'color'
            ? scheme.surfaceContainerHigh
            : (isDark ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest),
        surfaceTintColor: Colors.transparent,
        shadowColor: brand.colorSombra,
        elevation: brand.tarjeta == 'sombra' && !isDark ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: brand.card,
          side: conBorde ? bordeFino : BorderSide.none,
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.5 : 0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radioCampo),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radioCampo),
          borderSide: conBorde ? bordeFino : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radioCampo),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(brand.radioCampo),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
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
          shape: formaBoton,
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: brand.espaciadoTitulos,
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
          shape: formaBoton,
          side: BorderSide(
            color: conBorde ? scheme.outline : scheme.outlineVariant,
            width: brand.grosorBorde,
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: formaPequena,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(shape: formaPequena),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: formaBoton,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        secondarySelectedColor: scheme.primary,
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            brand.radioPequeno > 14 ? 999 : brand.radioPequeno,
          ),
        ),
        side: conBorde ? bordeFino : BorderSide.none,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: AppSpacing.lg,
      ),

      listTileTheme: ListTileThemeData(
        shape: formaPequena,
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
        shape: formaPequena,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? scheme.surfaceContainer : scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: brand.card,
          side: isDark ? bordeFino : BorderSide.none,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHigh,
          foregroundColor: scheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: formaBoton,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? scheme.primary : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface),
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
          shape: WidgetStatePropertyAll(formaBoton),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: brand.pequeno,
          side: isDark ? bordeFino : BorderSide.none,
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? scheme.surfaceContainerHighest : const Color(0xE6111111),
          borderRadius: brand.pequeno,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? scheme.onSurface : Colors.white,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(brand.radioTarjeta)),
        ),
      ),
    );
  }

  /// Tipografía del negocio: una familia para titulares y otra para el
  /// texto corrido (Google Fonts). Si no hay red la primera vez, Flutter
  /// usa la fuente del sistema mientras descarga, sin romper nada.
  TextTheme _buildTextTheme(
    ColorScheme scheme, {
    required String tipografia,
    required BrandStyle brand,
  }) {
    final base =
        ThemeData(brightness: scheme.brightness, useMaterial3: true).textTheme;
    final (titulares, cuerpo) = BrandOpciones.familias(tipografia);
    TextTheme cuerpoTheme;
    TextTheme tituloTheme;
    try {
      if (!usarFuentesDeGoogle) throw UnsupportedError('sin fuentes');
      cuerpoTheme = GoogleFonts.getTextTheme(cuerpo, base);
      tituloTheme = GoogleFonts.getTextTheme(titulares, base);
    } catch (_) {
      cuerpoTheme = base;
      tituloTheme = base;
    }
    final pesado = tipografia == 'gruesa';
    FontWeight peso(FontWeight w) => pesado ? FontWeight.w400 : w;
    final espacio = brand.espaciadoTitulos;
    // Títulos grandes un poco más juntos (se ven más firmes), salvo que el
    // estilo pida espaciado.
    final espacioGrande = espacio == 0 ? -0.5 : espacio;
    final t = cuerpoTheme.copyWith(
      displayLarge: tituloTheme.displayLarge?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacioGrande),
      displayMedium: tituloTheme.displayMedium?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacioGrande),
      displaySmall: tituloTheme.displaySmall?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacioGrande),
      headlineLarge: tituloTheme.headlineLarge?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacioGrande),
      headlineMedium: tituloTheme.headlineMedium?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacioGrande),
      headlineSmall: tituloTheme.headlineSmall?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacio == 0 ? -0.3 : espacio),
      titleLarge: tituloTheme.titleLarge?.copyWith(fontWeight: peso(FontWeight.w800), letterSpacing: espacio),
      titleMedium: tituloTheme.titleMedium?.copyWith(fontWeight: peso(FontWeight.w700), letterSpacing: espacio),
      titleSmall: cuerpoTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: cuerpoTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    return t.apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }
}
