import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los códigos internos de las historias de usuario ("HU-08") no deben
/// verse en la app: solo pueden quedar en comentarios del código.
void main() {
  test('ningún texto visible lleva un código HU-número', () {
    final codigo = RegExp(r'HU-?\d');
    final hallazgos = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        // Se quita el comentario de la línea antes de buscar.
        final sinComentario = lineas[i].split('//').first;
        if (codigo.hasMatch(sinComentario)) hallazgos.add('${f.path}:${i + 1}');
      }
    }
    expect(hallazgos, isEmpty);
  });
}
