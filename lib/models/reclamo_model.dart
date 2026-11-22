import 'package:cloud_firestore/cloud_firestore.dart';

class ReclamoEstado {
  static const String abierto = 'Abierto';
  static const String enRevision = 'En revision';
  static const String resuelto = 'Resuelto';

  /// Cómo se muestra el estado (en la base se guarda sin tilde).
  static String etiqueta(String estado) => estado == enRevision ? 'En revisión' : estado;
}

/// Motivos que puede elegir el cliente. Se guardan sin tildes porque las
/// reglas de Firestore los comparan tal cual.
class ReclamoMotivo {
  static const List<String> todos = [
    'Pedido incompleto',
    'Producto en mal estado',
    'Demora en la entrega',
    'Cobro incorrecto',
    'Mala atencion',
    'Otro',
  ];

  static String etiqueta(String motivo) => motivo == 'Mala atencion' ? 'Mala atención' : motivo;
}

/// Reclamo de un cliente: `negocios/{idNegocio}/reclamos/{id}`.
///
/// Lo crea el cliente (puede ir ligado a uno de sus pedidos) y lo responde el
/// Administrador del negocio. No se borra: queda como libro de reclamos.
class ReclamoModel {
  final String id;
  final String idNegocio;
  final String idCliente;
  final String nombreCliente;
  final String idPedido; // '' si no es de un pedido
  final String motivo;
  final String descripcion;
  final String estado;
  final DateTime? fecha;
  final String respuesta;
  final DateTime? fechaRespuesta;

  const ReclamoModel({
    required this.id,
    required this.idNegocio,
    required this.idCliente,
    required this.nombreCliente,
    required this.idPedido,
    required this.motivo,
    required this.descripcion,
    required this.estado,
    this.fecha,
    this.respuesta = '',
    this.fechaRespuesta,
  });

  bool get resuelto => estado == ReclamoEstado.resuelto;

  factory ReclamoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ReclamoModel(
      id: doc.id,
      idNegocio: data['idNegocio'] as String? ?? '',
      idCliente: data['idCliente'] as String? ?? '',
      nombreCliente: data['nombreCliente'] as String? ?? '',
      idPedido: data['idPedido'] as String? ?? '',
      motivo: data['motivo'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      estado: data['estado'] as String? ?? ReclamoEstado.abierto,
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      respuesta: data['respuesta'] as String? ?? '',
      fechaRespuesta: (data['fechaRespuesta'] as Timestamp?)?.toDate(),
    );
  }
}
