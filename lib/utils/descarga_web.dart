import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Descarga [contenido] como un archivo llamado [nombreArchivo].
Future<bool> descargarTexto(
  String nombreArchivo,
  String contenido, {
  String tipo = 'text/csv;charset=utf-8',
}) async {
  final url = _urlDe(contenido, tipo);
  final enlace = web.HTMLAnchorElement()
    ..href = url
    ..download = nombreArchivo
    ..style.display = 'none';
  web.document.body?.appendChild(enlace);
  enlace.click();
  enlace.remove();
  // Se libera un momento después, cuando el navegador ya tomó el archivo.
  Future.delayed(const Duration(seconds: 2), () => web.URL.revokeObjectURL(url));
  return true;
}

/// Abre [html] en una pestaña nueva; la propia página llama a imprimir
/// (desde ahí también se puede "Guardar como PDF").
Future<bool> imprimirHtml(String html) async {
  final url = _urlDe(html, 'text/html;charset=utf-8');
  final ventana = web.window.open(url, '_blank');
  return ventana != null;
}

String _urlDe(String contenido, String tipo) {
  final bytes = utf8.encode(contenido);
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: tipo),
  );
  return web.URL.createObjectURL(blob);
}
