import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/carrito_models.dart';
import '../models/pedido_models.dart';

/// HU-24 a HU-31: confirmar pedido (a partir del carrito), consultarlo,
/// y que el personal del negocio (Cajero/Cocina/Administrador) lo
/// gestione y cambie de estado.
class PedidoService {
  PedidoService._();
  static final instancia = PedidoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pedidos => _db.collection('pedidos');

  /// HU-24/HU-26: confirma el pedido a partir de los items ya cargados
  /// del carrito (se los pasa la pantalla, que ya los tiene vía
  /// CarritoService.streamCarrito). Crea el pedido + su detalle + el
  /// primer renglón de historialEstados, y al final vacía el carrito de
  /// ese negocio. Devuelve el id del pedido creado.
  Future<String> confirmarPedido({
    required String idCliente,
    required String idNegocio,
    required String idSucursal,
    required String modalidad,
    String? idMesa,
    Map<String, dynamic>? direccionEntrega,
    required String metodoPago,
    String? comprobantePagoUrl,
    required List<CarritoItemModel> itemsCarrito,
    String notas = '',
  }) async {
    if (itemsCarrito.isEmpty) {
      throw Exception('El carrito está vacío, no se puede confirmar el pedido.');
    }

    final total = itemsCarrito.fold<double>(0, (acc, item) => acc + item.subtotal);
    final pedidoDoc = _pedidos.doc();

    final pedido = PedidoModel(
      id: pedidoDoc.id,
      idCliente: idCliente,
      idNegocio: idNegocio,
      idSucursal: idSucursal,
      modalidad: modalidad,
      idMesa: idMesa,
      direccionEntrega: direccionEntrega,
      metodoPago: metodoPago,
      comprobantePagoUrl: comprobantePagoUrl,
      estado: PedidoEstado.pendiente,
      total: total,
      notas: notas,
    );

    // OJO (bug encontrado probando): el pedido se crea en un PRIMER
    // commit, solo, y recién en un SEGUNDO commit se agregan detalle +
    // historialEstados. No se puede hacer todo en un solo batch: las
    // reglas de detalle/historialEstados necesitan leer (get()) el
    // documento del pedido para confirmar que es tuyo, y esa lectura NO
    // ve los demás escrituras del mismo batch todavía sin confirmar
    // (Firestore evalúa las reglas de un batch contra el estado ANTES
    // del batch) — por eso fallaba con "permission-denied" aunque la
    // regla de creación del pedido en sí era correcta.
    await pedidoDoc.set(pedido.toMap());

    final batch = _db.batch();

    for (final item in itemsCarrito) {
      final detalle = DetallePedidoModel(
        id: '',
        idProducto: item.idProducto,
        nombreProducto: item.nombreProducto,
        precioUnitario: item.precioUnitario,
        cantidad: item.cantidad,
        variantes: item.variantes,
        complementos: item.complementos,
        notas: item.notas,
        subtotal: item.subtotal,
      );
      batch.set(pedidoDoc.collection('detalle').doc(), detalle.toMap());
    }

    final historial = HistorialEstadoModel(
      id: '',
      estado: PedidoEstado.pendiente,
      idUsuarioQueCambio: idCliente,
      comentario: 'Pedido creado por el cliente.',
    );
    batch.set(pedidoDoc.collection('historialEstados').doc(), historial.toMap());

    await batch.commit();

    // El carrito ya se copió al pedido, así que se vacía para que no
    // quede duplicado si el cliente abre el carrito de nuevo.
    await _items(idCliente).where('idNegocio', isEqualTo: idNegocio).get().then((qs) async {
      final limpiarBatch = _db.batch();
      for (final doc in qs.docs) {
        limpiarBatch.delete(doc.reference);
      }
      await limpiarBatch.commit();
    });

    return pedidoDoc.id;
  }

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('usuarios').doc(uid).collection('carritoItems');

  /// HU-28: el cliente consulta sus propios pedidos.
  Stream<List<PedidoModel>> streamPedidosCliente(String idCliente) =>
      _pedidos.where('idCliente', isEqualTo: idCliente).snapshots().map((qs) {
        final lista = qs.docs.map(PedidoModel.fromSnapshot).toList();
        lista.sort((a, b) =>
            (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
        return lista;
      });

  /// HU-29: el Cajero registra y consulta los pedidos recibidos de su
  /// negocio. `filtroEstado` es opcional (ej. para una pestaña "activos").
  Stream<List<PedidoModel>> streamPedidosNegocio(String idNegocio, {String? filtroEstado}) {
    Query<Map<String, dynamic>> query = _pedidos.where('idNegocio', isEqualTo: idNegocio);
    if (filtroEstado != null) {
      query = query.where('estado', isEqualTo: filtroEstado);
    }
    return query.snapshots().map((qs) {
      final lista = qs.docs.map(PedidoModel.fromSnapshot).toList();
      lista.sort((a, b) =>
          (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
      return lista;
    });
  }

  /// HU-30: Cocina consulta solo los pedidos pendientes/en preparación
  /// (no necesita ver los ya entregados o cancelados).
  Stream<List<PedidoModel>> streamPedidosCocina(String idNegocio) =>
      streamPedidosNegocio(idNegocio).map((lista) => lista
          .where((p) =>
              p.estado == PedidoEstado.pendiente || p.estado == PedidoEstado.enPreparacion)
          .toList());

  Stream<List<DetallePedidoModel>> streamDetalle(String idPedido) => _pedidos
      .doc(idPedido)
      .collection('detalle')
      .snapshots()
      .map((qs) => qs.docs.map(DetallePedidoModel.fromSnapshot).toList());

  Stream<List<HistorialEstadoModel>> streamHistorial(String idPedido) => _pedidos
      .doc(idPedido)
      .collection('historialEstados')
      .snapshots()
      .map((qs) {
        final lista = qs.docs.map(HistorialEstadoModel.fromSnapshot).toList();
        lista.sort((a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0)));
        return lista;
      });

  /// HU-31 (Cocina actualiza preparación) y HU-29 (Cajero gestiona el
  /// pedido): cambia el estado del pedido y deja registro en el
  /// historial de quién lo cambió.
  Future<void> cambiarEstado({
    required String idPedido,
    required String nuevoEstado,
    required String idUsuarioQueCambio,
    String comentario = '',
  }) async {
    final batch = _db.batch();
    batch.update(_pedidos.doc(idPedido), {'estado': nuevoEstado});
    final historial = HistorialEstadoModel(
      id: '',
      estado: nuevoEstado,
      idUsuarioQueCambio: idUsuarioQueCambio,
      comentario: comentario,
    );
    batch.set(_pedidos.doc(idPedido).collection('historialEstados').doc(), historial.toMap());
    await batch.commit();
  }
}
