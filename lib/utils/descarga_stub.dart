/// Versión para Android/iOS/escritorio: no hay descarga directa.
Future<bool> descargarTexto(
  String nombreArchivo,
  String contenido, {
  String tipo = 'text/csv;charset=utf-8',
}) async =>
    false;

/// Versión para Android/iOS/escritorio: no hay ventana de impresión.
Future<bool> imprimirHtml(String html) async => false;
