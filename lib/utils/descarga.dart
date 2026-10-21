/// Descargar archivos e imprimir desde la app.
///
/// En el navegador usa las funciones del propio navegador (descarga y
/// ventana de impresión). En Android/iOS/escritorio devuelve `false` y
/// quien lo llama ofrece una alternativa (por ejemplo, copiar al
/// portapapeles).
library;

export 'descarga_stub.dart' if (dart.library.js_interop) 'descarga_web.dart';
