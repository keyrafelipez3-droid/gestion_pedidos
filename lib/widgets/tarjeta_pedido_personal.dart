import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/alergenos.dart';
import '../models/pedido_models.dart';
import '../screens/cliente/pedido_detalle_screen.dart';
import '../services/sesion_actual.dart';
import '../theme/design_tokens.dart';
import '../utils/acciones_pedido.dart';
import '../utils/formato.dart';
import 'alergias.dart';
import 'app_iconos_pedido.dart';
import 'panel_personal.dart';

/// Minutos a partir de los cuales un pedido que todavía no está listo se
/// marca como atrasado.
const minutosAtraso = 20;

/// true si el pedido lleva demasiado tiempo sin estar listo.
bool pedidoAtrasado(PedidoModel p, {DateTime? ahora}) =>
    (p.estado == PedidoEstado.pendiente || p.estado == PedidoEstado.enPreparacion) &&
    !p.esParaMasTarde &&
    minutosTranscurridos(p.programadoPara ?? p.fechaCreacion, ahora: ahora) >= minutosAtraso;

/// Número corto del pedido para mostrar ("#A1B2C3").
String numeroPedido(PedidoModel p) =>
    '#${(p.id.length > 6 ? p.id.substring(0, 6) : p.id).toUpperCase()}';

/// Alergias del cliente en texto ("maní, gluten").
String textoAlergias(PedidoModel p) => [
      for (final c in Alergenos.ordenar(p.alergias)) tr(Alergenos.porCodigo(c)?.nombre ?? c),
    ].join(', ');

/// Tarjeta de un pedido para el personal: número, modalidad, tiempo,
/// total, avisos (alergias, nota, factura) y el botón con la siguiente
/// acción (aceptar, marcar listo, entregar y cobrar, asignar repartidor).
/// Tocarla abre el detalle completo.
class TarjetaPedidoPersonal extends StatefulWidget {
  final PedidoModel pedido;
  final bool conAccion;

  const TarjetaPedidoPersonal({super.key, required this.pedido, this.conAccion = true});

  @override
  State<TarjetaPedidoPersonal> createState() => _TarjetaPedidoPersonalState();
}

class _TarjetaPedidoPersonalState extends State<TarjetaPedidoPersonal> {
  bool _enviando = false;

  Future<void> _avanzar(String siguiente) async {
    setState(() => _enviando = true);
    await avanzarPedido(context, widget.pedido, siguiente);
    if (mounted) setState(() => _enviando = false);
  }

  void _abrir() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PedidoDetalleScreen(idPedido: widget.pedido.id, esPersonal: true),
        ),
      );

  IconData _iconoAccion(String siguiente) {
    switch (siguiente) {
      case PedidoEstado.enPreparacion:
        return Icons.check;
      case PedidoEstado.listo:
        return Icons.done_all;
      default:
        return requiereCobroEnCaja(widget.pedido) ? Icons.payments_outlined : Icons.task_alt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final textos = Theme.of(context).textTheme;
    final atrasado = pedidoAtrasado(p);
    final sesion = SesionActual.instancia;
    final puedeAsignar = (sesion.esCajero || sesion.esAdministrador) &&
        p.esDelivery &&
        p.estado == PedidoEstado.listo;
    final siguiente = siguienteParaPersonal(p);

    final tiempo = p.programadoPara != null
        ? tr('Para {hora}', {'hora': formatoProgramado(p.programadoPara!)})
        : haceTiempo(p.fechaCreacion);

    return TarjetaPanel(
      franja: p.tieneAlergias ? scheme.error : null,
      onTap: _abrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  numeroPedido(p),
                  style: textos.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: EtiquetaPanel(p.etiquetaModalidad, icono: iconoModalidad(p.modalidad)),
              ),
            ],
          ),
          if ((p.nombreCliente ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                p.nombreCliente!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textos.bodyMedium,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: DatoConIcono(
                  atrasado ? Icons.alarm : Icons.schedule,
                  atrasado ? '$tiempo · ${tr('atrasado')}' : tiempo,
                  color: atrasado ? scheme.error : null,
                  negrita: atrasado,
                ),
              ),
              Text(
                dinero(p.montoNegocio),
                style: textos.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (p.tieneAlergias)
                EtiquetaPanel(
                  tr('Alergia: {lista}', {'lista': textoAlergias(p)}),
                  icono: Icons.warning_amber_rounded,
                  color: scheme.error,
                ),
              EtiquetaPanel(
                p.cobrado ? '${tr(p.metodoPago)} · ${tr('cobrado')}' : tr(p.metodoPago),
                icono: Icons.payments_outlined,
                color: p.cobrado ? semantic.success : null,
              ),
              if (p.codigoCupon != null) EtiquetaPanel(p.codigoCupon!, icono: Icons.local_offer_outlined),
              if (p.pideFactura) EtiquetaPanel(tr('Factura'), icono: Icons.receipt_outlined),
              if (p.notas.trim().isNotEmpty) EtiquetaPanel(tr('Con nota'), icono: Icons.sticky_note_2_outlined),
              if (p.esDelivery && (p.nombreRepartidor ?? '').isNotEmpty)
                EtiquetaPanel(p.nombreRepartidor!, icono: Icons.two_wheeler_outlined),
              if (p.idiomaCliente != 'es') ChipIdiomaCliente(codigo: p.idiomaCliente),
            ],
          ),
          if (widget.conAccion && puedeAsignar) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            SizedBox(
              width: double.infinity,
              child: p.idRepartidor == null
                  ? FilledButton.icon(
                      onPressed: () => elegirRepartidor(context, p),
                      icon: const Icon(Icons.two_wheeler_outlined),
                      label: Text(tr('Asignar repartidor')),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => elegirRepartidor(context, p),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(tr('Cambiar repartidor')),
                    ),
            ),
            if (p.idRepartidor == null && siguiente != null)
              Center(
                child: TextButton(
                  onPressed: _enviando ? null : () => _avanzar(siguiente),
                  child: Text(textoAccion(p, siguiente)),
                ),
              ),
          ] else if (widget.conAccion && siguiente != null) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _enviando ? null : () => _avanzar(siguiente),
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_iconoAccion(siguiente)),
                label: Text(textoAccion(p, siguiente), overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
