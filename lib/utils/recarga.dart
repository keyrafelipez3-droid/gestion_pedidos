/// Recargar la página en la versión web (para tomar la versión nueva).
/// En Android/iOS devuelve `false`.
library;

export 'recarga_stub.dart' if (dart.library.js_interop) 'recarga_web.dart';
