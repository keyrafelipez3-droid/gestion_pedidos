import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/pedido_models.dart';
import '../../services/negocio_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_iconos_pedido.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/consulta_paginada.dart';
import 'carrito_screen.dart';
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

  /// Copia el pedido al carrito y abre el carrito para confirmarlo.
  Future<void> _volverAPedir(BuildContext context, PedidoModel p) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final uid = SesionActual.instancia.actual?.idUsuario ?? '';
    try {
      final r = await PedidoService.instancia.repetirPedido(idCliente: uid, pedido: p);
      if (r.agregados == 0) {
        messenger.showSnackBar(SnackBar(
          content: Text(tr('Los productos de ese pedido ya no están disponibles.')),
        ));
        return;
      }
      if (r.noDisponibles.isNotEmpty) {
        messenger.showSnackBar(SnackBar(
          content: Text(tr('No se agregaron (ya no están disponibles): {lista}',
              {'lista': r.noDisponibles.join(', ')})),
        ));
      }
      final negocio = await NegocioService.instancia.obtenerNegocioPorId(p.idNegocio);
      navigator.push(MaterialPageRoute(
        builder: (_) => CarritoScreen(negocio: negocio, idSucursal: p.idSucursal),
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr('No se pudo repetir el pedido. Intenta de nuevo.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = SesionActual.instancia.actual?.idUsuario ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mis pedidos'))),
      body: AppContenidoCentrado(child: ConsultaPaginada<PedidoModel>(
        consulta: (n) => PedidoService.instancia.streamPedidosClientePaginado(uid, n),
        builder: (context, snapshot, verMas) {
          if (snapshot.hasError && !snapshot.hasData) {
            return Center(child: Text(tr('No se pudieron cargar tus pedidos. Intenta de nuevo.')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pedidos = snapshot.data!;
          if (pedidos.isEmpty) {
            return AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: tr('Todavía no hiciste ningún pedido'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: pedidos.length + (verMas == null ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              if (i == pedidos.length) return verMas!;
              final p = pedidos[i];
              final puedeRepetir = p.estado == PedidoEstado.entregado || p.estado == PedidoEstado.cancelado;
              return Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  leading: AvatarModalidad(modalidad: p.modalidad),
                  title: Text(
                    tr('Pedido #{id}', {'id': p.id.substring(0, 6)}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${tr(p.modalidad)} · Bs ${p.total.toStringAsFixed(2)}'
                    '${p.fechaCreacion == null ? '' : '\n${formatoFechaHora(p.fechaCreacion!)}'}',
                  ),
                  isThreeLine: p.fechaCreacion != null,
                  trailing: AppStatusBadge(label: p.estado, tone: _tono(p.estado)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id)),
                  ),
                ),
                if (puedeRepetir)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs),
                    child: TextButton.icon(
                      onPressed: () => _volverAPedir(context, p),
                      icon: const Icon(Icons.replay, size: 18),
                      label: Text(tr('Volver a pedir')),
                    ),
                  ),
                  ],
                ),
              );
            },
          );
        },
      )),
    );
  }
}
