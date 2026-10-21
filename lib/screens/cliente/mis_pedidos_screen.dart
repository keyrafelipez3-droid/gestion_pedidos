import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_iconos_pedido.dart';
import '../../widgets/app_status_badge.dart';
import 'pedido_detalle_screen.dart';

/// HU-28: lista de los pedidos del Cliente, de más reciente a más viejo.
class MisPedidosScreen extends StatelessWidget {
  const MisPedidosScreen({super.key});

  AppStatusTone _tono(String estado) {
    switch (estado) {
      case PedidoEstado.entregado:
        return AppStatusTone.success;
      case PedidoEstado.cancelado:
        return AppStatusTone.danger;
      case PedidoEstado.enPreparacion:
      case PedidoEstado.listo:
      case PedidoEstado.enCamino:
      case PedidoEstado.llego:
        return AppStatusTone.warning;
      default:
        return AppStatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SesionActual.instancia.actual?.idUsuario ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: AppContenidoCentrado(child: StreamBuilder<List<PedidoModel>>(
        stream: PedidoService.instancia.streamPedidosCliente(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pedidos = snapshot.data!;
          if (pedidos.isEmpty) {
            return const AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Todavía no hiciste ningún pedido',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: pedidos.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final p = pedidos[i];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  leading: AvatarModalidad(modalidad: p.modalidad),
                  title: Text(
                    'Pedido #${p.id.substring(0, 6)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${p.modalidad} · Bs ${p.total.toStringAsFixed(2)}'
                    '${p.fechaCreacion == null ? '' : '\n${formatoFechaHora(p.fechaCreacion!)}'}',
                  ),
                  isThreeLine: p.fechaCreacion != null,
                  trailing: AppStatusBadge(label: p.estado, tone: _tono(p.estado)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id)),
                  ),
                ),
              );
            },
          );
        },
      )),
    );
  }
}
