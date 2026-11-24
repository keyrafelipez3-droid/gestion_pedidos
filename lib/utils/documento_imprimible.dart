import '../legal/textos_legales.dart';
import '../models/pais.dart';
import '../services/sesion_actual.dart';
import 'descarga.dart';

/// Datos de la firma o aceptación electrónica que se imprimen al final del
/// documento (por ejemplo, el acuerdo del personal ya firmado en la app).
class FirmaDocumento {
  final String detalle; // por ejemplo "Firmado por Ana Pérez (CI 1234567)"
  final String fecha;
  final String version;
  final String trazos; // firma dibujada (ver FirmaTrazos); vacío si no hay
  const FirmaDocumento({
    required this.detalle,
    required this.fecha,
    required this.version,
    this.trazos = '',
  });
}

/// Espacio en blanco para firmar a mano el documento impreso: lugar y
/// fecha, nombre, documento de identidad, cargo y la línea de la firma.
/// Lo que ya se sabe (nombre y rol de quien imprime) va escrito.
class EspacioFirma {
  final String nombre;
  final String rol;
  final String documentoIdentidad; // "carnet de identidad", "INE"...
  const EspacioFirma({this.nombre = '', this.rol = '', this.documentoIdentidad = 'documento de identidad'});
}

/// Espacio para firmar de quien tiene la sesión abierta. Todos los roles
/// lo tienen menos el SuperAdmin (titular de la plataforma, que no firma
/// estos documentos). Sin sesión (por ejemplo, desde el inicio de sesión)
/// el espacio va en blanco.
EspacioFirma? espacioFirmaDeLaSesion() {
  final u = SesionActual.instancia.actual;
  if (u != null && u.esSuperAdmin) return null;
  return EspacioFirma(
    nombre: u?.nombre ?? '',
    rol: u?.rol ?? '',
    documentoIdentidad: Paises.actual.docIdentidad,
  );
}

/// Página formal lista para imprimir (o "Guardar como PDF") y firmar en
/// papel: título en mayúsculas, texto justificado, cláusulas y, al final,
/// la firma electrónica registrada y/o el espacio para firmar a mano. Sin
/// los "En simple" de la pantalla.
String htmlDocumentoLegal({
  required String titulo,
  String subtitulo = '',
  required List<SeccionLegal> secciones,
  FirmaDocumento? firma,
  EspacioFirma? espacioFirma,
}) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String linea(String valor) => valor.trim().isEmpty
      ? '<span class="blanco"></span>'
      : '<span class="dato">${esc(valor.trim())}</span>';
  final cuerpo = StringBuffer();
  for (final s in secciones) {
    cuerpo.write('<h3>${esc(s.titulo)}</h3>');
    for (final p in s.parrafos) {
      cuerpo.write('<p>${esc(p)}</p>');
    }
  }
  if (firma != null) {
    cuerpo.write('<div class="firma-electronica">');
    if (firma.trazos.isNotEmpty) {
      cuerpo.write('<svg viewBox="0 0 300 120" width="240" height="96"><path d="${esc(firma.trazos)}" '
          'fill="none" stroke="#1c1915" stroke-width="2.5" stroke-linecap="round" '
          'stroke-linejoin="round"/></svg><br>');
    }
    cuerpo.write('<b>${esc(firma.detalle)}</b><br>'
        'Fecha: ${esc(firma.fecha)} · Versión: ${esc(firma.version)}<br>'
        'Aceptación electrónica registrada en la plataforma (Ley 164).</div>');
  }
  final e = espacioFirma;
  if (e != null) {
    cuerpo.write('<div class="firma-papel">'
        '<p class="constancia">En señal de conformidad con todas y cada una de las cláusulas del '
        'presente documento, firma a continuación:</p>'
        '<table>'
        '<tr><td>Lugar y fecha:</td><td>${linea('')}</td></tr>'
        '<tr><td>Nombre completo:</td><td>${linea(e.nombre)}</td></tr>'
        '<tr><td>${esc(_mayuscula(e.documentoIdentidad))}:</td><td>${linea('')}</td></tr>'
        '<tr><td>Rol en la plataforma:</td><td>${linea(e.rol)}</td></tr>'
        '</table>'
        '<div class="raya">Firma</div>'
        '</div>');
  }
  return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(titulo)}</title>
<style>
  @page{size:A4;margin:25mm 22mm 22mm 25mm;}
  body{font-family:"Times New Roman",Times,serif;color:#111;line-height:1.55;max-width:760px;margin:24px auto;padding:0 16px;font-size:12pt}
  h1{font-size:15pt;margin:0 0 4px;text-align:center;text-transform:uppercase;letter-spacing:.5px}
  .sub{text-align:center;font-size:10.5pt;margin:0 0 22px}
  h3{font-size:12pt;margin:16px 0 4px;text-transform:uppercase}
  p{margin:4px 0;text-align:justify}
  .firma-electronica{margin-top:28px;border-top:1px solid #999;padding-top:10px;font-size:11pt}
  .firma-papel{margin-top:36px;page-break-inside:avoid}
  .firma-papel table{border-collapse:collapse;margin-top:12px;width:100%}
  .firma-papel td{padding:10px 6px 4px 0;vertical-align:bottom}
  .firma-papel td:first-child{width:190px;white-space:nowrap}
  .blanco{display:inline-block;width:100%;border-bottom:1px solid #111;height:1.2em}
  .dato{display:inline-block;width:100%;border-bottom:1px solid #111}
  .raya{width:300px;margin:80px auto 0;border-top:1px solid #111;text-align:center;padding-top:4px}
  .acciones{text-align:center;margin:24px 0} .acciones button{font:700 14px Arial;padding:10px 22px;border:0;border-radius:8px;background:#1c1915;color:#fff;cursor:pointer}
  @media print{.acciones{display:none} body{margin:0;max-width:none}}
</style></head><body onload="window.print()">
<h1>${esc(titulo)}</h1>${subtitulo.isEmpty ? '' : '<p class="sub">${esc(subtitulo)}</p>'}
$cuerpo
<div class="acciones"><button onclick="window.print()">Imprimir o guardar como PDF</button></div>
</body></html>''';
}

String _mayuscula(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Abre el documento para imprimirlo o guardarlo como PDF (versión web).
/// Devuelve false en el celular (no hay ventana de impresión).
Future<bool> imprimirDocumentoLegal({
  required String titulo,
  String subtitulo = '',
  required List<SeccionLegal> secciones,
  FirmaDocumento? firma,
  EspacioFirma? espacioFirma,
}) =>
    imprimirHtml(htmlDocumentoLegal(
      titulo: titulo,
      subtitulo: subtitulo,
      secciones: secciones,
      firma: firma,
      espacioFirma: espacioFirma,
    ));
