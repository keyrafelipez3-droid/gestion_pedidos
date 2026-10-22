import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/boton_accion.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/alergias.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/aviso_pedidos_nuevos.dart';
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
        SnackBar(content: Text(textoError(e))),
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
          : AvisoPedidosNuevos(
              idNegocio: idNegocio,
              child: StreamBuilder<List<PedidoModel>>(
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
                // Primero lo que hay que preparar ya (los programados, por
                // su hora); al final los programados para más tarde.
                DateTime hora(PedidoModel p) => p.programadoPara ?? p.fechaCreacion ?? DateTime(0);
                final ahora = pedidos.where((p) => !p.esParaMasTarde).toList()
                  ..sort((a, b) => hora(a).compareTo(hora(b)));
                final despues = pedidos.where((p) => p.esParaMasTarde).toList()
                  ..sort((a, b) => hora(a).compareTo(hora(b)));
                final filas = <Object>[
                  ...ahora,
                  if (despues.isNotEmpty) 'Programados para más tarde (${despues.length})',
                  ...despues,
                ];
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: filas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final fila = filas[i];
                    if (fila is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 20),
                            const SizedBox(width: AppSpacing.sm),
                            Text(fila, style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      );
                    }
                    final p = fila as PedidoModel;
                    final enPreparacion = p.estado == PedidoEstado.enPreparacion;
                    return Card(
                      shape: p.tieneAlergias
                          ? RoundedRectangleBorder(
                              borderRadius: AppRadius.mdAll,
                              side: const BorderSide(color: Color(0xFFB3261E), width: 2),
                            )
                          : null,
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
                          child: Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              AppStatusBadge(
                                label: p.estado,
                                tone: enPreparacion ? AppStatusTone.warning : AppStatusTone.neutral,
                              ),
                              if (p.programadoPara != null)
                                Chip(
                                  avatar: const Icon(Icons.alarm, size: 16),
                                  label: Text('Para ${formatoProgramado(p.programadoPara!)}'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (p.tieneAlergias) BandaAlergias(alergias: p.alergias, compacta: true),
                              if (p.notas.isNotEmpty)
                                const Chip(
                                  avatar: Icon(Icons.sticky_note_2_outlined, size: 16),
                                  label: Text('Tiene nota'),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ChipIdiomaCliente(codigo: p.idiomaCliente),
                            ],
                          ),
                        ),
                        trailing: BotonAccion(
                          texto: enPreparacion ? 'Marcar listo' : 'Empezar',
                          onPressed: () => _avanzar(
                            context,
                            p,
                            enPreparacion ? PedidoEstado.listo : PedidoEstado.enPreparacion,
                          ),
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
            ),
    );
  }
}
