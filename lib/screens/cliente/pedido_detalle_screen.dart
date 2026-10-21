import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/caja_models.dart';
import '../../models/pedido_models.dart';
import '../../services/caja_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contacto.dart';
import '../../widgets/mapa_seguimiento.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_status_badge.dart';

/// HU-28: el Cliente consulta el detalle de su pedido.
///
/// También la usan las pantallas de Cajero/Cocina (con `esPersonal:
/// true`) para ver el mismo detalle Y además tener el control de avanzar
/// el estado — así no se duplica la pantalla entera solo por esa
/// diferencia.
class PedidoDetalleScreen extends StatelessWidget {
  final String idPedido;
  final bool esPersonal;

  const PedidoDetalleScreen({super.key, required this.idPedido, this.esPersonal = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pedido')),
      body: AppContenidoCentrado(
        child: esPersonal
            ? _DetalleViaNegocio(idPedido: idPedido, esPersonal: esPersonal)
            : _DetalleViaCliente(idPedido: idPedido, esPersonal: esPersonal),
      ),
    );
  }
}

/// Camino normal del Cliente: busca el pedido dentro de SU PROPIO
/// stream de pedidos (filtrando por id en memoria — no existe un
/// `streamPedidoPorId` aparte, no hizo falta agregarlo solo para esto).
class _DetalleViaCliente extends StatelessWidget {
  final String idPedido;
  final bool esPersonal;

  const _DetalleViaCliente({required this.idPedido, required this.esPersonal});

  @override
  Widget build(BuildContext context) {
    final uid = SesionActual.instancia.actual?.idUsuario ?? '';
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService.instancia.streamPedidosCliente(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pedido = snapshot.data!.where((p) => p.id == idPedido).toList();
        if (pedido.isEmpty) {
          return const Center(child: Text('No se encontró el pedido.'));
        }
        return _Detalle(pedido: pedido.first, esPersonal: esPersonal);
      },
    );
  }
}

/// Camino de Cajero/Cocina: busca el pedido dentro de los pedidos de SU
/// negocio (filtrando por id en memoria, mismo criterio que arriba).
class _DetalleViaNegocio extends StatelessWidget {
  final String idPedido;
  final bool esPersonal;

  const _DetalleViaNegocio({required this.idPedido, required this.esPersonal});

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;
    if (idNegocio == null) {
      return const Center(child: Text('No se pudo identificar el negocio.'));
    }
    return StreamBuilder<List<PedidoModel>>(
      stream: PedidoService.instancia.streamPedidosNegocio(idNegocio),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pedido = snapshot.data!.where((p) => p.id == idPedido).toList();
        if (pedido.isEmpty) {
          return const Center(child: Text('No se encontró el pedido.'));
        }
        return _Detalle(pedido: pedido.first, esPersonal: esPersonal);
      },
    );
  }
}

AppStatusTone _tonoEstado(String estado) {
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

String? _siguienteEstado(String actual) {
  // Delivery: si el pedido ya salió con un repartidor, el personal solo
  // puede cerrarlo como entregado (el avance normal lo hace el repartidor).
  if (actual == PedidoEstado.enCamino || actual == PedidoEstado.llego) {
    return PedidoEstado.entregado;
  }
  const flujo = [
    PedidoEstado.pendiente,
    PedidoEstado.enPreparacion,
    PedidoEstado.listo,
    PedidoEstado.entregado,
  ];
  final i = flujo.indexOf(actual);
  if (i == -1 || i == flujo.length - 1) return null;
  return flujo[i + 1];
}

class _Detalle extends StatelessWidget {
  final PedidoModel pedido;
  final bool esPersonal;

  const _Detalle({required this.pedido, required this.esPersonal});

  @override
  Widget build(BuildContext context) {
    final siguiente = _siguienteEstado(pedido.estado);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pedido #${pedido.id.substring(0, 6)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    AppStatusBadge(label: pedido.estado, tone: _tonoEstado(pedido.estado)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Modalidad: ${pedido.etiquetaModalidad}'),
                if (pedido.origen == PedidoOrigen.cajero)
                  const Text('Registrado por el Cajero'),
                Text('Método de pago: ${pedido.metodoPago}'),
                if (pedido.direccionEntrega != null)
                  Text('Entrega en: ${pedido.direccionEntrega!['direccion'] ?? ''}'),
                if (pedido.notas.isNotEmpty) Text('Nota: ${pedido.notas}'),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Total: Bs ${pedido.total.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        if (pedido.esDelivery && pedido.enReparto) ...[
          const SizedBox(height: AppSpacing.md),
          _TarjetaRepartidor(pedido: pedido),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Productos',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<DetallePedidoModel>>(
          stream: PedidoService.instancia.streamDetalle(pedido.id),
          builder: (context, snapshot) {
            final items = snapshot.data ?? [];
            return Column(
              children: items
                  .map((i) => Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                            child: Text(
                              '${i.cantidad}x',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                          title: Text(
                            i.nombreProducto,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: [...i.variantes, ...i.complementos].isEmpty
                              ? null
                              : Text(
                                  [...i.variantes, ...i.complementos]
                                      .map((o) => o.nombre)
                                      .join(', '),
                                ),
                          trailing: Text('Bs ${i.subtotal.toStringAsFixed(2)}'),
                        ),
                      ))
                  .toList(),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Historial',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<HistorialEstadoModel>>(
          stream: PedidoService.instancia.streamHistorial(pedido.id),
          builder: (context, snapshot) {
            final historial = snapshot.data ?? [];
            return Column(
              children: historial
                  .map((h) => ListTile(
                        leading: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        title: Text(h.estado),
                        subtitle: h.comentario.isEmpty ? null : Text(h.comentario),
                      ))
                  .toList(),
            );
          },
        ),
        if (esPersonal && siguiente != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                try {
                  // HU-46: el Cajero que entrega un pedido de un cliente lo
                  // cobra en SU caja. Delivery lo cobra el repartidor, y los
                  // pedidos de mesa se cobran al cerrar la mesa.
                  final cajero =
                      SesionActual.instancia.esCajero ? SesionActual.instancia.actual : null;
                  CajaModel? cajaCobro;
                  if (cajero != null &&
                      siguiente == PedidoEstado.entregado &&
                      pedido.origen == PedidoOrigen.cliente &&
                      pedido.modalidad != PedidoModalidad.delivery &&
                      !pedido.cobrado) {
                    cajaCobro = await CajaService.instancia.cajaAbiertaActual(cajero.idUsuario);
                    if (cajaCobro == null || cajaCobro.contada) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            cajaCobro == null
                                ? 'Abre tu caja (Caja, en el inicio) antes de entregar este pedido.'
                                : 'Tu caja está en cierre: ya no puedes registrar cobros.',
                          ),
                        ),
                      );
                      return;
                    }
                    await CajaService.instancia.cobrarPedido(
                      caja: cajaCobro,
                      pedido: pedido,
                      idUsuario: cajero.idUsuario,
                    );
                  }
                  await PedidoService.instancia.cambiarEstado(
                    idPedido: pedido.id,
                    nuevoEstado: siguiente,
                    idUsuarioQueCambio: SesionActual.instancia.actual?.idUsuario ?? '',
                    limpiarUbicacion: pedido.enReparto,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Estado actualizado a "$siguiente".')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('No se pudo actualizar: $e')),
                  );
                }
              },
              child: Text('Marcar como "$siguiente"'),
            ),
          ),
        ],
      ],
    );
  }
}

LatLng? _destino(PedidoModel pedido) {
  final lat = (pedido.direccionEntrega?['latitud'] as num?)?.toDouble();
  final lng = (pedido.direccionEntrega?['longitud'] as num?)?.toDouble();
  return (lat != null && lng != null) ? LatLng(lat, lng) : null;
}

/// Datos del repartidor mientras el pedido está en camino: nombre, aviso de
/// llegada y botón para llamarlo.
class _TarjetaRepartidor extends StatelessWidget {
  final PedidoModel pedido;

  const _TarjetaRepartidor({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final llego = pedido.estado == PedidoEstado.llego;
    final nombre = (pedido.nombreRepartidor ?? '').isEmpty
        ? 'Tu repartidor'
        : pedido.nombreRepartidor!;
    return Card(
      color: llego ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  llego ? Icons.notifications_active : Icons.two_wheeler_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    llego ? '¡$nombre ya llegó!' : '$nombre va en camino',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              llego
                  ? 'Está en el lugar de entrega. Sal a recibir tu pedido o '
                      'llámalo si no lo ves.'
                  : 'Tu pedido ya salió. Puedes llamarlo si necesitas darle '
                      'alguna indicación.',
            ),
            const SizedBox(height: AppSpacing.sm),
            MapaSeguimiento(
              destino: _destino(pedido),
              repartidor: (pedido.latRepartidor != null && pedido.lngRepartidor != null)
                  ? LatLng(pedido.latRepartidor!, pedido.lngRepartidor!)
                  : null,
              actualizado: pedido.ubicacionActualizada,
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: () => llamarPorTelefono(context, pedido.telefonoRepartidor),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Llamar al repartidor'),
            ),
          ],
        ),
      ),
    );
  }
}
