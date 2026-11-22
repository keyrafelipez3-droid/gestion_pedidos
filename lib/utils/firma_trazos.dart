import 'dart:ui';

/// La firma dibujada se guarda como un texto corto con los trazos, en un
/// recuadro de 300 x 120 y con el formato de un "path" de SVG:
///   "M10 20 L12 22 L15 25 M40 30 L42 31"
/// (M = empieza un trazo, L = sigue la línea). Así se puede guardar en
/// Firestore, volver a dibujar en la app y poner en el PDF del acuerdo.
class FirmaTrazos {
  FirmaTrazos._();

  static const double ancho = 300;
  static const double alto = 120;
  static const int maxLargo = 20000;
  static const int minPuntos = 10;

  /// Convierte los trazos (ya en el recuadro de 300 x 120) en texto. Los
  /// puntos muy cercanos se saltan para que el texto quede corto.
  static String aTexto(List<List<Offset>> trazos) {
    final texto = StringBuffer();
    for (final trazo in trazos) {
      Offset? anterior;
      for (var i = 0; i < trazo.length; i++) {
        final p = Offset(trazo[i].dx.clamp(0, ancho), trazo[i].dy.clamp(0, alto));
        final esUltimo = i == trazo.length - 1;
        if (anterior != null && !esUltimo && (p - anterior).distance < 2) continue;
        texto.write('${anterior == null ? 'M' : 'L'}${p.dx.round()} ${p.dy.round()} ');
        anterior = p;
      }
    }
    return texto.toString().trim();
  }

  /// Lee el texto guardado y devuelve los trazos para dibujarlos.
  static List<List<Offset>> desdeTexto(String texto) {
    final trazos = <List<Offset>>[];
    for (final m in RegExp(r'([ML])(\d+) (\d+)').allMatches(texto)) {
      final p = Offset(double.parse(m[2]!), double.parse(m[3]!));
      if (m[1] == 'M' || trazos.isEmpty) {
        trazos.add([p]);
      } else {
        trazos.last.add(p);
      }
    }
    return trazos;
  }

  /// true si el texto tiene el formato correcto y suficientes puntos (un
  /// punto o una rayita no cuentan como firma). Las reglas de Firestore
  /// revisan lo mismo.
  static bool esValida(String texto) {
    if (texto.length > maxLargo || !RegExp(r'^[ML0-9 ]+$').hasMatch(texto)) return false;
    final puntos = desdeTexto(texto).fold<int>(0, (suma, t) => suma + t.length);
    return puntos >= minPuntos;
  }
}
