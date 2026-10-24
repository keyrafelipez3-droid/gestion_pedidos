import 'package:flutter/material.dart';

import '../models/alergenos.dart';
import '../models/pedido_models.dart';
import '../services/pedido_service.dart';
import 'descarga.dart';
import 'formato.dart';

/// Comanda para la cocina: lo que hay que preparar, en letra grande y SIN
/// precios. Pensada para impresoras térmicas de 58 u 80 mm (también sale
/// bien en A4). Las alergias van en un recuadro para que nadie las pase
/// por alto.
String htmlComanda(PedidoModel p, List<DetallePedidoModel> detalle, {String sucursal = ''}) {
  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
  String dos(int n) => n.toString().padLeft(2, '0');
  final f = p.fechaCreacion ?? DateTime.now();
  final items = StringBuffer();
  for (final i in detalle) {
    final extras = [...i.variantes, ...i.complementos].map((o) => o.nombre).join(', ');
    items.write('<div class="item"><span class="cant">${i.cantidad}×</span> ${esc(i.nombreProducto)}'
        '${extras.isEmpty ? '' : '<div class="extra">+ ${esc(extras)}</div>'}'
        '${i.notas.isEmpty ? '' : '<div class="nota">» ${esc(i.notas)}</div>'}'
        '</div>');
  }
  final idioma = p.idiomaCliente == 'es' ? '' : ' (escrita en ${esc(p.idiomaCliente.toUpperCase())})';
  final totalProductos = detalle.fold<int>(0, (a, i) => a + i.cantidad);
  return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>Comanda ${esc(p.id.substring(0, 6))}</title>
<style>
  @page{size:80mm auto;margin:3mm;}
  body{font-family:"Courier New",monospace;color:#000;margin:0;padding:8px;max-width:74mm;}
  h1{font-size:22px;margin:0;} .linea{border-top:2px dashed #000;margin:8px 0;}
  .dato{font-size:14px;margin:2px 0;} .grande{font-size:18px;font-weight:700;margin:4px 0;}
  .item{font-size:17px;font-weight:700;margin:6px 0;} .cant{font-size:20px;}
  .extra{font-size:13px;font-weight:400;margin-left:18px;}
  .nota{font-size:14px;font-weight:700;margin-left:18px;}
  .alergia{border:3px solid #000;padding:6px;font-size:16px;font-weight:700;margin:8px 0;}
</style></head><body onload="window.print()">
  <h1>COMANDA #${esc(p.id.substring(0, 6).toUpperCase())}</h1>
  <p class="grande">${esc(p.etiquetaModalidad)}</p>
  <p class="dato">${dos(f.day)}/${dos(f.month)} ${dos(f.hour)}:${dos(f.minute)}${sucursal.isEmpty ? '' : ' · ${esc(sucursal)}'}</p>
  ${p.programadoPara == null ? '' : '<p class="grande">PARA: ${esc(formatoProgramado(p.programadoPara!))}</p>'}
  ${p.nombreCliente == null ? '' : '<p class="dato">Cliente: ${esc(p.nombreCliente!)}</p>'}
  ${p.tieneAlergias ? '<div class="alergia">&#9888; ALERGIA: ${esc(Alergenos.nombres(p.alergias).toUpperCase())}</div>' : ''}
  <div class="linea"></div>
  $items
  ${p.notas.isEmpty ? '' : '<div class="linea"></div><p class="nota">NOTA$idioma: ${esc(p.notas)}</p>'}
  <div class="linea"></div>
  <p class="dato">$totalProductos productos</p>
</body></html>''';
}

/// Abre la comanda para imprimir (versión web). En el celular avisa que
/// se imprime desde la web.
Future<void> imprimirComanda(BuildContext context, PedidoModel pedido) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final detalle = await PedidoService.instancia.streamDetalle(pedido.id).first;
    final ok = await imprimirHtml(htmlComanda(pedido, detalle));
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
