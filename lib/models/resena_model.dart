import 'package:cloud_firestore/cloud_firestore.dart';

class ResenaEstado {
  static const String visible = 'Visible';
  static const String oculta = 'Oculta';
}

/// Reseña de un pedido: `negocios/{idNegocio}/resenas/{idPedido}`.
///
/// El id es el del pedido, así que cada pedido tiene como máximo UNA reseña.
/// Solo puede escribirla el cliente de un pedido ya Entregado. El
/// Administrador del negocio puede ocultarla (no se borra) y bloquear a la
/// cuenta si el comentario es ofensivo.
class ResenaModel {
  final String id; // = idPedido
  final String idNegocio;
  final String idCliente;
  final String nombreCliente; // nombre corto, ej. "Ana P."
  final int calificacion; // 1 a 5
  final String comentario;
  final DateTime? fecha;
  final String estado;
  final String? motivoModeracion;

  const ResenaModel({
    required this.id,
    required this.idNegocio,
    required this.idCliente,
    required this.nombreCliente,
    required this.calificacion,
    this.comentario = '',
    this.fecha,
    this.estado = ResenaEstado.visible,
    this.motivoModeracion,
  });

  bool get oculta => estado == ResenaEstado.oculta;

  factory ResenaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ResenaModel(
      id: doc.id,
      idNegocio: data['idNegocio'] as String? ?? '',
      idCliente: data['idCliente'] as String? ?? '',
      nombreCliente: data['nombreCliente'] as String? ?? '',
      calificacion: (data['calificacion'] as num?)?.toInt() ?? 0,
      comentario: data['comentario'] as String? ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      estado: data['estado'] as String? ?? ResenaEstado.visible,
      motivoModeracion: data['motivoModeracion'] as String?,
    );
  }
}
