import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_iconos_pedido.dart';
import '../../widgets/app_status_badge.dart';
import '../cliente/pedido_detalle_screen.dart';

/// HU-30/31: Cocina consulta los pedidos pendientes/en preparación y
/// actualiza el estado conforme va cocinando.
class CocinaPedidosScreen extends StatelessWidget {
  const CocinaPedidosScreen({super.key});

  Future<void> _avanzar(BuildContext context, PedidoModel pedido, String siguiente) async {
    try {
      await PedidoService.instancia.cambiarEstado(
        idPedido: pedido.id,
        nuevoEstado: siguiente,
        idUsuarioQueCambio: SesionActual.instancia.actual?.idUsuario ?? '',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;
    return Scaffold(
      appBar: AppBar(title: const Text('Pedidos pendientes (Cocina)')),
      body: idNegocio == null
          ? const Center(child: Text('No se pudo identificar tu negocio.'))
          : StreamBuilder<List<PedidoModel>>(
              stream: PedidoService.instancia.streamPedidosCocina(idNegocio),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pedidos = snapshot.data!;
                if (pedidos.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.soup_kitchen_outlined,
                    title: 'No hay pedidos pendientes',
                    message: 'Los nuevos pedidos van a aparecer acá apenas lleguen.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: pedidos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final p = pedidos[i];
                    final enPreparacion = p.estado == PedidoEstado.enPreparacion;
                    return Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        leading: AvatarModalidad(modalidad: p.modalidad),
                        title: Text(
                          'Pedido #${p.id.substring(0, 6)} · ${p.etiquetaModalidad}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AppStatusBadge(
                              label: p.estado,
                              tone: enPreparacion ? AppStatusTone.warning : AppStatusTone.neutral,
                            ),
                          ),
                        ),
                        trailing: FilledButton(
                          onPressed: () => _avanzar(
                            context,
                            p,
                            enPreparacion ? PedidoEstado.listo : PedidoEstado.enPreparacion,
                          ),
                          child: Text(enPreparacion ? 'Marcar listo' : 'Empezar'),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
