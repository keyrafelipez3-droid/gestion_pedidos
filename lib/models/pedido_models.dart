import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
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

  /// Pedido de mesa tomado por el Cajero: todavía no se cobra. El método
  /// real se elige al cerrar la cuenta de la mesa. No está en `todos`
  /// a propósito, para que no aparezca como opción al elegir cómo pagar.
  static const String porDefinir = 'Por definir';
}

/// Quién creó el pedido: el propio cliente desde la app, o el Cajero
/// que lo registra para una mesa.
class PedidoOrigen {
  static const String cliente = 'cliente';
  static const String cajero = 'cajero';
}

/// Flujo de estados de un pedido (HU-28 a HU-31). La app controla el
/// orden en que se puede avanzar (ver PedidoService.cambiarEstado); las
/// reglas de Firestore solo controlan QUIÉN puede escribir en el pedido,
/// no en qué orden cambian los estados.
class PedidoEstado {
  static const String pendiente = 'Pendiente';
  static const String enPreparacion = 'En preparación';
  static const String listo = 'Listo';

  /// Solo Delivery: un repartidor tomó el pedido y va hacia el cliente.
  static const String enCamino = 'En camino';

  /// Solo Delivery: el repartidor avisó que ya llegó al lugar de entrega.
  /// (Texto sin tilde a propósito: se usa tal cual en las reglas de Firestore.)
  static const String llego = 'En el lugar';
  static const String entregado = 'Entregado';
  static const String cancelado = 'Cancelado';
  static const List<String> todos = [
    pendiente,
    enPreparacion,
    listo,
    enCamino,
    llego,
    entregado,
    cancelado,
  ];

  /// Cambios de estado permitidos. El servicio los valida contra el estado
  /// REAL del pedido en Firestore (no el que ve la pantalla), para que dos
  /// personas no puedan pisarse ni repetir un cambio.
  static const Map<String, List<String>> _transiciones = {
    pendiente: [enPreparacion, cancelado],
    enPreparacion: [listo, cancelado],
    listo: [enCamino, entregado, cancelado],
    // Delivery: si el cliente no aparece o no se puede entregar, el Cajero
    // o el Administrador también pueden cancelarlo (con motivo).
    enCamino: [llego, entregado, cancelado],
    llego: [entregado, cancelado],
  };

  static bool puedePasar(String actual, String nuevo) =>
      (_transiciones[actual] ?? const <String>[]).contains(nuevo);
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

  /// `cliente` (por defecto, pedidos de la app) o `cajero` (pedido de mesa
  /// registrado por el personal; en ese caso `idCliente` queda vacío).
  final String origen;
  final String? creadoPor; // uid del Cajero, solo si origen == cajero
  final String? numeroMesa; // copia del número para mostrarlo sin otra consulta

  /// Pedido de mesa del Cajero que todavía forma parte de la cuenta abierta
  /// de la mesa; pasa a `false` al cerrar la mesa.
  final bool cuentaAbierta;

  /// HU-46: el pedido ya se cobró y quedó registrado en una caja. Evita
  /// que el mismo pedido se cobre dos veces.
  final bool cobrado;
  final String? idCaja; // caja donde se registró el cobro

  /// Solo Delivery: datos del cliente para que el repartidor pueda
  /// contactarlo durante la entrega. Se borran si el cliente elimina su cuenta.
  final String? nombreCliente;
  final String? telefonoCliente;

  /// Solo Delivery: repartidor que tomó el pedido (lo escribe el propio
  /// repartidor al tomarlo). El cliente ve su nombre y teléfono mientras
  /// el pedido está en camino.
  final String? idRepartidor;
  final String? nombreRepartidor;
  final String? telefonoRepartidor;

  /// Posición en vivo del repartidor. Solo existe mientras el pedido está
  /// en camino; se borra al entregarlo.
  final double? latRepartidor;
  final double? lngRepartidor;
  final DateTime? ubicacionActualizada;

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
    this.origen = PedidoOrigen.cliente,
    this.creadoPor,
    this.numeroMesa,
    this.cuentaAbierta = false,
    this.cobrado = false,
    this.idCaja,
    this.nombreCliente,
    this.telefonoCliente,
    this.idRepartidor,
    this.nombreRepartidor,
    this.telefonoRepartidor,
    this.latRepartidor,
    this.lngRepartidor,
    this.ubicacionActualizada,
  });

  bool get esDelivery => modalidad == PedidoModalidad.delivery;

  /// El pedido está en la etapa de reparto (ya lo tomó un repartidor).
  bool get enReparto =>
      estado == PedidoEstado.enCamino || estado == PedidoEstado.llego;

  /// "Mesa 3" si es un pedido de mesa con número conocido; si no, la
  /// modalidad tal cual (Recoger, Delivery o Mesa).
  String get etiquetaModalidad {
    final n = numeroMesa;
    if (modalidad == PedidoModalidad.mesa && n != null && n.isNotEmpty) {
      return tr('Mesa {numero}', {'numero': n});
    }
    return tr(modalidad);
  }

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
        'origen': origen,
        'creadoPor': creadoPor,
        'numeroMesa': numeroMesa,
        'cuentaAbierta': cuentaAbierta,
        'cobrado': cobrado,
        'idCaja': idCaja,
        'nombreCliente': nombreCliente,
        'telefonoCliente': telefonoCliente,
        // idRepartidor / nombreRepartidor / telefonoRepartidor NO van acá a
        // propósito: los escribe el repartidor al tomar el pedido, no el
        // cliente al crearlo (las reglas de Firestore no los aceptan al crear).
      };

  factory PedidoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawTotal = data['total'];
    final ts = data['fechaCreacion'] as Timestamp?;
    final rawDireccion = data['direccionEntrega'];
    final ubicacion = data['ubicacionRepartidor'];
    final tsUbicacion = data['ubicacionActualizada'];
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
      origen: data['origen'] as String? ?? PedidoOrigen.cliente,
      creadoPor: data['creadoPor'] as String?,
      numeroMesa: data['numeroMesa'] as String?,
      cuentaAbierta: data['cuentaAbierta'] as bool? ?? false,
      cobrado: data['cobrado'] as bool? ?? false,
      idCaja: data['idCaja'] as String?,
      nombreCliente: data['nombreCliente'] as String?,
      telefonoCliente: data['telefonoCliente'] as String?,
      idRepartidor: data['idRepartidor'] as String?,
      nombreRepartidor: data['nombreRepartidor'] as String?,
      telefonoRepartidor: data['telefonoRepartidor'] as String?,
      latRepartidor: ubicacion is GeoPoint ? ubicacion.latitude : null,
      lngRepartidor: ubicacion is GeoPoint ? ubicacion.longitude : null,
      ubicacionActualizada: tsUbicacion is Timestamp ? tsUbicacion.toDate() : null,
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
