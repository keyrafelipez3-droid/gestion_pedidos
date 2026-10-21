import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../models/pedido_models.dart';
import '../../models/sucursal_model.dart';
import '../../services/negocio_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/descarga.dart';
import '../../widgets/app_contenido_centrado.dart';

/// Ticket (comprobante) de un pedido, con formato de recibo: datos del
/// negocio, sucursal, fecha, detalle de productos, total y método de pago.
///
/// En el navegador se puede imprimir o "Guardar como PDF". No es una
/// factura fiscal (la app no emite facturas): así lo dice el propio ticket.
class TicketPedidoScreen extends StatefulWidget {
  final PedidoModel pedido;
  const TicketPedidoScreen({super.key, required this.pedido});

  @override
  State<TicketPedidoScreen> createState() => _TicketPedidoScreenState();
}

class _DatosTicket {
  final NegocioModel negocio;
  final SucursalModel? sucursal;
  final List<DetallePedidoModel> detalle;
  const _DatosTicket(this.negocio, this.sucursal, this.detalle);
}

class _TicketPedidoScreenState extends State<TicketPedidoScreen> {
  late final Future<_DatosTicket> _datos = _cargar();

  Future<_DatosTicket> _cargar() async {
    final p = widget.pedido;
    final resultados = await Future.wait([
      NegocioService.instancia.obtenerNegocioPorId(p.idNegocio),
      SucursalService.instancia.obtener(p.idSucursal),
      PedidoService.instancia.streamDetalle(p.id).first,
    ]);
    return _DatosTicket(
      resultados[0] as NegocioModel,
      resultados[1] as SucursalModel?,
      resultados[2] as List<DetallePedidoModel>,
    );
  }

  String _dos(int n) => n.toString().padLeft(2, '0');
  String _fecha(DateTime? f) =>
      f == null ? '' : '${_dos(f.day)}/${_dos(f.month)}/${f.year} ${_dos(f.hour)}:${_dos(f.minute)}';

  Future<void> _imprimir(_DatosTicket d) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await imprimirHtml(_html(d));
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Permite las ventanas emergentes del sitio para imprimir el ticket.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Ticket #${widget.pedido.id.substring(0, 6)}')),
      body: FutureBuilder<_DatosTicket>(
        future: _datos,
        builder: (context, s) {
          if (s.hasError) {
            return const Center(child: Text('No se pudo cargar el ticket. Intenta de nuevo.'));
          }
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final d = s.data!;
          return AppContenidoCentrado(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Center(child: _Recibo(pedido: widget.pedido, datos: d, fecha: _fecha)),
                const SizedBox(height: AppSpacing.lg),
                if (kIsWeb)
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => _imprimir(d),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Imprimir / Guardar PDF'),
                    ),
                  )
                else
                  Text(
                    'Para imprimir o guardar en PDF, abre este ticket desde la versión web.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Versión HTML del ticket para imprimir (58–80 mm de ancho o A4).
  String _html(_DatosTicket d) {
    final p = widget.pedido;
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    final filas = StringBuffer();
    for (final i in d.detalle) {
      final extras = [...i.variantes, ...i.complementos].map((o) => o.nombre).join(', ');
      filas.write('<tr><td>${i.cantidad} x ${esc(i.nombreProducto)}'
          '${extras.isEmpty ? '' : '<div class="extra">${esc(extras)}</div>'}'
          '${i.notas.isEmpty ? '' : '<div class="extra">Nota: ${esc(i.notas)}</div>'}'
          '</td><td class="der">Bs ${i.subtotal.toStringAsFixed(2)}</td></tr>');
    }
    final n = d.negocio;
    final logo = n.logoUrl.trim().isEmpty ? '' : '<img class="logo" src="${esc(n.logoUrl.trim())}" alt="">';
    return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<title>Ticket ${esc(p.id.substring(0, 6))}</title>
<style>
  body{font-family:Poppins,Arial,sans-serif;color:#1a1200;margin:0;padding:24px;}
  .ticket{max-width:340px;margin:0 auto;border:1px dashed #bbb;padding:20px;}
  .centro{text-align:center;} .logo{width:64px;height:64px;border-radius:50%;object-fit:cover;}
  h1{font-size:20px;margin:8px 0 2px;} .gris{color:#6b6459;font-size:12px;margin:2px 0;}
  hr{border:0;border-top:1px dashed #bbb;margin:12px 0;}
  table{width:100%;border-collapse:collapse;font-size:13px;} td{padding:4px 0;vertical-align:top;}
  .der{text-align:right;white-space:nowrap;} .extra{color:#6b6459;font-size:11px;}
  .total td{font-weight:700;font-size:16px;padding-top:8px;}
  @media print{body{padding:0;} .ticket{border:0;}}
</style></head><body onload="window.print()">
<div class="ticket">
  <div class="centro">$logo
    <h1>${esc(n.nombre)}</h1>
    ${n.razonSocial.isEmpty ? '' : '<p class="gris">${esc(n.razonSocial)}</p>'}
    ${n.nit.isEmpty ? '' : '<p class="gris">NIT: ${esc(n.nit)}</p>'}
    ${d.sucursal == null ? '' : '<p class="gris">${esc(d.sucursal!.nombre)} · ${esc(d.sucursal!.direccion)}</p>'}
    ${n.telefono.isEmpty ? '' : '<p class="gris">Tel. ${esc(n.telefono)}</p>'}
  </div>
  <hr>
  <p class="gris">Pedido: <b>#${esc(p.id.substring(0, 6))}</b></p>
  <p class="gris">Fecha: ${_fecha(p.fechaCreacion)}</p>
  <p class="gris">Modalidad: ${esc(p.etiquetaModalidad)}</p>
  ${p.nombreCliente == null ? '' : '<p class="gris">Cliente: ${esc(p.nombreCliente!)}</p>'}
  <hr>
  <table>$filas
    <tr class="total"><td>TOTAL</td><td class="der">Bs ${p.total.toStringAsFixed(2)}</td></tr>
  </table>
  <hr>
  <p class="gris">Pago: ${esc(p.metodoPago)}${p.cobrado ? ' · Cobrado' : ''}</p>
  <p class="gris">Estado: ${esc(p.estado)}</p>
  <hr>
  <p class="centro gris">¡Gracias por tu compra!<br>Comprobante de pedido · no válido como factura.</p>
</div></body></html>''';
  }
}

/// El ticket dibujado en pantalla (mismo contenido que la versión impresa).
class _Recibo extends StatelessWidget {
  final PedidoModel pedido;
  final _DatosTicket datos;
  final String Function(DateTime?) fecha;
  const _Recibo({required this.pedido, required this.datos, required this.fecha});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final n = datos.negocio;
    // El ticket siempre es blanco (como el papel), también en modo oscuro.
    const tinta = Color(0xFF1A1200);
    final gris = texto.bodySmall?.copyWith(color: const Color(0xFF6B6459));
    TextStyle? t(TextStyle? base) => base?.copyWith(color: tinta);
    Widget linea() => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: List.generate(
              40,
              (i) => Expanded(child: Container(height: 1, color: i.isEven ? scheme.outlineVariant : Colors.transparent)),
            ),
          ),
        );
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xFF1A1200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (n.logoUrl.trim().isNotEmpty)
              Center(
                child: ClipOval(
                  child: Image.network(
                    n.logoUrl.trim(),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(n.nombre, textAlign: TextAlign.center, style: t(texto.titleLarge)?.copyWith(fontWeight: FontWeight.w700)),
            if (n.razonSocial.isNotEmpty) Text(n.razonSocial, textAlign: TextAlign.center, style: gris),
            if (n.nit.isNotEmpty) Text('NIT: ${n.nit}', textAlign: TextAlign.center, style: gris),
            if (datos.sucursal != null)
              Text('${datos.sucursal!.nombre} · ${datos.sucursal!.direccion}', textAlign: TextAlign.center, style: gris),
            if (n.telefono.isNotEmpty) Text('Tel. ${n.telefono}', textAlign: TextAlign.center, style: gris),
            linea(),
            Text('Pedido #${pedido.id.substring(0, 6)}', style: t(texto.bodyMedium)?.copyWith(fontWeight: FontWeight.w700)),
            Text('Fecha: ${fecha(pedido.fechaCreacion)}', style: gris),
            Text('Modalidad: ${pedido.etiquetaModalidad}', style: gris),
            if (pedido.nombreCliente != null) Text('Cliente: ${pedido.nombreCliente}', style: gris),
            linea(),
            for (final i in datos.detalle)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${i.cantidad} x ${i.nombreProducto}', style: t(texto.bodyMedium)),
                          if ([...i.variantes, ...i.complementos].isNotEmpty)
                            Text([...i.variantes, ...i.complementos].map((o) => o.nombre).join(', '), style: gris),
                        ],
                      ),
                    ),
                    Text('Bs ${i.subtotal.toStringAsFixed(2)}', style: t(texto.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(child: Text('TOTAL', style: t(texto.titleMedium)?.copyWith(fontWeight: FontWeight.w800))),
                Text('Bs ${pedido.total.toStringAsFixed(2)}',
                    style: t(texto.titleMedium)?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            linea(),
            Text('Pago: ${pedido.metodoPago}${pedido.cobrado ? ' · Cobrado' : ''}', style: gris),
            Text('Estado: ${pedido.estado}', style: gris),
            linea(),
            Text('¡Gracias por tu compra!', textAlign: TextAlign.center, style: t(texto.bodyMedium)),
            Text('Comprobante de pedido · no válido como factura.', textAlign: TextAlign.center, style: gris),
          ],
        ),
      ),
    );
  }
}
