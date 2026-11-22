import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/l10n/traducciones_en.dart';
import 'package:gestion_pedidos/l10n/traducciones_fr.dart';
import 'package:gestion_pedidos/l10n/traducciones_pt.dart';

/// Revisa que todos los textos de la parte del cliente que pasan por tr()
/// tengan traducción en inglés, portugués y francés.
///
/// El panel del personal (Administrador, Cajero, Cocina, Repartidor y
/// SuperAdmin) se queda solo en español, por eso esas carpetas no se revisan.
const carpetasDelPersonal = ['admin', 'cajero', 'cocina', 'repartidor', 'superadmin'];

const idiomas = {
  'en': traduccionesEn,
  'pt': traduccionesPt,
  'fr': traduccionesFr,
};

// Un texto entre comillas simples o dobles, como se escribe en Dart.
final literal = RegExp(r'''(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")''');

// tr( seguido de uno o más textos pegados ('...' '...').
final llamadaTr = RegExp(r'''\btr\(\s*((?:(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*")\s*)+)''');

/// Junta los pedazos de texto y quita las barras de escape (\' → ').
String unirTexto(String bloque) {
  final texto = StringBuffer();
  for (final m in literal.allMatches(bloque)) {
    final pedazo = m.group(0)!;
    texto.write(pedazo.substring(1, pedazo.length - 1));
  }
  return texto.toString().replaceAllMapped(RegExp(r'\\(.)'), (m) {
    if (m[1] == 'n') return '\n';
    return m[1]!;
  });
}

bool esDelPersonal(String ruta) {
  final r = ruta.replaceAll('\\', '/');
  return carpetasDelPersonal.any((c) => r.contains('lib/screens/$c/'));
}

/// Textos usados con tr() en la parte del cliente, con el archivo donde están.
Map<String, String> textosDelCliente() {
  final textos = <String, String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    final ruta = f.path.replaceAll('\\', '/');
    if (f is! File || !ruta.endsWith('.dart')) continue;
    if (ruta.contains('lib/l10n/') || esDelPersonal(ruta)) continue;
    for (final m in llamadaTr.allMatches(f.readAsStringSync())) {
      textos.putIfAbsent(unirTexto(m.group(1)!), () => ruta);
    }
  }
  return textos;
}

void main() {
  final textos = textosDelCliente();

  test('se encontraron textos para revisar', () {
    expect(textos.length, greaterThan(100));
  });

  for (final idioma in idiomas.entries) {
    test('todos los textos del cliente están en ${idioma.key}', () {
      final faltan = [
        for (final t in textos.entries)
          if (!idioma.value.containsKey(t.key)) '${t.value}: "${t.key}"',
      ];
      expect(faltan, isEmpty, reason: 'Falta traducir al ${idioma.key}:\n${faltan.join('\n')}');
    });

    test('las traducciones al ${idioma.key} conservan los datos entre llaves', () {
      final llaves = RegExp(r'\{\w+\}');
      final mal = <String>[];
      idioma.value.forEach((es, traducido) {
        final a = llaves.allMatches(es).map((m) => m[0]).toSet();
        final b = llaves.allMatches(traducido).map((m) => m[0]).toSet();
        if (a.length != b.length || !a.containsAll(b)) mal.add(es);
      });
      expect(mal, isEmpty, reason: 'Revisa las llaves {…} en:\n${mal.join('\n')}');
    });
  }
}
