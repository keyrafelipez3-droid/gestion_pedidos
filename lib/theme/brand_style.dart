import 'package:flutter/material.dart';

/// Opciones de personalización que el SuperAdmin puede elegir por negocio.
/// Los ids son los que se guardan en Firestore (`estiloBase`, `tipografia`,
/// `formaBotones`).
class EstiloOpcion {
  final String id;
  final String nombre;
  final String descripcion;
  const EstiloOpcion(this.id, this.nombre, this.descripcion);
}

class BrandOpciones {
  BrandOpciones._();

  static const estilos = <EstiloOpcion>[
    EstiloOpcion('caro', 'Caro', 'Tarjetas finas con borde y títulos grandes'),
    EstiloOpcion('moderno', 'Moderno', 'Tarjetas con sombra suave'),
    EstiloOpcion('minimal', 'Minimal', 'Líneas finas, sin sombras'),
    EstiloOpcion('premium', 'Premium', 'Sobrio, con espaciado en títulos'),
    EstiloOpcion('natural', 'Natural', 'Superficies planas y cálidas'),
    EstiloOpcion('vibrante', 'Vibrante', 'Sombras con el color de marca'),
    EstiloOpcion('industrial', 'Industrial', 'Bordes marcados, títulos en mayúscula'),
  ];

  static const tipografias = <EstiloOpcion>[
    EstiloOpcion('sans', 'Sans moderna', 'Hanken Grotesk'),
    EstiloOpcion('slab', 'Slab', 'Zilla Slab'),
    EstiloOpcion('serif', 'Serif elegante', 'Playfair Display'),
    EstiloOpcion('gruesa', 'Gruesa', 'Archivo Black'),
    EstiloOpcion('redondeada', 'Redondeada', 'Poppins'),
    EstiloOpcion('condensada', 'Condensada', 'Barlow Condensed'),
  ];

  static const formas = <EstiloOpcion>[
    EstiloOpcion('cuadrado', 'Cuadrados', 'Esquinas casi rectas'),
    EstiloOpcion('redondeado', 'Redondeados', 'Esquinas suaves'),
    EstiloOpcion('pildora', 'Píldora', 'Totalmente redondos'),
  ];

  /// Familias (titulares, texto) de Google Fonts para cada tipografía.
  static (String, String) familias(String id) {
    switch (id) {
      case 'slab':
        return ('Zilla Slab', 'Lato');
      case 'serif':
        return ('Playfair Display', 'Lato');
      case 'gruesa':
        return ('Archivo Black', 'Archivo');
      case 'redondeada':
        return ('Poppins', 'Poppins');
      case 'condensada':
        return ('Barlow Condensed', 'Barlow');
      case 'sans':
      default:
        return ('Hanken Grotesk', 'Hanken Grotesk');
    }
  }
}

/// Tokens de estilo de un negocio, disponibles en cualquier pantalla con
/// `context.brand`. Así los widgets no hardcodean radios ni sombras: todo
/// cambia cuando el SuperAdmin cambia la forma o el estilo.
@immutable
class BrandStyle extends ThemeExtension<BrandStyle> {
  final double radioBoton;
  final double radioTarjeta;
  final double radioPequeno;
  final double radioCampo;

  /// sombra | borde | plano | color
  final String tarjeta;
  final double grosorBorde;
  final bool mayusculasTitulos;
  final double espaciadoTitulos;
  final Color colorSombra;

  const BrandStyle({
    required this.radioBoton,
    required this.radioTarjeta,
    required this.radioPequeno,
    required this.radioCampo,
    required this.tarjeta,
    required this.grosorBorde,
    required this.mayusculasTitulos,
    required this.espaciadoTitulos,
    required this.colorSombra,
  });

  static const defecto = BrandStyle(
    radioBoton: 14,
    radioTarjeta: 16,
    radioPequeno: 12,
    radioCampo: 12,
    tarjeta: 'sombra',
    grosorBorde: 1,
    mayusculasTitulos: false,
    espaciadoTitulos: 0,
    colorSombra: Color(0x1F000000),
  );

  factory BrandStyle.desde({
    required String forma,
    required String estilo,
    required Color primary,
  }) {
    double rb, rt, rp, rc;
    switch (forma) {
      case 'cuadrado':
        rb = 6;
        rt = 8;
        rp = 6;
        rc = 6;
        break;
      case 'pildora':
        rb = 28;
        rt = 22;
        rp = 22;
        rc = 16;
        break;
      case 'redondeado':
      default:
        rb = 14;
        rt = 16;
        rp = 12;
        rc = 12;
    }
    String tarjeta = 'sombra';
    double borde = 1;
    bool mayus = false;
    double espacio = 0;
    Color sombra = const Color(0x1F000000);
    switch (estilo) {
      case 'caro':
        // Estilo de la marca Caro: tarjetas con borde fino (se ven bien
        // sobre fondos oscuros) y una sombra muy suave.
        tarjeta = 'borde';
        sombra = const Color(0x33000000);
        break;
      case 'minimal':
        tarjeta = 'borde';
        break;
      case 'premium':
        tarjeta = 'borde';
        espacio = 0.6;
        break;
      case 'natural':
        tarjeta = 'color';
        break;
      case 'vibrante':
        tarjeta = 'sombra';
        sombra = primary.withValues(alpha: 0.32);
        break;
      case 'industrial':
        tarjeta = 'borde';
        borde = 1.6;
        mayus = true;
        espacio = 0.4;
        break;
      case 'moderno':
      default:
        break;
    }
    return BrandStyle(
      radioBoton: rb,
      radioTarjeta: rt,
      radioPequeno: rp,
      radioCampo: rc,
      tarjeta: tarjeta,
      grosorBorde: borde,
      mayusculasTitulos: mayus,
      espaciadoTitulos: espacio,
      colorSombra: sombra,
    );
  }

  BorderRadius get boton => BorderRadius.circular(radioBoton);
  BorderRadius get card => BorderRadius.circular(radioTarjeta);
  BorderRadius get pequeno => BorderRadius.circular(radioPequeno);

  /// Aplica la regla de mayúsculas del estilo (Industrial) a un título.
  String titulo(String texto) => mayusculasTitulos ? texto.toUpperCase() : texto;

  /// Decoración de tarjeta según el estilo del negocio.
  BoxDecoration decoracionTarjeta(ColorScheme s, {Color? color}) {
    final oscuro = s.brightness == Brightness.dark;
    switch (tarjeta) {
      case 'borde':
        return BoxDecoration(
          // En fondo oscuro la tarjeta se separa un poco del fondo.
          color: color ?? (oscuro ? s.surfaceContainerLow : s.surface),
          borderRadius: card,
          border: Border.all(color: s.outlineVariant, width: grosorBorde),
          boxShadow: oscuro
              ? null
              : [BoxShadow(color: colorSombra.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        );
      case 'color':
        return BoxDecoration(
          color: color ?? s.surfaceContainerHigh,
          borderRadius: card,
        );
      case 'sombra':
      default:
        return BoxDecoration(
          color: color ?? s.surfaceContainerLowest,
          borderRadius: card,
          // En fondo oscuro la sombra no se ve: se marca con un borde fino.
          border: oscuro ? Border.all(color: s.outlineVariant, width: grosorBorde) : null,
          boxShadow: [
            BoxShadow(
              color: colorSombra,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        );
    }
  }

  @override
  BrandStyle copyWith({
    double? radioBoton,
    double? radioTarjeta,
    double? radioPequeno,
    double? radioCampo,
    String? tarjeta,
    double? grosorBorde,
    bool? mayusculasTitulos,
    double? espaciadoTitulos,
    Color? colorSombra,
  }) {
    return BrandStyle(
      radioBoton: radioBoton ?? this.radioBoton,
      radioTarjeta: radioTarjeta ?? this.radioTarjeta,
      radioPequeno: radioPequeno ?? this.radioPequeno,
      radioCampo: radioCampo ?? this.radioCampo,
      tarjeta: tarjeta ?? this.tarjeta,
      grosorBorde: grosorBorde ?? this.grosorBorde,
      mayusculasTitulos: mayusculasTitulos ?? this.mayusculasTitulos,
      espaciadoTitulos: espaciadoTitulos ?? this.espaciadoTitulos,
      colorSombra: colorSombra ?? this.colorSombra,
    );
  }

  @override
  BrandStyle lerp(ThemeExtension<BrandStyle>? other, double t) {
    if (other is! BrandStyle) return this;
    return t < 0.5 ? this : other;
  }
}

extension BrandContext on BuildContext {
  BrandStyle get brand => Theme.of(this).extension<BrandStyle>() ?? BrandStyle.defecto;
}

/// Color de texto legible (blanco o casi negro) sobre [fondo].
Color colorSobre(Color fondo) =>
    fondo.computeLuminance() > 0.5 ? const Color(0xFF111111) : Colors.white;
