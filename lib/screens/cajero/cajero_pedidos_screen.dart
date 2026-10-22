import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/alergias.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/aviso_pedidos_nuevos.dart';
import '../../widgets/app_iconos_pedido.dart';
import '../../widgets/app_status_badge.dart';
import '../cliente/pedido_detalle_screen.dart';

/// HU-29: el Cajero registra y consulta los pedidos recibidos de su
/// negocio. Pestañas por estado para no tener que buscar entre todos.
class CajeroPedidosScreen extends StatefulWidget {
  const CajeroPedidosScreen({super.key});

  @override
  State<CajeroPedidosScreen> createState() => _CajeroPedidosScreenState();
}

class _CajeroPedidosScreenState extends State<CajeroPedidosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _grupos = <String, List<String>>{
    'Activos': [
      PedidoEstado.pendiente,
      PedidoEstado.enPreparacion,
      PedidoEstado.listo,
      PedidoEstado.enCamino,
      PedidoEstado.llego,
    ],
    'Entregados': [PedidoEstado.entregado],
    'Cancelados': [PedidoEstado.cancelado],
  };

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _grupos.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

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
    final idNegocio = SesionActual.instancia.idNegocio;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pedidos recibidos'),
        bottom: TabBar(controller: _tabs, tabs: _grupos.keys.map((k) => Tab(text: k)).toList()),
      ),
      body: idNegocio == null
          ? const Center(child: Text('No se pudo identificar tu negocio.'))
          : AvisoPedidosNuevos(
              idNegocio: idNegocio,
              child: StreamBuilder<List<PedidoModel>>(
              stream: PedidoService.instancia.streamPedidosNegocio(idNegocio),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pedidos = snapshot.data!;
                return TabBarView(
                  controller: _tabs,
                  children: _grupos.values.map((estados) {
                    final filtrados =
                        pedidos.where((p) => estados.contains(p.estado)).toList();
                    if (filtrados.isEmpty) {
                      return const AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No hay pedidos en esta categoría',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: filtrados.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final p = filtrados[i];
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
                            subtitle: Wrap(
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Bs ${p.total.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                if (p.programadoPara != null)
                                  Chip(
                                    avatar: const Icon(Icons.alarm, size: 16),
                                    label: Text('Para ${formatoProgramado(p.programadoPara!)}'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (p.codigoCupon != null)
                                  Chip(
                                    avatar: const Icon(Icons.local_offer_outlined, size: 16),
                                    label: Text(p.codigoCupon!),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (p.pideFactura)
                                  const Chip(
                                    avatar: Icon(Icons.receipt_outlined, size: 16),
                                    label: Text('Factura'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (p.tieneAlergias) BandaAlergias(alergias: p.alergias, compacta: true),
                                ChipIdiomaCliente(codigo: p.idiomaCliente),
                              ],
                            ),
                            trailing: AppStatusBadge(label: p.estado, tone: _tono(p.estado)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PedidoDetalleScreen(idPedido: p.id, esPersonal: true),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            ),
    );
  }
}
