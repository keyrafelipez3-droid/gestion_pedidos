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

  /// Una consulta por pestaña: los activos (en curso) y los entregados /
  /// cancelados de los últimos 7 días. Antes se leían TODOS los pedidos del
  /// negocio, que con el tiempo son miles de lecturas cada vez.
  List<Stream<List<PedidoModel>>>? _streams;
  List<Stream<List<PedidoModel>>> _streamsDe(String idNegocio) => _streams ??= [
        PedidoService.instancia.streamPedidosEnCurso(idNegocio),
        PedidoService.instancia.streamRecientesPorEstado(idNegocio, PedidoEstado.entregado),
        PedidoService.instancia.streamRecientesPorEstado(idNegocio, PedidoEstado.cancelado),
      ];

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
              child: TabBarView(
                  controller: _tabs,
                  children: [
                    for (final (i, stream) in _streamsDe(idNegocio).indexed)
                      StreamBuilder<List<PedidoModel>>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('No se pudieron cargar los pedidos.'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final filtrados = snapshot.data!;
                    if (filtrados.isEmpty) {
                      return AppEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No hay pedidos en esta categoría',
                        message: i == 0 ? null : 'Se muestran los de los últimos 7 días.',
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
                                  'Bs ${p.montoNegocio.toStringAsFixed(2)}',
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
                  },
                      ),
                  ],
                ),
            ),
    );
  }
}
