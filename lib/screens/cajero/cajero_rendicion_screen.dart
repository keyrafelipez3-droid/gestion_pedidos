import 'package:flutter/material.dart';

import '../../models/actividad_model.dart';
import '../../models/pedido_models.dart';
import '../../services/actividad_service.dart';
import '../../services/caja_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../widgets/app_empty_state.dart';

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
      appBar: AppBar(title: const Text('Rendición de repartidores')),
      body: stream == null
          ? const Center(child: Text('No se pudo identificar tu negocio.'))
          : StreamBuilder<List<PedidoModel>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text(textoError(snap.error!)));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final rendiciones = RendicionRepartidor.agrupar(snap.data!);
                if (rendiciones.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.two_wheeler_outlined,
                    title: 'Nada pendiente',
                    message: 'Cuando un repartidor entregue pedidos, aquí verás cuánto '
                        'efectivo debe entregar en caja.',
                  );
                }
                final scheme = Theme.of(context).colorScheme;
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    Text(
                      'Pedidos de delivery entregados en los últimos 7 días que todavía no '
                      'se registraron en caja.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (final r in rendiciones)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: scheme.primaryContainer,
                                    child: Icon(Icons.delivery_dining, color: scheme.onPrimaryContainer),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Text(r.nombre,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            )),
                                  ),
                                  Text('${r.pedidos.length} pedido(s)'),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Efectivo a entregar: Bs ${r.efectivo.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: scheme.primary,
                                    ),
                              ),
                              if (r.digital > 0) Text('QR / transferencia: Bs ${r.digital.toStringAsFixed(2)}'),
                              if (r.propinas > 0)
                                Text('Propinas del repartidor: Bs ${r.propinas.toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: AppSpacing.xs),
                              Wrap(
                                spacing: AppSpacing.xs,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  for (final p in r.pedidos)
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(
                                        '#${p.id.substring(0, 6)} · ${p.metodoPago} · Bs ${p.montoNegocio.toStringAsFixed(2)}',
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _procesando == null ? () => _recibir(r) : null,
                                  icon: _procesando == r.idRepartidor
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.payments_outlined),
                                  label: const Text('Recibir y registrar en caja'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
