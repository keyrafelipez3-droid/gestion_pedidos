import 'package:cloud_firestore/cloud_firestore.dart';

/// Un cliente visto desde un negocio: `negocios/{idNegocio}/clientes/{uid}`.
///
/// Se crea cuando el cliente hace su primer pedido en ese negocio y guarda
/// solo lo necesario para atenderlo (nombre y teléfono); el correo y las
/// direcciones NO se copian. El Administrador del negocio puede bloquearlo
/// (por ejemplo, por mal comportamiento); el bloqueo vale solo en ese
/// negocio, no en el resto de la plataforma.
class ClienteNegocioModel {
  final String idUsuario;
  final String nombre;
  final String telefono;
  final bool bloqueado;
  final String? motivoBloqueo;
  final DateTime? fechaPrimerPedido;
  final DateTime? ultimoPedido;

  const ClienteNegocioModel({
    required this.idUsuario,
    required this.nombre,
    required this.telefono,
    this.bloqueado = false,
    this.motivoBloqueo,
    this.fechaPrimerPedido,
    this.ultimoPedido,
  });

  factory ClienteNegocioModel.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ClienteNegocioModel(
      idUsuario: doc.id,
      nombre: data['nombre'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      bloqueado: data['bloqueado'] as bool? ?? false,
      motivoBloqueo: data['motivoBloqueo'] as String?,
      fechaPrimerPedido: (data['fechaPrimerPedido'] as Timestamp?)?.toDate(),
      ultimoPedido: (data['ultimoPedido'] as Timestamp?)?.toDate(),
    );
  }
}
