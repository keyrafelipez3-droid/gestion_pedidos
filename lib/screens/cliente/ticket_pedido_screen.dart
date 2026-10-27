import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/negocio_model.dart';
import '../../models/alergenos.dart';
import '../../models/pedido_models.dart';
import '../../models/sucursal_model.dart';
import '../../services/negocio_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/descarga.dart';
import '../../utils/formato.dart';
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
      messenger.showSnackBar(SnackBar(
        content: Text(tr('Permite las ventanas emergentes del sitio para imprimir el ticket.')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Ticket #{id}', {'id': widget.pedido.id.substring(0, 6)}))),
      body: FutureBuilder<_DatosTicket>(
        future: _datos,
        builder: (context, s) {
          if (s.hasError) {
            return Center(child: Text(tr('No se pudo cargar el ticket. Intenta de nuevo.')));
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
                      label: Text(tr('Imprimir / Guardar PDF')),
                    ),
                  )
                else
                  Text(
                    tr('Para imprimir o guardar en PDF, abre este ticket desde la versión web.'),
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
          '${i.notas.isEmpty ? '' : '<div class="extra">${esc(tr('Nota: {notas}', {'notas': i.notas}))}</div>'}'
          '</td><td class="der">${dinero(i.subtotal)}</td></tr>');
    }
    final n = d.negocio;
    final logo = n.logoUrl.trim().isEmpty ? '' : '<img class="logo" src="${esc(n.logoUrl.trim())}" alt="">';
    return '''<!doctype html><html lang="${IdiomaController.instancia.codigo.value}"><head><meta charset="utf-8">
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
  .alergia{border:2px solid #b3261e;color:#b3261e;font-weight:700;padding:6px 8px;margin:8px 0;font-size:13px;}
  @media print{body{padding:0;} .ticket{border:0;}}
</style></head><body onload="window.print()">
<div class="ticket">
  <div class="centro">$logo
    <h1>${esc(n.nombre)}</h1>
    ${n.razonSocial.isEmpty ? '' : '<p class="gris">${esc(n.razonSocial)}</p>'}
    ${n.nit.isEmpty ? '' : '<p class="gris">${esc('${n.datosPais.idFiscal}: ${n.nit}')}</p>'}
    ${d.sucursal == null ? '' : '<p class="gris">${esc(d.sucursal!.nombre)} · ${esc(d.sucursal!.direccion)}</p>'}
    ${n.telefono.isEmpty ? '' : '<p class="gris">${esc(tr('Tel. {telefono}', {'telefono': n.telefono}))}</p>'}
  </div>
  <hr>
  <p class="gris"><b>${esc(tr('Pedido #{id}', {'id': p.id.substring(0, 6)}))}</b></p>
  <p class="gris">${esc(tr('Fecha: {fechaCreacion}', {'fechaCreacion': _fecha(p.fechaCreacion)}))}</p>
  <p class="gris">${esc(tr('Modalidad: {etiquetaModalidad}', {'etiquetaModalidad': p.etiquetaModalidad}))}</p>
  ${p.nombreCliente == null ? '' : '<p class="gris">${esc(tr('Cliente: {nombreCliente}', {'nombreCliente': p.nombreCliente}))}</p>'}
  ${p.pideFactura ? '<p class="gris">${esc(tr('Factura a: {nit} · {razon}', {'nit': p.facturaNit, 'razon': p.facturaRazonSocial ?? ''}))}</p>' : ''}
  ${p.programadoPara == null ? '' : '<p class="gris"><b>${esc(tr('Programado para: {hora}', {'hora': formatoProgramado(p.programadoPara!)}))}</b></p>'}
  ${p.tieneAlergias ? '<p class="alergia">&#9888; ${esc(tr('ALERGIA'))}: ${esc(Alergenos.nombres(p.alergias))}</p>' : ''}
  <hr>
  <table>$filas
    ${p.descuento > 0 ? '<tr><td>${esc(tr('Descuento ({codigo})', {'codigo': p.codigoCupon ?? ''}))}</td><td class="der">-${dinero(p.descuento)}</td></tr>' : ''}
    ${p.costoEnvio > 0 ? '<tr><td>${esc(tr('Envío ({zona})', {'zona': p.zonaEntrega ?? ''}))}</td><td class="der">${dinero(p.costoEnvio)}</td></tr>' : ''}
    <tr class="total"><td>${esc(tr('TOTAL'))}</td><td class="der">${dinero(p.montoNegocio)}</td></tr>
    ${p.propina > 0 ? '<tr><td>${esc(tr('Propina'))}</td><td class="der">${dinero(p.propina)}</td></tr>' : ''}
  </table>
  <hr>
  <p class="gris">${esc(tr('Pago: {metodo}', {'metodo': tr(p.metodoPago)}))}${p.cobrado ? ' · ${esc(tr('Cobrado'))}' : ''}</p>
  <p class="gris">${esc(tr('Estado: {estado}', {'estado': tr(p.estado)}))}</p>
  <hr>
  <p class="centro gris">${esc(tr('¡Gracias por tu compra!'))}<br>${esc(tr('Comprobante de pedido · no válido como factura.'))}</p>
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
              (i) => Expanded(child: Container(height: 1, color: i.isEven ? const Color(0x33000000) : Colors.transparent)),
            ),
          ),
        );
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: const Color(0x1F000000)),
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
            if (n.nit.isNotEmpty) Text('${n.datosPais.idFiscal}: ${n.nit}', textAlign: TextAlign.center, style: gris),
            if (datos.sucursal != null)
              Text('${datos.sucursal!.nombre} · ${datos.sucursal!.direccion}', textAlign: TextAlign.center, style: gris),
            if (n.telefono.isNotEmpty) Text(tr('Tel. {telefono}', {'telefono': n.telefono}), textAlign: TextAlign.center, style: gris),
            linea(),
            Text(tr('Pedido #{id}', {'id': pedido.id.substring(0, 6)}), style: t(texto.bodyMedium)?.copyWith(fontWeight: FontWeight.w700)),
            Text(tr('Fecha: {fechaCreacion}', {'fechaCreacion': fecha(pedido.fechaCreacion)}), style: gris),
            Text(tr('Modalidad: {etiquetaModalidad}', {'etiquetaModalidad': pedido.etiquetaModalidad}), style: gris),
            if (pedido.nombreCliente != null) Text(tr('Cliente: {nombreCliente}', {'nombreCliente': pedido.nombreCliente}), style: gris),
            if (pedido.pideFactura)
              Text(tr('Factura a: {nit} · {razon}',
                  {'nit': pedido.facturaNit, 'razon': pedido.facturaRazonSocial ?? ''}), style: gris),
            if (pedido.programadoPara != null)
              Text(tr('Programado para: {hora}', {'hora': formatoProgramado(pedido.programadoPara!)}),
                  style: t(texto.bodySmall)?.copyWith(fontWeight: FontWeight.w700)),
            if (pedido.tieneAlergias)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFB3261E), width: 2),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  '⚠ ${tr('ALERGIA')}: ${Alergenos.nombres(pedido.alergias)}',
                  style: const TextStyle(color: Color(0xFFB3261E), fontWeight: FontWeight.w800),
                ),
              ),
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
                    Text(dinero(i.subtotal), style: t(texto.bodyMedium)),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (pedido.descuento > 0)
              Row(
                children: [
                  Expanded(child: Text(tr('Descuento ({codigo})', {'codigo': pedido.codigoCupon ?? ''}), style: gris)),
                  Text('-${dinero(pedido.descuento)}', style: gris),
                ],
              ),
            if (pedido.costoEnvio > 0)
              Row(
                children: [
                  Expanded(child: Text(tr('Envío ({zona})', {'zona': pedido.zonaEntrega ?? ''}), style: gris)),
                  Text(dinero(pedido.costoEnvio), style: gris),
                ],
              ),
            Row(
              children: [
                Expanded(child: Text(tr('TOTAL'), style: t(texto.titleMedium)?.copyWith(fontWeight: FontWeight.w800))),
                Text(dinero(pedido.montoNegocio),
                    style: t(texto.titleMedium)?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            if (pedido.propina > 0)
              Row(
                children: [
                  Expanded(child: Text(tr('Propina'), style: gris)),
                  Text(dinero(pedido.propina), style: gris),
                ],
              ),
            linea(),
            Text('${tr('Pago: {metodo}', {'metodo': tr(pedido.metodoPago)})}${pedido.cobrado ? ' · ${tr('Cobrado')}' : ''}', style: gris),
            Text(tr('Estado: {estado}', {'estado': tr(pedido.estado)}), style: gris),
            linea(),
            Text(tr('¡Gracias por tu compra!'), textAlign: TextAlign.center, style: t(texto.bodyMedium)),
            Text(tr('Comprobante de pedido · no válido como factura.'), textAlign: TextAlign.center, style: gris),
          ],
        ),
      ),
    );
  }
}
