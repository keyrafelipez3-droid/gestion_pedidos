import '../legal/textos_legales.dart';
import 'descarga.dart';

/// Datos de la firma o aceptación que se imprimen al final del documento.
class FirmaDocumento {
  final String detalle; // por ejemplo "Firmado por Ana Pérez (CI 1234567)"
  final String fecha;
  final String version;
  const FirmaDocumento({required this.detalle, required this.fecha, required this.version});
}

/// Página lista para imprimir o "Guardar como PDF" desde el navegador.
String htmlDocumentoLegal({
  required String titulo,
  String subtitulo = '',
  List<String> resumen = const [],
  required List<SeccionLegal> secciones,
  FirmaDocumento? firma,
}) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  final cuerpo = StringBuffer();
  if (resumen.isNotEmpty) {
    cuerpo.write('<div class="resumen"><h2>En resumen</h2><ul>');
    for (final r in resumen) {
      cuerpo.write('<li>${esc(r)}</li>');
    }
    cuerpo.write('</ul></div>');
  }
  for (final s in secciones) {
    cuerpo.write('<h3>${esc(s.titulo)}</h3>');
    if (s.enSimple != null) {
      cuerpo.write('<p class="simple"><b>En simple:</b> ${esc(s.enSimple!)}</p>');
    }
    for (final p in s.parrafos) {
      cuerpo.write('<p>${esc(p)}</p>');
    }
  }
  if (firma != null) {
    cuerpo.write('<div class="firma"><b>${esc(firma.detalle)}</b><br>'
        'Fecha: ${esc(firma.fecha)} · Versión: ${esc(firma.version)}<br>'
        'Aceptación electrónica registrada en la plataforma (Ley 164).</div>');
  }
  return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(titulo)}</title>
<style>
  @page{size:A4;margin:18mm 16mm;}
  body{font-family:Arial,Helvetica,sans-serif;color:#1c1915;line-height:1.5;max-width:760px;margin:24px auto;padding:0 16px;font-size:14px}
  h1{font-size:22px;margin:0 0 4px} .sub{color:#6e6557;font-size:12px;margin:0 0 16px}
  .resumen{border:1.5px solid #c9a45c;background:#fbf6ec;border-radius:10px;padding:10px 16px;margin:12px 0 20px}
  .resumen h2{font-size:15px;margin:4px 0} .resumen li{margin:4px 0}
  h3{font-size:15px;margin:18px 0 4px} p{margin:4px 0} .simple{font-style:italic;color:#5a4a20}
  .firma{margin-top:28px;border-top:1px solid #999;padding-top:10px;font-size:13px}
  .acciones{text-align:center;margin:24px 0} .acciones button{font:700 14px Arial;padding:10px 22px;border:0;border-radius:8px;background:#1c1915;color:#fff;cursor:pointer}
  @media print{.acciones{display:none} body{margin:0;max-width:none}}
</style></head><body onload="window.print()">
<h1>${esc(titulo)}</h1>${subtitulo.isEmpty ? '' : '<p class="sub">${esc(subtitulo)}</p>'}
$cuerpo
<div class="acciones"><button onclick="window.print()">Imprimir o guardar como PDF</button></div>
</body></html>''';
}

/// Abre el documento para imprimirlo o guardarlo como PDF (versión web).
/// Devuelve false en el celular (no hay ventana de impresión).
Future<bool> imprimirDocumentoLegal({
  required String titulo,
  String subtitulo = '',
  List<String> resumen = const [],
  required List<SeccionLegal> secciones,
  FirmaDocumento? firma,
}) =>
    imprimirHtml(htmlDocumentoLegal(
      titulo: titulo,
      subtitulo: subtitulo,
      resumen: resumen,
      secciones: secciones,
      firma: firma,
    ));
