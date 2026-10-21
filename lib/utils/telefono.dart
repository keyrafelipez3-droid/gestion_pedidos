import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../l10n/idioma.dart';

/// País disponible para ingresar un número de teléfono.
class PaisTelefono {
  final String nombre;
  final String iso;
  final String codigo; // código de marcación, sin '+'

  const PaisTelefono(this.nombre, this.iso, this.codigo);

  String get etiqueta => '${tr(nombre)} (+$codigo)';
}

/// Utilidades para guardar y validar teléfonos en formato internacional
/// (E.164, por ejemplo +59171234567), según el plan de numeración de cada país.
class Telefono {
  Telefono._();

  static const bolivia = PaisTelefono('Bolivia', 'BO', '591');

  /// Lista de países. Los códigos de marcación son únicos para poder
  /// reconocer el país a partir de un número guardado.
  static const paises = <PaisTelefono>[
    bolivia,
    PaisTelefono('Argentina', 'AR', '54'),
    PaisTelefono('Brasil', 'BR', '55'),
    PaisTelefono('Chile', 'CL', '56'),
    PaisTelefono('Colombia', 'CO', '57'),
    PaisTelefono('Costa Rica', 'CR', '506'),
    PaisTelefono('Ecuador', 'EC', '593'),
    PaisTelefono('El Salvador', 'SV', '503'),
    PaisTelefono('España', 'ES', '34'),
    PaisTelefono('Estados Unidos / Canadá', 'US', '1'),
    PaisTelefono('Guatemala', 'GT', '502'),
    PaisTelefono('Honduras', 'HN', '504'),
    PaisTelefono('México', 'MX', '52'),
    PaisTelefono('Nicaragua', 'NI', '505'),
    PaisTelefono('Panamá', 'PA', '507'),
    PaisTelefono('Paraguay', 'PY', '595'),
    PaisTelefono('Perú', 'PE', '51'),
    PaisTelefono('Uruguay', 'UY', '598'),
    PaisTelefono('Venezuela', 'VE', '58'),
    PaisTelefono('Alemania', 'DE', '49'),
    PaisTelefono('Francia', 'FR', '33'),
    PaisTelefono('Italia', 'IT', '39'),
    PaisTelefono('Portugal', 'PT', '351'),
    PaisTelefono('Reino Unido', 'GB', '44'),
  ];

  static String _soloDigitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Arma el valor a guardar: '+<código><número>'. Devuelve '' si no hay número.
  static String componer(PaisTelefono pais, String numeroLocal) {
    final digitos = _soloDigitos(numeroLocal);
    if (digitos.isEmpty) return '';
    return '+${pais.codigo}$digitos';
  }

  /// Separa un valor guardado en país y número local. Los números antiguos
  /// guardados sin '+' se consideran de Bolivia.
  static ({PaisTelefono pais, String numero}) separar(String valor) {
    final texto = valor.trim();
    if (texto.startsWith('+')) {
      final digitos = _soloDigitos(texto);
      // Se prueba primero el código más largo (3 dígitos, luego 2, luego 1).
      for (final largo in [3, 2, 1]) {
        if (digitos.length <= largo) continue;
        final codigo = digitos.substring(0, largo);
        for (final p in paises) {
          if (p.codigo == codigo) {
            return (pais: p, numero: digitos.substring(largo));
          }
        }
      }
    }
    return (pais: bolivia, numero: _soloDigitos(texto));
  }

  /// Valida el número local para el país elegido. Devuelve el mensaje de
  /// error, o null si es válido (o si está vacío y no es obligatorio).
  static String? validar(
    PaisTelefono pais,
    String numeroLocal, {
    required bool obligatorio,
  }) {
    final digitos = _soloDigitos(numeroLocal);
    if (digitos.isEmpty) {
      return obligatorio ? tr('Ingresa el teléfono') : null;
    }
    try {
      final numero = PhoneNumber.parse('+${pais.codigo}$digitos');
      if (!numero.isValid()) {
        return tr('Número no válido para {nombre}', {'nombre': tr(pais.nombre)});
      }
    } catch (_) {
      return tr('Número no válido para {nombre}', {'nombre': tr(pais.nombre)});
    }
    return null;
  }
}
