/// Sonido corto de aviso (pedido nuevo). En el navegador reproduce el
/// archivo `assets/sonidos/nuevo_pedido.wav`; en Android/iOS usa el sonido
/// y la vibración del sistema.
library;

export 'sonido_stub.dart' if (dart.library.js_interop) 'sonido_web.dart';
