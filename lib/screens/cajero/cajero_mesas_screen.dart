import 'package:flutter/material.dart';

import '../../models/mesa_model.dart';
import '../../models/pedido_models.dart';
import '../../services/caja_service.dart';
import '../../services/mesa_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../cliente/pedido_detalle_screen.dart';
import 'cajero_pedido_mesa_screen.dart';

/// HU-32: el Cajero gestiona las mesas de su sucursal. Recibe a los
/// clientes en la puerta, les asigna una mesa (queda Ocupada, con cuántas
/// personas son si lo sabe), registra los pedidos de esa mesa y, al final,
/// cierra la cuenta y la libera.
class CajeroMesasScreen extends StatelessWidget {
  const CajeroMesasScreen({super.key});

  Future<void> _nuevaMesa(BuildContext context, String idSucursal) async {
    final numeroCtrl = TextEditingController();
    final capacidadCtrl = TextEditingController(text: '4');
    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva mesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numeroCtrl,
              decoration: const InputDecoration(labelText: 'Número / nombre de la mesa'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: capacidadCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacidad (personas)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Crear')),
        ],
      ),
    );
    if (crear != true || numeroCtrl.text.trim().isEmpty) return;
    await MesaService.instancia.guardarMesa(
      idSucursal,
      MesaModel(
        id: '',
        numero: numeroCtrl.text.trim(),
        capacidad: int.tryParse(capacidadCtrl.text) ?? 4,
        idNegocio: SesionActual.instancia.idNegocio,
      ),
    );
  }

  /// El cliente llegó y el Cajero le asigna esta mesa. Lo único que se
  /// pregunta es para cuántas personas es (opcional).
  Future<void> _asignarMesa(BuildContext context, String idSucursal, MesaModel mesa) async {
    final personasCtrl = TextEditingController();
    final asignar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Asignar mesa ${mesa.numero}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Esta mesa es para ${mesa.capacidad} personas.'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: personasCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '¿Para cuántas personas? (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Asignar')),
        ],
      ),
    );
    if (asignar != true) return;
    final personas = int.tryParse(personasCtrl.text.trim());
    try {
      await MesaService.instancia.asignarMesa(
        idSucursal,
        mesa.id,
        personas: (personas != null && personas > 0) ? personas : null,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo asignar la mesa: $e')),
      );
    }
  }

  void _tomarPedido(BuildContext context, String idSucursal, MesaModel mesa) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CajeroPedidoMesaScreen(mesa: mesa, idSucursal: idSucursal),
      ),
    );
  }

  void _verCuenta(BuildContext context, String idSucursal, MesaModel mesa) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CuentaMesaSheet(mesa: mesa, idSucursal: idSucursal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idSucursal = SesionActual.instancia.idSucursal;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesas')),
      floatingActionButton: idSucursal == null
          ? null
          : FloatingActionButton(
              tooltip: 'Nueva mesa',
              onPressed: () => _nuevaMesa(context, idSucursal),
              child: const Icon(Icons.add),
            ),
      body: idSucursal == null
          ? const Center(child: Text('No tienes una sucursal asignada.'))
          : StreamBuilder<List<MesaModel>>(
              stream: MesaService.instancia.streamMesas(idSucursal),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final mesas = snapshot.data!;
                if (mesas.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.table_bar_outlined,
                    title: 'Todavía no hay mesas registradas',
                    actionLabel: 'Nueva mesa',
                    onAction: () => _nuevaMesa(context, idSucursal),
                  );
                }
                return AppContenidoCentrado(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      88, // espacio para que el botón flotante no tape la última mesa
                    ),
                    itemCount: mesas.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _TarjetaMesa(
                      mesa: mesas[i],
                      idSucursal: idSucursal,
                      onAsignar: () => _asignarMesa(context, idSucursal, mesas[i]),
                      onTomarPedido: () => _tomarPedido(context, idSucursal, mesas[i]),
                      onVerCuenta: () => _verCuenta(context, idSucursal, mesas[i]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

AppStatusTone _tonoMesa(String estado) {
  switch (estado) {
    case MesaEstado.libre:
      return AppStatusTone.success;
    case MesaEstado.ocupada:
      return AppStatusTone.danger;
    case MesaEstado.reservada:
      return AppStatusTone.warning;
    default:
      return AppStatusTone.neutral;
  }
}

class _TarjetaMesa extends StatelessWidget {
  final MesaModel mesa;
  final String idSucursal;
  final VoidCallback onAsignar;
  final VoidCallback onTomarPedido;
  final VoidCallback onVerCuenta;

  const _TarjetaMesa({
    required this.mesa,
    required this.idSucursal,
    required this.onAsignar,
    required this.onTomarPedido,
    required this.onVerCuenta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocupada = mesa.estado == MesaEstado.ocupada;
    final subtitulo = ocupada && mesa.personas != null
        ? '${mesa.personas} personas · capacidad ${mesa.capacidad}'
        : 'Capacidad: ${mesa.capacidad} personas';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mesa ${mesa.numero}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitulo,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                AppStatusBadge(label: mesa.estado, tone: _tonoMesa(mesa.estado)),
                // Una mesa ocupada solo se libera cerrando su cuenta (así
                // no quedan pedidos abiertos sin cobrar); en las demás se
                // puede marcar a mano como Libre o Reservada.
                if (!ocupada)
                  PopupMenuButton<String>(
                    tooltip: 'Cambiar estado',
                    onSelected: (nuevo) =>
                        MesaService.instancia.cambiarEstado(idSucursal, mesa.id, nuevo),
                    itemBuilder: (_) => [
                      for (final e in MesaEstado.todos)
                        if (e != mesa.estado && e != MesaEstado.ocupada)
                          PopupMenuItem(value: e, child: Text('Marcar como $e')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (ocupada)
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton.icon(
                    onPressed: onTomarPedido,
                    icon: const Icon(Icons.restaurant_menu_outlined),
                    label: const Text('Tomar pedido'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onVerCuenta,
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Ver cuenta'),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: onAsignar,
                icon: const Icon(Icons.event_seat_outlined),
                label: const Text('Asignar mesa'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Cuenta abierta de una mesa: los pedidos que el Cajero registró para
/// ella, el total a cobrar y el botón para cerrarla.
class _CuentaMesaSheet extends StatelessWidget {
  final MesaModel mesa;
  final String idSucursal;

  const _CuentaMesaSheet({required this.mesa, required this.idSucursal});

  AppStatusTone _tonoPedido(String estado) {
    switch (estado) {
      case PedidoEstado.entregado:
        return AppStatusTone.success;
      case PedidoEstado.cancelado:
        return AppStatusTone.danger;
      case PedidoEstado.enPreparacion:
      case PedidoEstado.listo:
        return AppStatusTone.warning;
      default:
        return AppStatusTone.neutral;
    }
  }

  Future<void> _cerrarMesa(
    BuildContext context,
    String idNegocio,
    List<PedidoModel> pedidos,
    double total,
  ) async {
    // HU-46: no se cobra sin caja abierta (y que no esté ya en cierre).
    final cajero = SesionActual.instancia.actual;
    final caja = cajero == null
        ? null
        : await CajaService.instancia.cajaAbiertaActual(cajero.idUsuario);
    if (!context.mounted) return;
    if (cajero == null || caja == null || caja.contada) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(caja == null ? 'Primero abre tu caja' : 'Tu caja está en cierre'),
          content: Text(
            caja == null
                ? 'Para cobrar una mesa necesitas una caja abierta. Ábrela '
                    'desde Caja, en el inicio.'
                : 'Ya contaste el efectivo de tu caja, así que no se pueden '
                    'registrar más cobros. Ciérrala desde Caja.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final sinEntregar = pedidos
        .where((p) => p.estado != PedidoEstado.entregado && p.estado != PedidoEstado.cancelado)
        .length;
    var metodo = MetodoPago.efectivo;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Cerrar mesa ${mesa.numero}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total a cobrar: Bs ${total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (sinEntregar > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    sinEntregar == 1
                        ? 'Atención: 1 pedido todavía no está entregado.'
                        : 'Atención: $sinEntregar pedidos todavía no están entregados.',
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: metodo,
                decoration: const InputDecoration(labelText: 'Método de pago'),
                items: MetodoPago.todos
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setLocal(() => metodo = v ?? metodo),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cerrar y liberar'),
            ),
          ],
        ),
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await CajaService.instancia.cobrarMesa(
        caja: caja,
        mesa: mesa,
        metodoPago: metodo,
        idUsuario: cajero.idUsuario,
      );
      await MesaService.instancia.liberarMesa(idSucursal, mesa.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Mesa ${mesa.numero} cerrada y liberada.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo cerrar la mesa: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idNegocio = SesionActual.instancia.idNegocio;
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.4;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: idNegocio == null
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Text('No se pudo identificar el negocio.'),
              )
            : StreamBuilder<List<PedidoModel>>(
                stream: PedidoService.instancia.streamCuentaMesa(idNegocio, mesa.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final pedidos = snapshot.data!;
                  final total = pedidos
                      .where((p) => p.estado != PedidoEstado.cancelado)
                      .fold<double>(0, (acc, p) => acc + p.total);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cuenta · Mesa ${mesa.numero}',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (mesa.personas != null)
                        Text(
                          '${mesa.personas} personas',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      if (pedidos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Text('Todavía no hay pedidos en esta mesa.'),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: altoMaximo),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final p in pedidos)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    'Pedido #${p.id.substring(0, 6)}',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AppStatusBadge(
                                      label: p.estado,
                                      tone: _tonoPedido(p.estado),
                                    ),
                                  ),
                                  trailing: Text('Bs ${p.total.toStringAsFixed(2)}'),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PedidoDetalleScreen(idPedido: p.id, esPersonal: true),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total', style: theme.textTheme.titleMedium),
                          Text(
                            'Bs ${total.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _cerrarMesa(context, idNegocio, pedidos, total),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Cerrar mesa y cobrar'),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
