import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Traduce los textos libres que escribe el cliente (notas del pedido,
/// referencia de la dirección) al idioma de quien los lee, normalmente el
/// español del personal.
///
/// Usa el servicio gratuito configurado en [AppConfig.traductorUrl]. Si no
/// responde (sin internet, límite diario agotado, etc.) devuelve null y la
/// pantalla muestra el texto original con un enlace a Google Traductor.
///
/// Las alergias NO pasan por aquí: se eligen de una lista fija
/// (`Alergenos`) y se muestran siempre correctas en cada idioma.
class TraduccionService {
  TraduccionService._();
  static final instancia = TraduccionService._();

  /// Cada texto se traduce una sola vez por sesión (las pantallas del
  /// personal se redibujan seguido y no conviene gastar el límite).
  final _cache = <String, Future<String?>>{};

  static const nombresIdioma = {
    'es': 'español',
    'en': 'inglés',
    'pt': 'portugués',
    'fr': 'francés',
  };

  Future<String?> traducir(String texto, {required String desde, required String hacia}) {
    final limpio = texto.trim();
    if (limpio.isEmpty || desde == hacia) return Future.value(null);
    final clave = '$desde|$hacia|$limpio';
    return _cache.putIfAbsent(clave, () async {
      final resultado = await _traducirTodo(limpio, desde, hacia);
      // Si falló, se permite reintentar más tarde.
      if (resultado == null) _cache.remove(clave);
      return resultado;
    });
  }

  Future<String?> _traducirTodo(String texto, String desde, String hacia) async {
    try {
      final partes = <String>[];
      for (final trozo in _trozos(texto)) {
        final t = await _pedir(trozo, desde, hacia);
        if (t == null) return null;
        partes.add(t);
      }
      return partes.join(' ');
    } catch (_) {
      return null;
    }
  }

  Future<String?> _pedir(String texto, String desde, String hacia) async {
    final uri = Uri.parse(AppConfig.traductorUrl).replace(queryParameters: {
      'q': texto,
      'langpair': '$desde|$hacia',
      if (AppConfig.traductorCorreo.isNotEmpty) 'de': AppConfig.traductorCorreo,
    });
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final datos = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final estado = '${datos['responseStatus']}';
    final traducido = (datos['responseData'] as Map?)?['translatedText'] as String?;
    if (estado != '200' || traducido == null || traducido.trim().isEmpty) return null;
    // Cuando se agota el límite, el servicio responde con un aviso en vez
    // de la traducción.
    if (traducido.toUpperCase().contains('MYMEMORY WARNING')) return null;
    return traducido.trim();
  }

  /// El servicio acepta hasta 500 bytes por consulta: se corta por
  /// palabras en trozos más chicos.
  static List<String> _trozos(String texto) {
    const maxBytes = 450;
    final trozos = <String>[];
    var actual = StringBuffer();
    for (final palabra in texto.split(RegExp(r'\s+'))) {
      final candidato = actual.isEmpty ? palabra : '${actual.toString()} $palabra';
      if (utf8.encode(candidato).length > maxBytes && actual.isNotEmpty) {
        trozos.add(actual.toString());
        actual = StringBuffer(palabra);
      } else {
        actual = StringBuffer(candidato);
      }
    }
    if (actual.isNotEmpty) trozos.add(actual.toString());
    return trozos;
  }

  /// Enlace para abrir el texto en Google Traductor (plan B).
  static Uri enlaceGoogle(String texto, {required String desde, required String hacia}) =>
      Uri.https('translate.google.com', '/', {
        'sl': desde,
        'tl': hacia,
        'text': texto,
        'op': 'translate',
      });
}
