import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pedido_models.dart';
import 'descarga.dart';
import 'reporte_csv.dart';

/// Reporte de ventas como archivo de Excel de verdad (.xlsx): columnas
/// separadas, fechas y montos como números (se pueden sumar y filtrar),
/// encabezado fijo con filtros, fila de totales y una hoja "Resumen".
/// Se abre igual en cualquier Excel (español o inglés), Google Sheets o
/// LibreOffice, sin configurar nada.
Uint8List excelVentas(
  List<PedidoModel> pedidos, {
  Map<String, String> nombresSucursal = const {},
  String titulo = 'Reporte de ventas',
  String periodo = '',
}) {
  final ordenados = List.of(pedidos)
    ..sort((a, b) => (a.fechaCreacion ?? DateTime(0)).compareTo(b.fechaCreacion ?? DateTime(0)));
  final ahora = DateTime.now();
  String dos(int n) => n.toString().padLeft(2, '0');
  String sucursal(PedidoModel p) => nombresSucursal[p.idSucursal] ?? p.idSucursal;

  // ---------------------------------------------------------------- Ventas
  final hoja = _Hoja();
  hoja.fila([_texto(titulo, _E.titulo)]);
  hoja.fila([
    _texto(
      '${periodo.isEmpty ? '' : '$periodo · '}${ordenados.length} pedidos · '
      'generado el ${dos(ahora.day)}/${dos(ahora.month)}/${ahora.year} ${dos(ahora.hour)}:${dos(ahora.minute)}',
      _E.nota,
    ),
  ]);
  hoja.fila(const []);
  const encabezados = [
    'Fecha', 'Hora', 'Pedido', 'Sucursal', 'Modalidad', 'Método de pago', 'Estado',
    'Cupón', 'Descuento (Bs)', 'Total (Bs)', 'Propina (Bs)', 'Envío (Bs)', 'NIT / CI', 'Razón social',
  ];
  final filaEncabezado = hoja.fila([for (final e in encabezados) _texto(e, _E.encabezado)]);
  final primeraDato = filaEncabezado + 1;
  for (final p in ordenados) {
    final f = p.fechaCreacion;
    hoja.fila([
      f == null ? _vacia() : _numero(_serialFecha(f), _E.fecha),
      _texto(f == null ? '' : '${dos(f.hour)}:${dos(f.minute)}'),
      _texto('#${p.id.length >= 6 ? p.id.substring(0, 6) : p.id}'),
      _texto(sucursal(p)),
      _texto(p.etiquetaModalidad),
      _texto(p.metodoPago),
      _texto(p.estado),
      _texto(p.codigoCupon ?? ''),
      p.descuento > 0 ? _numero(p.descuento, _E.dinero) : _vacia(),
      _numero(p.total, _E.dinero),
      p.propina > 0 ? _numero(p.propina, _E.dinero) : _vacia(),
      p.costoEnvio > 0 ? _numero(p.costoEnvio, _E.dinero) : _vacia(),
      _texto(p.facturaNit ?? ''),
      _texto(p.facturaRazonSocial ?? ''),
    ]);
  }
  final ultimaDato = hoja.filas;
  double suma(double Function(PedidoModel) v) => ordenados.fold(0, (a, p) => a + v(p));
  String rango(String col) => '$col$primeraDato:$col${ultimaDato < primeraDato ? primeraDato : ultimaDato}';
  hoja.fila([
    _texto('TOTAL', _E.totalTexto),
    for (var i = 0; i < 7; i++) _texto('', _E.totalTexto),
    _formula('SUM(${rango('I')})', suma((p) => p.descuento), _E.totalDinero),
    _formula('SUM(${rango('J')})', suma((p) => p.total), _E.totalDinero),
    _formula('SUM(${rango('K')})', suma((p) => p.propina), _E.totalDinero),
    _formula('SUM(${rango('L')})', suma((p) => p.costoEnvio), _E.totalDinero),
    _texto('', _E.totalTexto),
    _texto('', _E.totalTexto),
  ]);
  final List<double> anchosVentas = [12, 8, 11, 22, 14, 16, 14, 12, 15, 13, 13, 12, 14, 26];

  // --------------------------------------------------------------- Resumen
  final resumen = _Hoja();
  final total = suma((p) => p.total);
  resumen.fila([_texto('Resumen', _E.titulo)]);
  resumen.fila([_texto(periodo.isEmpty ? '${ordenados.length} pedidos' : periodo, _E.nota)]);
  resumen.fila(const []);
  resumen.fila([_texto('Indicador', _E.encabezado), _texto('Valor', _E.encabezado)]);
  resumen.fila([_texto('Ventas (Bs)'), _numero(total, _E.dinero)]);
  resumen.fila([_texto('Pedidos'), _numero(ordenados.length.toDouble(), _E.entero)]);
  resumen.fila([
    _texto('Ticket promedio (Bs)'),
    _numero(ordenados.isEmpty ? 0 : total / ordenados.length, _E.dinero),
  ]);
  resumen.fila([_texto('Descuentos con cupón (Bs)'), _numero(suma((p) => p.descuento), _E.dinero)]);
  resumen.fila([_texto('Costos de envío cobrados (Bs)'), _numero(suma((p) => p.costoEnvio), _E.dinero)]);
  resumen.fila([_texto('Propinas para repartidores (Bs)'), _numero(suma((p) => p.propina), _E.dinero)]);
  resumen.fila([
    _texto('Pedidos con factura'),
    _numero(ordenados.where((p) => p.pideFactura).length.toDouble(), _E.entero),
  ]);

  void agrupado(String titulo, String Function(PedidoModel) clave) {
    final grupos = <String, ({int n, double bs})>{};
    for (final p in ordenados) {
      final k = clave(p);
      final g = grupos[k] ?? (n: 0, bs: 0.0);
      grupos[k] = (n: g.n + 1, bs: g.bs + p.total);
    }
    final lista = grupos.entries.toList()..sort((a, b) => b.value.bs.compareTo(a.value.bs));
    resumen.fila(const []);
    resumen.fila([
      _texto(titulo, _E.encabezado),
      _texto('Pedidos', _E.encabezado),
      _texto('Ventas (Bs)', _E.encabezado),
      _texto('% de las ventas', _E.encabezado),
    ]);
    for (final e in lista) {
      resumen.fila([
        _texto(e.key),
        _numero(e.value.n.toDouble(), _E.entero),
        _numero(e.value.bs, _E.dinero),
        _numero(total == 0 ? 0 : e.value.bs / total, _E.porcentaje),
      ]);
    }
  }

  agrupado('Método de pago', (p) => p.metodoPago);
  agrupado('Modalidad', (p) => p.modalidad);
  agrupado('Sucursal', sucursal);
  final List<double> anchosResumen = [34, 12, 15, 16];

  return _xlsx([
    ('Ventas', hoja, anchosVentas, filaEncabezado, encabezados.length),
    ('Resumen', resumen, anchosResumen, 0, 0),
  ]);
}

/// Descarga el Excel (navegador). En el celular, donde no se puede
/// descargar, copia el reporte al portapapeles para pegarlo en una hoja.
Future<void> exportarExcel(
  BuildContext context, {
  required String nombreArchivo,
  required List<PedidoModel> pedidos,
  Map<String, String> nombresSucursal = const {},
  String periodo = '',
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final bytes = excelVentas(pedidos, nombresSucursal: nombresSucursal, periodo: periodo);
  final descargado = await descargarBytes(
    nombreArchivo,
    bytes,
    tipo: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  if (descargado) {
    messenger.showSnackBar(SnackBar(content: Text('Reporte descargado: $nombreArchivo')));
    return;
  }
  await Clipboard.setData(ClipboardData(text: csvVentas(pedidos, nombresSucursal: nombresSucursal)));
  messenger.showSnackBar(const SnackBar(
    content: Text('Reporte copiado al portapapeles. Pégalo en Excel o en Google Sheets.'),
  ));
}

// ======================================================================
// Escritura del archivo .xlsx (un .zip con archivos XML).
// ======================================================================

enum _E { normal, titulo, nota, encabezado, fecha, dinero, entero, porcentaje, totalTexto, totalDinero }

/// Índice del estilo en styles.xml (ver _estilos).
int _indice(_E e) => switch (e) {
      _E.normal => 0,
      _E.titulo => 1,
      _E.nota => 2,
      _E.encabezado => 3,
      _E.fecha => 4,
      _E.dinero => 5,
      _E.entero => 6,
      _E.porcentaje => 7,
      _E.totalTexto => 8,
      _E.totalDinero => 9,
    };

class _Celda {
  final String? texto;
  final double? numero;
  final String? formula;
  final _E estilo;
  const _Celda({this.texto, this.numero, this.formula, this.estilo = _E.normal});
}

_Celda _texto(String t, [_E e = _E.normal]) => _Celda(texto: t, estilo: e);
_Celda _numero(double n, [_E e = _E.normal]) => _Celda(numero: n, estilo: e);
_Celda _formula(String f, double valor, _E e) => _Celda(formula: f, numero: valor, estilo: e);
_Celda _vacia() => const _Celda();

class _Hoja {
  final List<List<_Celda>> _filas = [];
  int get filas => _filas.length;

  /// Agrega una fila y devuelve su número (empieza en 1, como en Excel).
  int fila(List<_Celda> celdas) {
    _filas.add(celdas);
    return _filas.length;
  }
}

/// Días desde el 30/12/1899 (así guarda Excel las fechas).
double _serialFecha(DateTime f) {
  final dia = DateTime.utc(f.year, f.month, f.day);
  return dia.difference(DateTime.utc(1899, 12, 30)).inDays.toDouble();
}

String _columna(int i) {
  var n = i + 1;
  var s = '';
  while (n > 0) {
    final r = (n - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    n = (n - 1) ~/ 26;
  }
  return s;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _num(double v) {
  final r = (v * 100).round() / 100;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toString();
}

String _hojaXml(_Hoja hoja, List<double> anchos, int filaEncabezado, int columnas) {
  final b = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">');
  if (filaEncabezado > 0) {
    // Deja fijas las filas de arriba al bajar.
    b.write('<sheetViews><sheetView workbookViewId="0">'
        '<pane ySplit="$filaEncabezado" topLeftCell="A${filaEncabezado + 1}" activePane="bottomLeft" state="frozen"/>'
        '</sheetView></sheetViews>');
  }
  b.write('<cols>');
  for (var i = 0; i < anchos.length; i++) {
    b.write('<col min="${i + 1}" max="${i + 1}" width="${anchos[i]}" customWidth="1"/>');
  }
  b.write('</cols><sheetData>');
  for (var f = 0; f < hoja._filas.length; f++) {
    final fila = hoja._filas[f];
    final alta = fila.isNotEmpty && fila.first.estilo == _E.titulo;
    b.write('<row r="${f + 1}"${alta ? ' ht="24" customHeight="1"' : ''}>');
    for (var c = 0; c < fila.length; c++) {
      final celda = fila[c];
      final ref = '${_columna(c)}${f + 1}';
      final s = _indice(celda.estilo);
      if (celda.formula != null) {
        b.write('<c r="$ref" s="$s"><f>${_esc(celda.formula!)}</f><v>${_num(celda.numero ?? 0)}</v></c>');
      } else if (celda.numero != null) {
        b.write('<c r="$ref" s="$s"><v>${celda.estilo == _E.porcentaje ? celda.numero : _num(celda.numero!)}</v></c>');
      } else if ((celda.texto ?? '').isNotEmpty) {
        b.write('<c r="$ref" s="$s" t="inlineStr"><is><t xml:space="preserve">${_esc(celda.texto!)}</t></is></c>');
      } else if (s != 0) {
        b.write('<c r="$ref" s="$s"/>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData>');
  if (filaEncabezado > 0 && columnas > 0 && hoja.filas > filaEncabezado + 1) {
    // Filtros en el encabezado (sin incluir la fila de totales).
    b.write('<autoFilter ref="A$filaEncabezado:${_columna(columnas - 1)}${hoja.filas - 1}"/>');
  }
  b.write('<pageMargins left="0.5" right="0.5" top="0.6" bottom="0.6" header="0.3" footer="0.3"/>'
      '<pageSetup orientation="landscape" fitToWidth="1" fitToHeight="0"/>');
  b.write('</worksheet>');
  return b.toString();
}

const _estilos = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
    '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
    '<numFmts count="3">'
    '<numFmt numFmtId="164" formatCode="dd/mm/yyyy"/>'
    '<numFmt numFmtId="165" formatCode="#,##0.00"/>'
    '<numFmt numFmtId="166" formatCode="0.0%"/>'
    '</numFmts>'
    '<fonts count="4">'
    '<font><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="11"/><name val="Calibri"/></font>'
    '<font><b/><sz val="16"/><color rgb="FF1A1200"/><name val="Calibri"/></font>'
    '<font><i/><sz val="10"/><color rgb="FF6B6459"/><name val="Calibri"/></font>'
    '</fonts>'
    '<fills count="4">'
    '<fill><patternFill patternType="none"/></fill>'
    '<fill><patternFill patternType="gray125"/></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF2BC45"/><bgColor indexed="64"/></patternFill></fill>'
    '<fill><patternFill patternType="solid"><fgColor rgb="FFF3EEE3"/><bgColor indexed="64"/></patternFill></fill>'
    '</fills>'
    '<borders count="3">'
    '<border><left/><right/><top/><bottom/><diagonal/></border>'
    '<border><left/><right/><top/><bottom style="thin"><color rgb="FF8A6A1F"/></bottom><diagonal/></border>'
    '<border><left/><right/><top style="thin"><color rgb="FF8A6A1F"/></top><bottom style="double"><color rgb="FF8A6A1F"/></bottom><diagonal/></border>'
    '</borders>'
    '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
    '<cellXfs count="10">'
    '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
    '<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="0" fontId="3" fillId="0" borderId="0" xfId="0" applyFont="1"/>'
    '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>'
    '<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1" applyAlignment="1"><alignment horizontal="left"/></xf>'
    '<xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="166" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
    '<xf numFmtId="0" fontId="1" fillId="3" borderId="2" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>'
    '<xf numFmtId="165" fontId="1" fillId="3" borderId="2" xfId="0" applyNumberFormat="1" applyFont="1" applyFill="1" applyBorder="1"/>'
    '</cellXfs>'
    '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>'
    '</styleSheet>';

Uint8List _xlsx(List<(String, _Hoja, List<double>, int, int)> hojas) {
  final archivos = <String, String>{
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '${[for (var i = 0; i < hojas.length; i++) '<Override PartName="/xl/worksheets/sheet${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'].join()}'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>'
        '${[for (var i = 0; i < hojas.length; i++) '<sheet name="${_esc(hojas[i].$1)}" sheetId="${i + 1}" r:id="rId${i + 1}"/>'].join()}'
        '</sheets>'
        '${hojas.first.$4 > 0 && hojas.first.$2.filas > hojas.first.$4 + 1 ? '<definedNames><definedName name="_xlnm._FilterDatabase" localSheetId="0" hidden="1">\'${hojas.first.$1}\'!\$A\$${hojas.first.$4}:\$${_columna(hojas.first.$5 - 1)}\$${hojas.first.$2.filas - 1}</definedName></definedNames>' : ''}'
        '</workbook>',
    'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '${[for (var i = 0; i < hojas.length; i++) '<Relationship Id="rId${i + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet${i + 1}.xml"/>'].join()}'
        '<Relationship Id="rId${hojas.length + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>',
    'xl/styles.xml': _estilos,
    for (var i = 0; i < hojas.length; i++)
      'xl/worksheets/sheet${i + 1}.xml': _hojaXml(hojas[i].$2, hojas[i].$3, hojas[i].$4, hojas[i].$5),
  };
  final zip = Archive();
  archivos.forEach((nombre, contenido) {
    final bytes = utf8.encode(contenido);
    zip.addFile(ArchiveFile(nombre, bytes.length, bytes));
  });
  return Uint8List.fromList(ZipEncoder().encode(zip));
}
