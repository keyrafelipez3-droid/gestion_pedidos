import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
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
    'Activos': [PedidoEstado.pendiente, PedidoEstado.enPreparacion, PedidoEstado.listo],
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
          : StreamBuilder<List<PedidoModel>>(
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
                              'Pedido #${p.id.substring(0, 6)} · ${p.modalidad}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Text(
                              'Bs ${p.total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
    );
  }
}
