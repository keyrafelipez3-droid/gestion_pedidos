import 'package:cloud_firestore/cloud_firestore.dart';

import 'carrito_models.dart' show OpcionSeleccionada;

class PedidoModalidad {
  static const String mesa = 'Mesa';
  static const String recoger = 'Recoger';
  static const String delivery = 'Delivery';
  static const List<String> todas = [mesa, recoger, delivery];
}

class MetodoPago {
  static const String efectivo = 'Efectivo';
  static const String transferencia = 'Transferencia';
  static const String qr = 'QR';
  static const List<String> todos = [efectivo, transferencia, qr];
}

/// Flujo de estados de un pedido (HU-28 a HU-31). La app controla el
/// orden en que se puede avanzar (ver PedidoService.cambiarEstado); las
/// reglas de Firestore solo controlan QUIÉN puede escribir en el pedido,
/// no en qué orden cambian los estados.
class PedidoEstado {
  static const String pendiente = 'Pendiente';
  static const String enPreparacion = 'En preparación';
  static const String listo = 'Listo';
  static const String entregado = 'Entregado';
  static const String cancelado = 'Cancelado';
  static const List<String> todos = [
    pendiente,
    enPreparacion,
    listo,
    entregado,
    cancelado,
  ];
}

/// Documento de `pedidos/{pedidoId}` (raíz). Se crea a partir del
/// carrito del cliente al confirmar (HU-26); `total` y los items quedan
/// "congelados" desde ese momento, aunque el Administrador luego cambie
/// precios del catálogo.
class PedidoModel {
  final String id;
  final String idCliente;
  final String idNegocio;
  final String idSucursal;
  final String modalidad;
  final String? idMesa;
  final Map<String, dynamic>? direccionEntrega; // snapshot, solo si modalidad == delivery
  final String metodoPago;
  final String? comprobantePagoUrl; // HU-27, solo si corresponde (ej. transferencia/QR)
  final String estado;
  final double total;
  final String notas;
  final DateTime? fechaCreacion;

  const PedidoModel({
    required this.id,
    required this.idCliente,
    required this.idNegocio,
    required this.idSucursal,
    required this.modalidad,
    this.idMesa,
    this.direccionEntrega,
    required this.metodoPago,
    this.comprobantePagoUrl,
    this.estado = PedidoEstado.pendiente,
    this.total = 0,
    this.notas = '',
    this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
        'idCliente': idCliente,
        'idNegocio': idNegocio,
        'idSucursal': idSucursal,
        'modalidad': modalidad,
        'idMesa': idMesa,
        'direccionEntrega': direccionEntrega,
        'metodoPago': metodoPago,
        'comprobantePagoUrl': comprobantePagoUrl,
        'estado': estado,
        'total': total,
        'notas': notas,
        'fechaCreacion': FieldValue.serverTimestamp(),
      };

  factory PedidoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawTotal = data['total'];
    final ts = data['fechaCreacion'] as Timestamp?;
    final rawDireccion = data['direccionEntrega'];
    return PedidoModel(
      id: doc.id,
      idCliente: data['idCliente'] as String? ?? '',
      idNegocio: data['idNegocio'] as String? ?? '',
      idSucursal: data['idSucursal'] as String? ?? '',
      modalidad: data['modalidad'] as String? ?? PedidoModalidad.recoger,
      idMesa: data['idMesa'] as String?,
      direccionEntrega:
          rawDireccion is Map ? Map<String, dynamic>.from(rawDireccion) : null,
      metodoPago: data['metodoPago'] as String? ?? MetodoPago.efectivo,
      comprobantePagoUrl: data['comprobantePagoUrl'] as String?,
      estado: data['estado'] as String? ?? PedidoEstado.pendiente,
      total: rawTotal is num ? rawTotal.toDouble() : 0,
      notas: data['notas'] as String? ?? '',
      fechaCreacion: ts?.toDate(),
    );
  }
}

/// Documento de `pedidos/{pedidoId}/detalle/{detalleId}` — una línea del
/// pedido, copiada del carrito al confirmar (HU-28: consultar detalle).
class DetallePedidoModel {
  final String id;
  final String idProducto;
  final String nombreProducto;
  final double precioUnitario;
  final int cantidad;
  final List<OpcionSeleccionada> variantes;
  final List<OpcionSeleccionada> complementos;
  final String notas;
  final double subtotal;

  const DetallePedidoModel({
    required this.id,
    required this.idProducto,
    required this.nombreProducto,
    required this.precioUnitario,
    required this.cantidad,
    this.variantes = const [],
    this.complementos = const [],
    this.notas = '',
    required this.subtotal,
  });

  Map<String, dynamic> toMap() => {
        'idProducto': idProducto,
        'nombreProducto': nombreProducto,
        'precioUnitario': precioUnitario,
        'cantidad': cantidad,
        'variantes': variantes.map((v) => v.toMap()).toList(),
        'complementos': complementos.map((c) => c.toMap()).toList(),
        'notas': notas,
        'subtotal': subtotal,
      };

  factory DetallePedidoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrecio = data['precioUnitario'];
    final rawSubtotal = data['subtotal'];
    return DetallePedidoModel(
      id: doc.id,
      idProducto: data['idProducto'] as String? ?? '',
      nombreProducto: data['nombreProducto'] as String? ?? '',
      precioUnitario: rawPrecio is num ? rawPrecio.toDouble() : 0,
      cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
      variantes: ((data['variantes'] as List?) ?? [])
          .map((v) => OpcionSeleccionada.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList(),
      complementos: ((data['complementos'] as List?) ?? [])
          .map((c) => OpcionSeleccionada.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      notas: data['notas'] as String? ?? '',
      subtotal: rawSubtotal is num ? rawSubtotal.toDouble() : 0,
    );
  }
}

/// Documento de `pedidos/{pedidoId}/historialEstados/{historialId}`
/// (HU-29/HU-30/HU-31): un renglón por cada cambio de estado del pedido.
class HistorialEstadoModel {
  final String id;
  final String estado;
  final String idUsuarioQueCambio;
  final String comentario;
  final DateTime? fecha;

  const HistorialEstadoModel({
    required this.id,
    required this.estado,
    required this.idUsuarioQueCambio,
    this.comentario = '',
    this.fecha,
  });

  Map<String, dynamic> toMap() => {
        'estado': estado,
        'idUsuarioQueCambio': idUsuarioQueCambio,
        'comentario': comentario,
        'fecha': FieldValue.serverTimestamp(),
      };

  factory HistorialEstadoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['fecha'] as Timestamp?;
    return HistorialEstadoModel(
      id: doc.id,
      estado: data['estado'] as String? ?? '',
      idUsuarioQueCambio: data['idUsuarioQueCambio'] as String? ?? '',
      comentario: data['comentario'] as String? ?? '',
      fecha: ts?.toDate(),
    );
  }
}
