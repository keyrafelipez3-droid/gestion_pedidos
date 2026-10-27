import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/actividad_model.dart';
import '../../models/pedido_models.dart';
import '../../services/actividad_service.dart';
import '../../services/caja_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/panel_personal.dart';
import '../../widgets/tarjeta_pedido_personal.dart';

/// Pedidos de delivery entregados que todavía no pasaron por caja,
/// agrupados por repartidor.
class RendicionRepartidor {
  final String idRepartidor;
  final String nombre;
  final List<PedidoModel> pedidos;

  const RendicionRepartidor(this.idRepartidor, this.nombre, this.pedidos);

  /// Efectivo que el repartidor debe entregar (productos + envío; la
  /// propina se la queda él).
  double get efectivo => pedidos
      .where((p) => p.metodoPago == MetodoPago.efectivo)
      .fold(0, (a, p) => a + p.montoNegocio);

  /// Pagos por QR o transferencia (ya están en la cuenta del negocio).
  double get digital => pedidos
      .where((p) => p.metodoPago != MetodoPago.efectivo)
      .fold(0, (a, p) => a + p.montoNegocio);

  double get propinas => pedidos.fold(0, (a, p) => a + p.propina);

  /// Agrupa los pedidos entregados de delivery que faltan registrar en caja.
  static List<RendicionRepartidor> agrupar(List<PedidoModel> entregados) {
    final grupos = <String, List<PedidoModel>>{};
    for (final p in entregados) {
      if (p.modalidad != PedidoModalidad.delivery || p.cobrado || p.idRepartidor == null) continue;
      grupos.putIfAbsent(p.idRepartidor!, () => []).add(p);
    }
    final lista = [
      for (final e in grupos.entries)
        RendicionRepartidor(e.key, e.value.first.nombreRepartidor ?? 'Repartidor', e.value),
    ]..sort((a, b) => a.nombre.compareTo(b.nombre));
    return lista;
  }
}

/// Cajero: recibe el efectivo que traen los repartidores y registra sus
/// entregas en la caja abierta.
class CajeroRendicionScreen extends StatefulWidget {
  const CajeroRendicionScreen({super.key});

  @override
  State<CajeroRendicionScreen> createState() => _CajeroRendicionScreenState();
}

class _CajeroRendicionScreenState extends State<CajeroRendicionScreen> {
  late final String? _idNegocio = SesionActual.instancia.idNegocio;
  late final Stream<List<PedidoModel>>? _stream = _idNegocio == null
      ? null
      : PedidoService.instancia.streamRecientesPorEstado(_idNegocio, PedidoEstado.entregado, dias: 7);
  String? _procesando;

  Future<void> _recibir(RendicionRepartidor r) async {
    final cajero = SesionActual.instancia.actual;
    if (cajero == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final caja = await CajaService.instancia.cajaAbiertaActual(cajero.idUsuario);
    if (caja == null || caja.contada) {
      messenger.showSnackBar(SnackBar(
        content: Text(caja == null
            ? 'Abre tu caja (Caja, en el inicio) antes de recibir la rendición.'
            : 'Tu caja está en cierre: ya no puedes registrar cobros.'),
      ));
      return;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rendición de ${r.nombre}'),
        content: Text(
          '${r.pedidos.length} pedido(s) entregado(s).\n\n'
          'Efectivo a recibir: Bs ${r.efectivo.toStringAsFixed(2)}\n'
          'Pagos por QR/transferencia: Bs ${r.digital.toStringAsFixed(2)}\n'
          '${r.propinas > 0 ? 'Propinas (se las queda el repartidor): Bs ${r.propinas.toStringAsFixed(2)}\n' : ''}'
          '\nCuenta el efectivo antes de confirmar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Recibí el dinero')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _procesando = r.idRepartidor);
    try {
      final n = await CajaService.instancia.recibirRendicion(
        caja: caja,
        pedidos: r.pedidos,
        idUsuario: cajero.idUsuario,
      );
      ActividadService.instancia.registrar(
        ActividadTipo.caja,
        'Recibió la rendición de ${r.nombre}: $n pedido(s), efectivo Bs ${r.efectivo.toStringAsFixed(2)}',
      );
      messenger.showSnackBar(SnackBar(content: Text('Rendición de ${r.nombre} registrada en tu caja.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Rendición de repartidores'))),
      body: stream == null
          ? Center(child: Text(tr('No se pudo identificar tu negocio.')))
          : StreamBuilder<List<PedidoModel>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text(textoError(snap.error!)));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rendiciones = RendicionRepartidor.agrupar(snap.data!);
                if (rendiciones.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.two_wheeler_outlined,
                    title: tr('Nada pendiente'),
                    message: tr('Cuando un repartidor entregue pedidos, aquí verás cuánto efectivo debe entregar en caja.'),
                  );
                }
                final efectivo = rendiciones.fold(0.0, (a, r) => a + r.efectivo);
                final pedidos = rendiciones.fold(0, (a, r) => a + r.pedidos.length);
                return AppContenidoCentrado(
                  maxWidth: 820,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      ResumenTurno(datos: [
                        DatoTurno(dinero(efectivo), tr('efectivo por recibir'), icono: Icons.payments_outlined),
                        DatoTurno('$pedidos', tr('entregas sin rendir'), icono: Icons.receipt_long_outlined),
                        DatoTurno('${rendiciones.length}', tr('repartidores'), icono: Icons.two_wheeler_outlined),
                      ]),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        tr('Entregas de delivery de los últimos 7 días que todavía no se registraron en caja.'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final r in rendiciones) ...[
                        _TarjetaRendicion(
                          rendicion: r,
                          procesando: _procesando == r.idRepartidor,
                          habilitado: _procesando == null,
                          onRecibir: () => _recibir(r),
                        ),
                        const SizedBox(height: AppSpacing.sm + 4),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

/// Lo que debe entregar un repartidor: el efectivo en grande, sus
/// entregas (se pueden desplegar) y el botón con el monto exacto.
class _TarjetaRendicion extends StatelessWidget {
  final RendicionRepartidor rendicion;
  final bool procesando;
  final bool habilitado;
  final VoidCallback onRecibir;

  const _TarjetaRendicion({
    required this.rendicion,
    required this.procesando,
    required this.habilitado,
    required this.onRecibir,
  });

  @override
  Widget build(BuildContext context) {
    final r = rendicion;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return TarjetaPanel(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Text(
                  r.nombre.isEmpty ? '?' : r.nombre.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nombre, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      tr('{n} entrega(s)', {'n': r.pedidos.length}),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dinero(r.efectivo),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  Text(tr('en efectivo'), style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs + 2,
            runSpacing: AppSpacing.xs + 2,
            children: [
              if (r.digital > 0)
                EtiquetaPanel(tr('QR / transferencia: {monto}', {'monto': dinero(r.digital)}),
                    icono: Icons.qr_code_2),
              if (r.propinas > 0)
                EtiquetaPanel(tr('Propinas (son del repartidor): {monto}', {'monto': dinero(r.propinas)}),
                    icono: Icons.volunteer_activism_outlined),
            ],
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(tr('Ver entregas'), style: theme.textTheme.bodyMedium),
              children: [
                for (final p in r.pedidos)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${numeroPedido(p)} · ${tr(p.metodoPago)}'
                            '${p.fechaCreacion == null ? '' : ' · ${formatoHora(p.fechaCreacion!)}'}',
                          ),
                        ),
                        Text(dinero(p.montoNegocio), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: habilitado ? onRecibir : null,
            icon: procesando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.payments_outlined),
            label: Text(tr('Recibí {monto}', {'monto': dinero(r.efectivo)})),
          ),
        ],
      ),
    );
  }
}
