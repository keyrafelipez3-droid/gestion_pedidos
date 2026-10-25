import 'package:flutter/material.dart';

import '../models/alergenos.dart';
import '../models/pedido_models.dart';
import '../services/pedido_service.dart';
import '../services/traduccion_service.dart';
import 'descarga.dart';
import 'formato.dart';

/// Comanda para la cocina: lo que hay que preparar, en letra grande y SIN
/// precios. Pensada para impresoras térmicas de 58 u 80 mm (también sale
/// bien en A4): solo blanco y negro, con el número del pedido y las
/// alergias en recuadros negros para que nadie los pase por alto.
String htmlComanda(
  PedidoModel p,
  List<DetallePedidoModel> detalle, {
  String sucursal = '',
  DateTime? impresa,
  String? notaTraducida,
}) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String dos(int n) => n.toString().padLeft(2, '0');
  final f = p.fechaCreacion ?? DateTime.now();
  final ahora = impresa ?? DateTime.now();
  final numero = esc(p.id.substring(0, 6).toUpperCase());

  final items = StringBuffer();
  for (final i in detalle) {
    final extras = [...i.variantes, ...i.complementos].map((o) => o.nombre).join(', ');
    items.write('<tr>'
        '<td class="cant">${i.cantidad}</td>'
        '<td class="prod">${esc(i.nombreProducto)}'
        '${extras.isEmpty ? '' : '<div class="extra">+ ${esc(extras)}</div>'}'
        '${i.notas.isEmpty ? '' : '<div class="nota-item">&#9656; ${esc(i.notas)}</div>'}'
        '</td>'
        '<td class="check"></td>'
        '</tr>');
  }
  final unidades = detalle.fold<int>(0, (a, i) => a + i.cantidad);
  final idioma = p.idiomaCliente == 'es' ? '' : ' <span class="idioma">${esc(p.idiomaCliente.toUpperCase())}</span>';
  // Nota del cliente: traducida al español si se pudo, con el original abajo.
  final traduccion = (notaTraducida ?? '').trim();
  final notaHtml = traduccion.isEmpty
      ? '<div class="nota"><b>NOTA DEL CLIENTE$idioma</b>${esc(p.notas)}</div>'
      : '<div class="nota"><b>NOTA DEL CLIENTE (traducida)</b>${esc(traduccion)}'
          '<div class="original">Original$idioma: ${esc(p.notas)}</div></div>';

  return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Comanda #$numero</title>
<style>
  @page{size:80mm auto;margin:2mm;}
  *{box-sizing:border-box;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
  body{margin:0;background:#e9e6e1;font-family:Arial,Helvetica,sans-serif;color:#000;}
  .ticket{width:76mm;margin:24px auto;background:#fff;padding:10px 10px 14px;box-shadow:0 2px 12px rgba(0,0,0,.18);}
  .cab{background:#000;color:#fff;text-align:center;padding:8px 6px 6px;}
  .cab .etq{font-size:11px;letter-spacing:4px;font-weight:700;}
  .cab .num{font-size:30px;font-weight:900;letter-spacing:2px;line-height:1.1;}
  .meta{display:flex;justify-content:space-between;align-items:center;margin:8px 0 2px;}
  .modo{border:2px solid #000;padding:2px 8px;font-weight:900;font-size:15px;text-transform:uppercase;}
  .hora{font-size:13px;font-weight:700;}
  .dato{font-size:12px;margin:3px 0;}
  .para{border:2px solid #000;text-align:center;font-weight:900;font-size:16px;padding:4px;margin:8px 0;}
  .alergia{background:#000;color:#fff;padding:7px 8px;margin:8px 0;font-weight:900;font-size:14px;}
  .alergia small{display:block;font-weight:400;font-size:11px;margin-top:2px;}
  .sep{border:0;border-top:2px dashed #000;margin:8px 0;}
  table{width:100%;border-collapse:collapse;}
  td{vertical-align:top;padding:5px 0;border-bottom:1px dotted #888;}
  tr:last-child td{border-bottom:0;}
  .cant{width:34px;font-size:22px;font-weight:900;}
  .prod{font-size:16px;font-weight:700;line-height:1.2;}
  .extra{font-size:12px;font-weight:400;margin-top:2px;}
  .nota-item{font-size:13px;font-weight:900;margin-top:3px;}
  .check{width:20px;}
  .check::after{content:"";display:inline-block;width:14px;height:14px;border:2px solid #000;margin-top:3px;}
  .nota{border:2px dashed #000;padding:6px 8px;font-size:13px;margin-top:8px;}
  .nota b{display:block;font-size:11px;letter-spacing:1px;margin-bottom:2px;}
  .original{font-size:11px;margin-top:4px;}
  .idioma{border:1px solid #000;font-size:10px;padding:0 3px;margin-left:4px;}
  .pie{display:flex;justify-content:space-between;font-size:11px;margin-top:8px;}
  .acciones{text-align:center;margin:0 0 24px;}
  .acciones button{font:700 14px Arial,sans-serif;padding:10px 22px;border:0;border-radius:8px;background:#000;color:#fff;cursor:pointer;}
  @media print{body{background:#fff;} .ticket{width:auto;margin:0;box-shadow:none;padding:0;} .acciones{display:none;}}
</style></head><body onload="window.print()">
<div class="ticket">
  <div class="cab"><div class="etq">COMANDA</div><div class="num">#$numero</div></div>
  <div class="meta">
    <span class="modo">${esc(p.etiquetaModalidad)}</span>
    <span class="hora">${dos(f.day)}/${dos(f.month)} · ${dos(f.hour)}:${dos(f.minute)}</span>
  </div>
  ${sucursal.isEmpty ? '' : '<p class="dato">Sucursal: ${esc(sucursal)}</p>'}
  ${p.nombreCliente == null ? '' : '<p class="dato">Cliente: <b>${esc(p.nombreCliente!)}</b></p>'}
  ${p.programadoPara == null ? '' : '<div class="para">PARA LAS ${esc(formatoProgramado(p.programadoPara!))}</div>'}
  ${p.tieneAlergias ? '<div class="alergia">&#9888; ALERGIA: ${esc(Alergenos.nombres(p.alergias).toUpperCase())}<small>No usar estos ingredientes. Si no se pueden quitar, avisar al cliente.</small></div>' : ''}
  <hr class="sep">
  <table>$items</table>
  ${p.notas.isEmpty ? '' : notaHtml}
  <hr class="sep">
  <div class="pie">
    <span>$unidades ${unidades == 1 ? 'producto' : 'productos'}</span>
    <span>Impresa ${dos(ahora.hour)}:${dos(ahora.minute)}</span>
  </div>
</div>
<div class="acciones"><button onclick="window.print()">Imprimir otra vez</button></div>
</body></html>''';
}

/// Abre la comanda para imprimir (versión web). En el celular avisa que
/// se imprime desde la web.
Future<void> imprimirComanda(BuildContext context, PedidoModel pedido) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final detalle = await PedidoService.instancia.streamDetalle(pedido.id).first;
    // La cocina lee en español: se traduce la nota antes de imprimir.
    String? traducida;
    if (pedido.notas.isNotEmpty && pedido.idiomaCliente != 'es') {
      traducida = await TraduccionService.instancia
          .traducir(pedido.notas, desde: pedido.idiomaCliente, hacia: 'es')
          .catchError((_) => null);
    }
    final ok = await imprimirHtml(htmlComanda(pedido, detalle, notaTraducida: traducida));
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Para imprimir la comanda, abre la cocina desde la versión web '
            '(computadora o tablet conectada a la impresora).'),
      ));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('No se pudo preparar la comanda.')));
  }
}
