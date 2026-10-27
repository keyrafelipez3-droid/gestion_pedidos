import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/caja_models.dart';
import '../models/pedido_models.dart';
import '../models/usuario_model.dart';
import '../services/caja_service.dart';
import '../services/pedido_service.dart';
import '../services/sesion_actual.dart';
import '../theme/design_tokens.dart';
import 'errores.dart';
import 'formato.dart';

/// Acciones del personal sobre un pedido (avanzar el estado, entregar y
/// cobrar, asignar repartidor). Las usan el detalle del pedido y las
/// tarjetas de los paneles, para que el botón haga exactamente lo mismo en
/// los dos lugares.

/// Quién registra el cobro de un pedido de la app al entregarlo: el Cajero,
/// salvo un delivery que tomó un repartidor (ese lo cobra el repartidor y
/// lo entrega en caja en la rendición). Un delivery que el local entrega
/// sin repartidor de la app lo cobra el Cajero, para que no quede sin
/// registrar en ninguna caja.
bool loCobraLaCaja(PedidoModel p) => p.modalidad != PedidoModalidad.delivery || p.idRepartidor == null;

/// Siguiente estado del flujo normal del pedido (null si ya terminó).
String? siguienteEstadoFlujo(String actual) {
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

/// true si para entregar este pedido hay que registrar el cobro en la caja
/// del Cajero (pedido de la app que se cobra en el local).
bool requiereCobroEnCaja(PedidoModel p) =>
    siguienteEstadoFlujo(p.estado) == PedidoEstado.entregado &&
    p.origen == PedidoOrigen.cliente &&
    loCobraLaCaja(p) &&
    !p.cobrado;

/// Un pedido que se cobra en caja solo lo puede entregar el Cajero: si lo
/// marcara "Entregado" otro rol, quedaría entregado SIN cobro.
bool soloElCajeroLoEntrega(PedidoModel p) => requiereCobroEnCaja(p) && !SesionActual.instancia.esCajero;

/// Estado al que la persona en sesión puede pasar el pedido (null si
/// ninguno).
String? siguienteParaPersonal(PedidoModel p) => soloElCajeroLoEntrega(p) ? null : siguienteEstadoFlujo(p.estado);

/// Texto del botón principal para pasar [p] a [siguiente].
String textoAccion(PedidoModel p, String siguiente) {
  switch (siguiente) {
    case PedidoEstado.enPreparacion:
      return tr('Aceptar pedido');
    case PedidoEstado.listo:
      return tr('Marcar listo');
    case PedidoEstado.entregado:
      if (SesionActual.instancia.esCajero && requiereCobroEnCaja(p)) {
        return tr('Entregar y cobrar {monto}', {'monto': dinero(p.montoNegocio)});
      }
      return tr('Marcar entregado');
    default:
      return tr('Marcar como "{siguiente}"', {'siguiente': tr(siguiente)});
  }
}

/// Pasa el pedido a [siguiente]. Si es el Cajero quien lo entrega y hay
/// que cobrarlo, primero registra el cobro en su caja. Muestra el
/// resultado con un aviso y devuelve true si se hizo el cambio.
Future<bool> avanzarPedido(BuildContext context, PedidoModel pedido, String siguiente) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    // Antes de cobrar, confirma que el pedido sigue en el estado que ve la
    // pantalla (evita cobrar y luego fallar).
    await PedidoService.instancia.verificarCambio(pedido.id, siguiente);
    // HU-46: el Cajero que entrega un pedido de un cliente lo cobra en SU
    // caja. Delivery lo cobra el repartidor, y los pedidos de mesa se
    // cobran al cerrar la mesa.
    final cajero = SesionActual.instancia.esCajero ? SesionActual.instancia.actual : null;
    if (cajero != null && siguiente == PedidoEstado.entregado && requiereCobroEnCaja(pedido)) {
      final CajaModel? caja = await CajaService.instancia.cajaAbiertaActual(cajero.idUsuario);
      if (caja == null || caja.contada) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              caja == null
                  ? tr('Abre tu caja (Caja, en el inicio) antes de entregar este pedido.')
                  : tr('Tu caja está en cierre: ya no puedes registrar cobros.'),
            ),
          ),
        );
        return false;
      }
      await CajaService.instancia.cobrarPedido(
        caja: caja,
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
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Estado actualizado a "{siguiente}".', {'siguiente': tr(siguiente)}))),
    );
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
    return false;
  }
}

/// HU-39: elegir a qué repartidor se le asigna un pedido de delivery.
Future<void> elegirRepartidor(BuildContext context, PedidoModel pedido) async {
  final idNegocio = SesionActual.instancia.idNegocio;
  final yo = SesionActual.instancia.actual;
  if (idNegocio == null || yo == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final elegido = await showModalBottomSheet<UsuarioModel>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: StreamBuilder<List<UsuarioModel>>(
        stream: PedidoService.instancia.streamRepartidores(idNegocio),
        builder: (ctx, s) {
          if (s.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(tr('No se pudo cargar la lista de repartidores.')),
            );
          }
          if (!s.hasData) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final lista = s.data!;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
            children: [
              Text(tr('Asignar repartidor'), style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (lista.isEmpty)
                Text(tr('Este negocio todavía no tiene repartidores activos.'))
              else
                for (final r in lista)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.two_wheeler_outlined),
                      title: Text(r.nombre),
                      subtitle: r.telefono.isEmpty ? null : Text(r.telefono),
                      trailing: r.idUsuario == pedido.idRepartidor
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => Navigator.pop(ctx, r),
                    ),
                  ),
            ],
          );
        },
      ),
    ),
  );
  if (elegido == null || elegido.idUsuario == pedido.idRepartidor) return;
  try {
    await PedidoService.instancia.asignarRepartidor(
      idPedido: pedido.id,
      idRepartidor: elegido.idUsuario,
      nombreRepartidor: elegido.nombre,
      telefonoRepartidor: elegido.telefono,
      idUsuario: yo.idUsuario,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(tr('Pedido asignado a {nombre}.', {'nombre': elegido.nombre})),
    ));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
  }
}
