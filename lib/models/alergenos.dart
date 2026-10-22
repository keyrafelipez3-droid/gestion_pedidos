import '../l10n/idioma.dart';

/// Un alérgeno o ingrediente que el cliente no puede comer.
///
/// Se guarda en Firestore solo el [codigo] (por ejemplo `cebolla`), nunca
/// el texto: así la cocina lo ve siempre en español y el cliente en su
/// idioma, sin depender de una traducción automática.
class Alergeno {
  final String codigo;
  final String nombre; // en español; se traduce con tr()
  final String emoji;
  const Alergeno(this.codigo, this.nombre, this.emoji);

  /// Nombre en el idioma de quien está mirando la pantalla.
  String get etiqueta => tr(nombre);
}

class Alergenos {
  Alergenos._();

  static const todos = <Alergeno>[
    Alergeno('mani', 'Maní', '🥜'),
    Alergeno('frutos_secos', 'Frutos secos', '🌰'),
    Alergeno('gluten', 'Gluten (trigo)', '🌾'),
    Alergeno('lacteos', 'Lácteos', '🥛'),
    Alergeno('huevo', 'Huevo', '🥚'),
    Alergeno('mariscos', 'Mariscos', '🦐'),
    Alergeno('pescado', 'Pescado', '🐟'),
    Alergeno('soya', 'Soya', '🫘'),
    Alergeno('sesamo', 'Sésamo', '🌱'),
    Alergeno('cebolla', 'Cebolla', '🧅'),
    Alergeno('tomate', 'Tomate', '🍅'),
    Alergeno('ajo', 'Ajo', '🧄'),
    Alergeno('picante', 'Picante / ají', '🌶️'),
  ];

  static Alergeno? porCodigo(String codigo) {
    for (final a in todos) {
      if (a.codigo == codigo) return a;
    }
    return null;
  }

  /// Deja solo códigos conocidos, sin repetir y en el orden del catálogo.
  static List<String> ordenar(Iterable<String> codigos) {
    final set = codigos.toSet();
    return [for (final a in todos) if (set.contains(a.codigo)) a.codigo];
  }

  /// Lee una lista guardada en Firestore (ignora valores raros).
  static List<String> desdeFirestore(Object? valor) =>
      valor is List ? ordenar(valor.whereType<String>()) : const [];

  /// "Maní, Cebolla" en el idioma de quien mira.
  static String nombres(Iterable<String> codigos) =>
      ordenar(codigos).map((c) => porCodigo(c)!.etiqueta).join(', ');

  /// Alérgenos que están en las dos listas (lo que el producto contiene y
  /// el cliente no puede comer).
  static List<String> enComun(Iterable<String> a, Iterable<String> b) {
    final setB = b.toSet();
    return ordenar(a.where(setB.contains));
  }
}
