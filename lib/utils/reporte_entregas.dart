import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/pedido_models.dart';
import '../models/usuario_model.dart';
import 'descarga.dart';
import 'formato.dart';

/// Qué columnas ve cada rol en el reporte de entregas realizadas:
/// - negocio (Administrador y Cajero): cliente, repartidor, pago y total.
/// - cocina: los productos de cada pedido, sin montos.
/// - repartidor: sus entregas, lo cobrado y sus propinas.
enum AlcanceEntregas { negocio, cocina, repartidor }

AlcanceEntregas alcanceDelRol(String rol) => switch (rol) {
      Rol.cocina => AlcanceEntregas.cocina,
      Rol.repartidor => AlcanceEntregas.repartidor,
      _ => AlcanceEntregas.negocio,
    };

/// Reporte de entregas realizadas, listo para Word (.docx) o para imprimir.
class ReporteEntregas {
  final String negocio;
  final String periodo;

  /// Quién lo genera (va en el pie, junto a la firma).
  final String persona;
  final String rol;
  final List<PedidoModel> pedidos;
  final AlcanceEntregas alcance;
  final Map<String, String> nombresSucursal;
  final DateTime generado;

  ReporteEntregas({
    required this.negocio,
    required this.periodo,
    required this.persona,
    required this.rol,
    required List<PedidoModel> pedidos,
    required this.alcance,
    this.nombresSucursal = const {},
    DateTime? generado,
  })  : pedidos = (List.of(pedidos.where((p) => p.estado == PedidoEstado.entregado))
          ..sort((a, b) => (a.fechaCreacion ?? DateTime(0)).compareTo(b.fechaCreacion ?? DateTime(0)))),
        generado = generado ?? DateTime.now();

  static String _dos(int n) => n.toString().padLeft(2, '0');
  static String fecha(DateTime d) => '${_dos(d.day)}/${_dos(d.month)}/${d.year}';
  static String hora(DateTime d) => '${_dos(d.hour)}:${_dos(d.minute)}';

  String get titulo => 'Reporte de entregas realizadas';

  String get nombreArchivo {
    final g = generado;
    return 'entregas_${g.year}-${_dos(g.month)}-${_dos(g.day)}_${_dos(g.hour)}${_dos(g.minute)}.docx';
  }

  List<String> get columnas => switch (alcance) {
        AlcanceEntregas.negocio => [
            'N°', 'Fecha', 'Hora', 'Pedido', 'Sucursal', 'Modalidad', 'Cliente', 'Repartidor',
            'Pago', 'Total (${simboloMoneda()})',
          ],
        AlcanceEntregas.cocina => ['N°', 'Fecha', 'Hora', 'Pedido', 'Modalidad', 'Productos'],
        AlcanceEntregas.repartidor => [
            'N°', 'Fecha', 'Hora', 'Pedido', 'Cliente', 'Zona', 'Pago',
            'Cobrado (${simboloMoneda()})', 'Propina (${simboloMoneda()})',
          ],
      };

  static String _monto(double v) => v.toStringAsFixed(2);

  static String _productos(PedidoModel p) =>
      p.lineas.map((l) => '${l.cantidad} × ${l.nombreProducto}').join(', ');

  List<List<String>> get filas {
    final lista = <List<String>>[];
    for (var i = 0; i < pedidos.length; i++) {
      final p = pedidos[i];
      final f = p.fechaCreacion;
      final comun = [
        '${i + 1}',
        f == null ? '' : fecha(f),
        f == null ? '' : hora(f),
        '#${p.id.length >= 6 ? p.id.substring(0, 6).toUpperCase() : p.id}',
      ];
      final cliente = (p.nombreCliente ?? '').trim().isNotEmpty
          ? p.nombreCliente!.trim()
          : (p.modalidad == PedidoModalidad.mesa ? p.etiquetaModalidad : '—');
      lista.add(switch (alcance) {
        AlcanceEntregas.negocio => [
            ...comun,
            nombresSucursal[p.idSucursal] ?? '',
            p.etiquetaModalidad,
            cliente,
            (p.nombreRepartidor ?? '').trim().isEmpty ? '—' : p.nombreRepartidor!.trim(),
            p.metodoPago,
            _monto(p.montoNegocio),
          ],
        AlcanceEntregas.cocina => [...comun, p.etiquetaModalidad, _productos(p)],
        AlcanceEntregas.repartidor => [
            ...comun,
            cliente,
            (p.zonaEntrega ?? '').trim().isEmpty ? '—' : p.zonaEntrega!.trim(),
            p.metodoPago,
            _monto(p.montoNegocio + p.propina),
            _monto(p.propina),
          ],
      });
    }
    return lista;
  }

  /// Fila de totales (o null si el rol no ve montos).
  List<String>? get totales {
    double suma(double Function(PedidoModel) v) => pedidos.fold(0.0, (a, p) => a + v(p));
    final n = columnas.length;
    return switch (alcance) {
      AlcanceEntregas.cocina => null,
      AlcanceEntregas.negocio => [
          'TOTAL', for (var i = 1; i < n - 1; i++) '', _monto(suma((p) => p.montoNegocio)),
        ],
      AlcanceEntregas.repartidor => [
          'TOTAL', for (var i = 1; i < n - 2; i++) '',
          _monto(suma((p) => p.montoNegocio + p.propina)), _monto(suma((p) => p.propina)),
        ],
    };
  }

  List<String> get datosCabecera => [
        if (negocio.trim().isNotEmpty) 'Restaurante: ${negocio.trim()}',
        'Periodo: $periodo',
        'Generado por: $persona ($rol)',
        'Fecha de emisión: ${fecha(generado)} ${hora(generado)}',
        'Total de entregas: ${pedidos.length}',
      ];
}

// ------------------------------------------------------------- imprimir

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// Página lista para imprimir o "Guardar como PDF" desde el navegador.
String htmlEntregas(ReporteEntregas r) {
  final b = StringBuffer();
  b.write('<table><thead><tr>');
  for (final c in r.columnas) {
    b.write('<th>${_esc(c)}</th>');
  }
  b.write('</tr></thead><tbody>');
  if (r.pedidos.isEmpty) {
    b.write('<tr><td colspan="${r.columnas.length}" class="vacio">No hay entregas realizadas en este periodo.</td></tr>');
  }
  for (final f in r.filas) {
    b.write('<tr>${f.map((c) => '<td>${_esc(c)}</td>').join()}</tr>');
  }
  final t = r.totales;
  if (t != null && r.pedidos.isNotEmpty) {
    b.write('<tr class="total">${t.map((c) => '<td>${_esc(c)}</td>').join()}</tr>');
  }
  b.write('</tbody></table>');
  return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(r.titulo)}</title>
<style>
  @page{size:A4 landscape;margin:14mm 12mm;}
  body{font-family:Arial,Helvetica,sans-serif;color:#1c1915;font-size:12px;margin:24px auto;max-width:1100px;padding:0 16px}
  h1{font-size:20px;margin:0 0 8px;text-align:center;text-transform:uppercase;letter-spacing:.5px}
  .datos{margin:0 0 14px;line-height:1.6}
  table{width:100%;border-collapse:collapse}
  th,td{border:1px solid #8a8070;padding:5px 6px;text-align:left;vertical-align:top}
  th{background:#efe6d2;font-weight:700}
  tr.total td{font-weight:700;background:#f6f1e6}
  td.vacio{text-align:center;color:#6e6557;padding:18px}
  .firmas{display:flex;gap:48px;margin-top:56px}
  .firmas div{flex:1;text-align:center;border-top:1px solid #1c1915;padding-top:6px}
  .acciones{text-align:center;margin:24px 0} .acciones button{font:700 14px Arial;padding:10px 22px;border:0;border-radius:8px;background:#1c1915;color:#fff;cursor:pointer}
  @media print{.acciones{display:none} body{margin:0;max-width:none}}
</style></head><body onload="window.print()">
<h1>${_esc(r.titulo)}</h1>
<div class="datos">${r.datosCabecera.map(_esc).join('<br>')}</div>
$b
<div class="firmas"><div>Entregado por<br>${_esc(r.persona)} (${_esc(r.rol)})</div><div>Recibido / revisado por<br>Nombre y firma</div></div>
<div class="acciones"><button onclick="window.print()">Imprimir o guardar como PDF</button></div>
</body></html>''';
}

// ----------------------------------------------------------------- Word

String _p(String texto, {bool negrita = false, int tamano = 20, String alinear = 'left', int despues = 60}) =>
    '<w:p><w:pPr><w:spacing w:after="$despues"/><w:jc w:val="$alinear"/></w:pPr>'
    '<w:r><w:rPr>${negrita ? '<w:b/>' : ''}<w:sz w:val="$tamano"/></w:rPr>'
    '<w:t xml:space="preserve">${_esc(texto)}</w:t></w:r></w:p>';

String _celda(String texto, {bool negrita = false, String? fondo}) =>
    '<w:tc><w:tcPr>${fondo == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="$fondo"/>'}</w:tcPr>'
    '<w:p><w:pPr><w:spacing w:after="0"/></w:pPr><w:r><w:rPr>${negrita ? '<w:b/>' : ''}<w:sz w:val="18"/></w:rPr>'
    '<w:t xml:space="preserve">${_esc(texto)}</w:t></w:r></w:p></w:tc>';

String _fila(List<String> celdas, {bool negrita = false, String? fondo, bool encabezado = false}) =>
    '<w:tr>${encabezado ? '<w:trPr><w:tblHeader/></w:trPr>' : ''}'
    '${celdas.map((c) => _celda(c, negrita: negrita, fondo: fondo)).join()}</w:tr>';

/// Documento de Word (.docx) del reporte: hoja horizontal, tabla con
/// bordes, totales y espacio para las firmas. Se abre en Word, Google Docs
/// o LibreOffice.
Uint8List docxEntregas(ReporteEntregas r) {
  final cuerpo = StringBuffer()
    ..write(_p(r.titulo.toUpperCase(), negrita: true, tamano: 30, alinear: 'center', despues: 200));
  for (final d in r.datosCabecera) {
    cuerpo.write(_p(d));
  }
  cuerpo.write(_p('', despues: 120));
  const borde = '<w:top w:val="single" w:sz="4" w:color="8A8070"/>'
      '<w:left w:val="single" w:sz="4" w:color="8A8070"/>'
      '<w:bottom w:val="single" w:sz="4" w:color="8A8070"/>'
      '<w:right w:val="single" w:sz="4" w:color="8A8070"/>'
      '<w:insideH w:val="single" w:sz="4" w:color="8A8070"/>'
      '<w:insideV w:val="single" w:sz="4" w:color="8A8070"/>';
  cuerpo.write('<w:tbl><w:tblPr><w:tblW w:w="5000" w:type="pct"/><w:tblBorders>$borde</w:tblBorders>'
      '<w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar></w:tblPr>');
  cuerpo.write(_fila(r.columnas, negrita: true, fondo: 'EFE6D2', encabezado: true));
  if (r.pedidos.isEmpty) {
    cuerpo.write(_fila(['No hay entregas realizadas en este periodo.',
      for (var i = 1; i < r.columnas.length; i++) '']));
  }
  for (final f in r.filas) {
    cuerpo.write(_fila(f));
  }
  final t = r.totales;
  if (t != null && r.pedidos.isNotEmpty) cuerpo.write(_fila(t, negrita: true, fondo: 'F6F1E6'));
  cuerpo.write('</w:tbl>');
  // Firmas.
  cuerpo.write(_p('', despues: 900));
  cuerpo.write(_p('________________________________          ________________________________',
      alinear: 'center', despues: 0));
  cuerpo.write(_p('Entregado por: ${r.persona} (${r.rol})          Recibido / revisado por: nombre y firma',
      alinear: 'center'));
  final documento = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>'
      '$cuerpo'
      '<w:sectPr><w:pgSz w:w="16838" w:h="11906" w:orient="landscape"/>'
      '<w:pgMar w:top="850" w:right="850" w:bottom="850" w:left="850" w:header="400" w:footer="400" w:gutter="0"/>'
      '</w:sectPr></w:body></w:document>';
  final archivos = <String, String>{
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>',
    'word/document.xml': documento,
  };
  final zip = Archive();
  archivos.forEach((nombre, contenido) {
    final bytes = utf8.encode(contenido);
    zip.addFile(ArchiveFile(nombre, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(zip));
}

/// Descarga el Word (navegador). Devuelve false en el celular.
Future<bool> descargarWordEntregas(ReporteEntregas r) => descargarBytes(
      r.nombreArchivo,
      docxEntregas(r),
      tipo: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    );

/// Abre la página para imprimir (navegador). Devuelve false en el celular.
Future<bool> imprimirEntregas(ReporteEntregas r) => imprimirHtml(htmlEntregas(r));
