import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pedido_models.dart';
import 'descarga.dart';

/// Reporte de ventas en CSV listo para abrir en Excel: separado por ";"
/// (Excel en español usa la coma como decimal) y con BOM UTF-8 para que
/// las tildes se vean bien.
String csvVentas(
  List<PedidoModel> pedidos, {
  Map<String, String> nombresSucursal = const {},
}) {
  String celda(Object? v) {
    final s = (v ?? '').toString().replaceAll('"', '""');
    return s.contains(';') || s.contains('"') || s.contains('\n') ? '"$s"' : s;
  }

  String dos(int n) => n.toString().padLeft(2, '0');
  final ordenados = List.of(pedidos)
    ..sort((a, b) => (a.fechaCreacion ?? DateTime(0)).compareTo(b.fechaCreacion ?? DateTime(0)));
  final filas = <String>[
    ['Fecha', 'Hora', 'Pedido', 'Sucursal', 'Modalidad', 'Método de pago', 'Estado', 'Total (Bs)']
        .join(';'),
  ];
  double total = 0;
  for (final p in ordenados) {
    final f = p.fechaCreacion;
    total += p.total;
    filas.add([
      f == null ? '' : '${dos(f.day)}/${dos(f.month)}/${f.year}',
      f == null ? '' : '${dos(f.hour)}:${dos(f.minute)}',
      '#${p.id.length >= 6 ? p.id.substring(0, 6) : p.id}',
      nombresSucursal[p.idSucursal] ?? p.idSucursal,
      p.etiquetaModalidad,
      p.metodoPago,
      p.estado,
      p.total.toStringAsFixed(2).replaceAll('.', ','),
    ].map(celda).join(';'));
  }
  filas.add(['', '', '', '', '', '', 'TOTAL', total.toStringAsFixed(2).replaceAll('.', ',')].join(';'));
  return '﻿${filas.join('\r\n')}';
}

/// Descarga el CSV (navegador) o, en el celular, lo copia al portapapeles.
Future<void> exportarCsv(BuildContext context, String nombreArchivo, String contenido) async {
  final messenger = ScaffoldMessenger.of(context);
  final descargado = await descargarTexto(nombreArchivo, contenido);
  if (descargado) {
    messenger.showSnackBar(SnackBar(content: Text('Reporte descargado: $nombreArchivo')));
    return;
  }
  await Clipboard.setData(ClipboardData(text: contenido));
  messenger.showSnackBar(const SnackBar(
    content: Text('Reporte copiado al portapapeles. Pégalo en Excel o en Google Sheets.'),
  ));
}
