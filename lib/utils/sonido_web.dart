import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// En web, los archivos de `assets/` se publican bajo `assets/assets/`.
Future<void> sonarAvisoPedido() async {
  try {
    final audio = web.HTMLAudioElement()
      ..src = 'assets/assets/sonidos/nuevo_pedido.wav'
      ..volume = 0.8;
    await audio.play().toDart;
  } catch (_) {
    // El navegador puede bloquear el sonido si la persona todavía no tocó
    // la página; el aviso visual se muestra igual.
  }
}
