import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/idioma.dart';
import '../../models/alergenos.dart';
import '../../models/caja_models.dart';
import '../../models/catalogo_models.dart';
import '../../models/pedido_models.dart';
import '../../services/caja_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contacto.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/alergias.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/boton_accion.dart';
import '../../widgets/cancelar_pedido.dart';
import '../../widgets/linea_estado_pedido.dart';
import '../../widgets/mapa_seguimiento.dart';
import '../../widgets/texto_traducido.dart';
import 'resena_pedido_card.dart';
import 'ticket_pedido_screen.dart';

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
      appBar: AppBar(title: Text(tr('Detalle del pedido'))),
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
  Widget build(BuildContext context) => _PedidoEnVivo(idPedido: idPedido, esPersonal: esPersonal);
}

/// Camino de Cajero/Cocina: busca el pedido dentro de los pedidos de SU
/// negocio (filtrando por id en memoria, mismo criterio que arriba).
class _DetalleViaNegocio extends StatelessWidget {
  final String idPedido;
  final bool esPersonal;

  const _DetalleViaNegocio({required this.idPedido, required this.esPersonal});

  @override
  Widget build(BuildContext context) {
    if (SesionActual.instancia.idNegocio == null) {
      return Center(child: Text(tr('No se pudo identificar el negocio.')));
    }
    return _PedidoEnVivo(idPedido: idPedido, esPersonal: esPersonal);
  }
}

/// Escucha SOLO el documento del pedido (antes se leían todos los pedidos
/// del cliente o del negocio para encontrar uno).
class _PedidoEnVivo extends StatefulWidget {
  final String idPedido;
  final bool esPersonal;
  const _PedidoEnVivo({required this.idPedido, required this.esPersonal});

  @override
  State<_PedidoEnVivo> createState() => _PedidoEnVivoState();
}

class _PedidoEnVivoState extends State<_PedidoEnVivo> {
  late final Stream<PedidoModel?> _pedido = PedidoService.instancia.streamPedido(widget.idPedido);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PedidoModel?>(
      stream: _pedido,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(tr('No se encontró el pedido.')));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final pedido = snapshot.data;
        if (pedido == null) {
          return Center(child: Text(tr('No se encontró el pedido.')));
        }
        return _Detalle(pedido: pedido, esPersonal: widget.esPersonal);
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

/// Líneas del pedido. Si el cliente tiene alergias, marca en rojo los
/// productos que contienen alguna ("preparar sin cebolla").
class _ProductosDelPedido extends StatefulWidget {
  final PedidoModel pedido;
  const _ProductosDelPedido({required this.pedido});

  @override
  State<_ProductosDelPedido> createState() => _ProductosDelPedidoState();
}

class _ProductosDelPedidoState extends State<_ProductosDelPedido> {
  PedidoModel get pedido => widget.pedido;

  // Se abren una sola vez (la pantalla se redibuja con cada cambio del pedido).
  late final Stream<List<DetallePedidoModel>> _detalle =
      PedidoService.instancia.streamDetalle(pedido.id);
  late final Stream<List<ProductoModel>>? _productos = pedido.tieneAlergias
      ? CatalogoService.instancia.streamProductos(pedido.idNegocio)
      : null;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProductoModel>>(
      stream: _productos,
      builder: (context, snapProductos) {
        final alergenos = {
          for (final p in snapProductos.data ?? const <ProductoModel>[]) p.id: p.alergenos,
        };
        return StreamBuilder<List<DetallePedidoModel>>(
          stream: _detalle,
          builder: (context, snapshot) => _lista(context, snapshot.data ?? const [], alergenos),
        );
      },
    );
  }

  Widget _lista(BuildContext context, List<DetallePedidoModel> items, Map<String, List<String>> alergenos) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final i in items)
          Builder(builder: (context) {
            final conflicto = Alergenos.enComun(alergenos[i.idProducto] ?? const [], pedido.alergias);
            final extras = [...i.variantes, ...i.complementos].map((o) => o.nombre).join(', ');
            return Card(
              shape: conflicto.isEmpty
                  ? null
                  : RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                      side: BorderSide(color: scheme.error, width: 2),
                    ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    '${i.cantidad}x',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                title: Text(
                  i.nombreProducto,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: (extras.isEmpty && i.notas.isEmpty && conflicto.isEmpty)
                    ? null
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (extras.isNotEmpty) Text(extras),
                          if (i.notas.isNotEmpty)
                            TextoTraducido(
                              texto: i.notas,
                              idiomaOrigen: pedido.idiomaCliente,
                              etiqueta: tr('Nota'),
                            ),
                          if (conflicto.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '⚠ ${tr('Contiene {lista}: preparar sin ese ingrediente', {'lista': Alergenos.nombres(conflicto).toLowerCase()})}',
                                style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800),
                              ),
                            ),
                        ],
                      ),
                trailing: Text(tr('Bs {subtotal}', {'subtotal': i.subtotal.toStringAsFixed(2)})),
              ),
            );
          }),
      ],
    );
  }
}

/// Quién registra el cobro de un pedido de la app al entregarlo: el Cajero,
/// salvo un delivery que tomó un repartidor (ese lo cobra el repartidor y
/// lo entrega en caja en la rendición). Un delivery que el local entrega
/// sin repartidor de la app lo cobra el Cajero, para que no quede sin
/// registrar en ninguna caja.
bool _loCobraLaCaja(PedidoModel p) => p.modalidad != PedidoModalidad.delivery || p.idRepartidor == null;

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
    final siguienteFlujo = _siguienteEstado(pedido.estado);
    // Un pedido de la app (Recoger o Mesa) se cobra al entregarlo, en la
    // caja del Cajero. Si lo marcara "Entregado" otro rol (Cocina o
    // Administrador), el pedido quedaría entregado SIN cobro en ninguna caja.
    final requiereCobroCajero = siguienteFlujo == PedidoEstado.entregado &&
        pedido.origen == PedidoOrigen.cliente &&
        _loCobraLaCaja(pedido) &&
        !pedido.cobrado;
    final soloCajeroPuede = requiereCobroCajero && !SesionActual.instancia.esCajero;
    final siguiente = soloCajeroPuede ? null : siguienteFlujo;

    final referencia = (pedido.direccionEntrega?['referencia'] as String?)?.trim() ?? '';
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (pedido.tieneAlergias) ...[
          BandaAlergias(alergias: pedido.alergias, paraPersonal: esPersonal),
          const SizedBox(height: AppSpacing.md),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(tr('Pedido #{id}', {'id': pedido.id.substring(0, 6)}),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    AppStatusBadge(label: pedido.estado, tone: _tonoEstado(pedido.estado)),
                  ],
                ),
                if (pedido.estado != PedidoEstado.cancelado) ...[
                  const SizedBox(height: AppSpacing.md),
                  LineaEstadoPedido(pedido: pedido),
                  const SizedBox(height: AppSpacing.md),
                ] else
                  const SizedBox(height: AppSpacing.sm),
                Text(tr('Modalidad: {etiquetaModalidad}', {'etiquetaModalidad': pedido.etiquetaModalidad})),
                if (pedido.origen == PedidoOrigen.cajero)
                  Text(tr('Registrado por el Cajero')),
                Text(tr('Método de pago: {metodoPago}', {'metodoPago': tr(pedido.metodoPago)})),
                if (pedido.programadoPara != null)
                  Text(
                    tr('Programado para: {hora}', {'hora': formatoProgramado(pedido.programadoPara!)}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (pedido.pideFactura)
                  Text(tr('Factura a: {nit} · {razon}',
                      {'nit': pedido.facturaNit, 'razon': pedido.facturaRazonSocial ?? ''})),
                if (pedido.direccionEntrega != null)
                  Text(tr('Entrega en: {direccion}', {'direccion': pedido.direccionEntrega!['direccion'] ?? ''})),
                if (esPersonal && pedido.idiomaCliente != 'es') ...[
                  const SizedBox(height: AppSpacing.xs),
                  ChipIdiomaCliente(codigo: pedido.idiomaCliente),
                ],
                if (referencia.isNotEmpty)
                  TextoTraducido(
                    texto: referencia,
                    idiomaOrigen: pedido.idiomaCliente,
                    etiqueta: tr('Referencia'),
                    icono: Icons.info_outline,
                  ),
                if (pedido.notas.isNotEmpty)
                  TextoTraducido(
                    texto: pedido.notas,
                    idiomaOrigen: pedido.idiomaCliente,
                    etiqueta: tr('Nota'),
                    destacado: esPersonal,
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (pedido.descuento > 0)
                  Text(tr('Descuento ({codigo}): −Bs {monto}',
                      {'codigo': pedido.codigoCupon ?? '', 'monto': pedido.descuento.toStringAsFixed(2)})),
                if (pedido.costoEnvio > 0)
                  Text(tr('Envío a {zona}: Bs {monto}',
                      {'zona': pedido.zonaEntrega ?? '', 'monto': pedido.costoEnvio.toStringAsFixed(2)})),
                if (pedido.propina > 0)
                  Text(tr('Propina para el repartidor: Bs {monto}', {'monto': pedido.propina.toStringAsFixed(2)})),
                Text(
                  tr('Total: Bs {total}', {'total': pedido.totalACobrar.toStringAsFixed(2)}),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        if (pedido.estado == PedidoEstado.cancelado) ...[
          const SizedBox(height: AppSpacing.md),
          AvisoCancelacion(idPedido: pedido.id),
        ],
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TicketPedidoScreen(pedido: pedido)),
            ),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
            label: Text(tr('Ver ticket')),
          ),
        ),
        if (!esPersonal &&
            pedido.estado == PedidoEstado.entregado &&
            pedido.origen == PedidoOrigen.cliente) ...[
          const SizedBox(height: AppSpacing.md),
          ResenaPedidoCard(pedido: pedido),
        ],
        if (pedido.esDelivery && pedido.enReparto) ...[
          const SizedBox(height: AppSpacing.md),
          _TarjetaRepartidor(pedido: pedido),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(tr('Productos'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: AppSpacing.sm),
        _ProductosDelPedido(pedido: pedido),
        const SizedBox(height: AppSpacing.md),
        Text(tr('Historial'),
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
                        title: Text(tr(h.estado)),
                        subtitle: h.comentario.isEmpty ? null : Text(trComentario(h.comentario)),
                      ))
                  .toList(),
            );
          },
        ),
        if (esPersonal && soloCajeroPuede) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            tr('El Cajero entrega este pedido y registra el cobro en su caja.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
        if (esPersonal && siguiente != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: BotonAccion(
              expandido: true,
              texto: tr('Marcar como "{siguiente}"', {'siguiente': siguiente}),
              onPressed: () async {
                try {
                  // Antes de cobrar, confirma que el pedido sigue en el
                  // estado que ve esta pantalla (evita cobrar y luego fallar).
                  await PedidoService.instancia.verificarCambio(pedido.id, siguiente);
                  // HU-46: el Cajero que entrega un pedido de un cliente lo
                  // cobra en SU caja. Delivery lo cobra el repartidor, y los
                  // pedidos de mesa se cobran al cerrar la mesa.
                  final cajero =
                      SesionActual.instancia.esCajero ? SesionActual.instancia.actual : null;
                  CajaModel? cajaCobro;
                  if (cajero != null &&
                      siguiente == PedidoEstado.entregado &&
                      pedido.origen == PedidoOrigen.cliente &&
                      _loCobraLaCaja(pedido) &&
                      !pedido.cobrado) {
                    cajaCobro = await CajaService.instancia.cajaAbiertaActual(cajero.idUsuario);
                    if (cajaCobro == null || cajaCobro.contada) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            cajaCobro == null
                                ? tr('Abre tu caja (Caja, en el inicio) antes de entregar este pedido.')
                                : tr('Tu caja está en cierre: ya no puedes registrar cobros.'),
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
                    SnackBar(content: Text(tr('Estado actualizado a "{siguiente}".', {'siguiente': siguiente}))),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(textoError(e))),
                  );
                }
              },
            ),
          ),
        ],
        // Cajero o Administrador: cancelar con motivo (cualquier estado que
        // todavía no terminó, incluso En camino). Un pedido ya cobrado no
        // se cancela aquí (el servicio lo explica).
        if (esPersonal &&
            puedeCancelarPedidos() &&
            pedido.estado != PedidoEstado.entregado &&
            pedido.estado != PedidoEstado.cancelado) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
              onPressed: () => cancelarPedidoConMotivo(context, pedido),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(tr('Cancelar pedido')),
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
        ? tr('Tu repartidor')
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
                    llego ? tr('¡{nombre} ya llegó!', {'nombre': nombre}) : tr('{nombre} va en camino', {'nombre': nombre}),
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
                  ? tr('Está en el lugar de entrega. Sal a recibir tu pedido o llámalo si no lo ves.')
                  : tr('Tu pedido ya salió. Puedes llamarlo si necesitas darle alguna indicación.'),
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
              label: Text(tr('Llamar al repartidor')),
            ),
          ],
        ),
      ),
    );
  }
}
