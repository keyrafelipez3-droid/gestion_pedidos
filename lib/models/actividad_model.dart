import 'package:cloud_firestore/cloud_firestore.dart';

/// Un renglón del registro de actividad del negocio:
/// `negocios/{id}/actividad/{id}`. Solo se agregan, nunca se editan.
class ActividadTipo {
  static const sesion = 'sesion';
  static const empleado = 'empleado';
  static const caja = 'caja';
  static const pedido = 'pedido';
  static const catalogo = 'catalogo';
  static const seguridad = 'seguridad';

  static const nombres = {
    sesion: 'Sesiones',
    empleado: 'Empleados',
    caja: 'Caja',
    pedido: 'Pedidos',
    catalogo: 'Catálogo y cupones',
    seguridad: 'Seguridad',
  };
}

class ActividadModel {
  final String id;
  final String tipo;
  final String descripcion;
  final String idUsuario;
  final String nombreUsuario;
  final String rol;
  final DateTime? fecha;

  const ActividadModel({
    required this.id,
    required this.tipo,
    required this.descripcion,
    required this.idUsuario,
    required this.nombreUsuario,
    required this.rol,
    this.fecha,
  });

  factory ActividadModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ActividadModel(
      id: doc.id,
      tipo: d['tipo'] as String? ?? '',
      descripcion: d['descripcion'] as String? ?? '',
      idUsuario: d['idUsuario'] as String? ?? '',
      nombreUsuario: d['nombreUsuario'] as String? ?? '',
      rol: d['rol'] as String? ?? '',
      fecha: (d['fecha'] as Timestamp?)?.toDate(),
    );
  }
}
