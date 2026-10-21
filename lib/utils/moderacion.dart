/// Filtro básico de lenguaje ofensivo para reseñas y comentarios.
///
/// Es una primera barrera automática, no infalible: detecta insultos
/// comunes en español (aunque tengan tildes, mayúsculas, letras repetidas
/// o números en lugar de letras) y amenazas obvias. La moderación real la
/// hace el Administrador del negocio, que puede ocultar la reseña y bloquear
/// a la cuenta.
class Moderacion {
  Moderacion._();

  static const _palabras = <String>{
    'puta', 'puto', 'putas', 'putos', 'mierda', 'carajo',
    'pendejo', 'pendeja', 'idiota', 'idiotas', 'imbecil', 'imbeciles',
    'estupido', 'estupida', 'cabron', 'cabrona', 'maricon', 'marica',
    'huevon', 'huevona', 'malparido', 'malparida', 'gilipollas', 'verga',
    'coño', 'chingar', 'chinga', 'zorra', 'inutil', 'inutiles',
    'retrasado', 'retrasada',
    'hijueputa', 'hijoputa', 'jodete', 'joder',
  };

  // Frases (sin espacios) que se buscan dentro del texto compactado.
  static const _frases = <String>[
    'hijodeputa', 'hijueputa', 'conchatumadre', 'tuputamadre', 'vetealamierda',
    'tevoyamatar', 'teatravesare', 'tevoyagolpear',
  ];

  static String _normalizar(String texto) {
    var t = texto.toLowerCase();
    const reemplazos = {
      'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u',
      '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't',
      '@': 'a', r'$': 's', '!': 'i',
    };
    reemplazos.forEach((k, v) => t = t.replaceAll(k, v));
    // Todo lo que no sea letra pasa a espacio.
    t = t.replaceAll(RegExp(r'[^a-zñ\s]'), ' ');
    // Letras repetidas ("puuuta") se reducen a una sola.
    t = t.replaceAllMapped(RegExp(r'([a-zñ])\1+'), (m) => m[1]!);
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// true si el texto contiene lenguaje que no se permite publicar.
  static bool contieneLenguajeInapropiado(String texto) {
    final normal = _normalizar(texto);
    if (normal.isEmpty) return false;
    final palabras = normal.split(' ');
    for (final p in palabras) {
      if (_palabras.contains(p)) return true;
    }
    final compacto = normal.replaceAll(' ', '');
    for (final f in _frases) {
      if (compacto.contains(f)) return true;
    }
    return false;
  }
}
