import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/negocio_model.dart';
import '../models/usuario_model.dart';

/// Solicitud de un restaurante para unirse a la plataforma. El id del
/// documento es el uid de quien la envía (una por persona).
class SolicitudNegocio {
  static const pendiente = 'Pendiente';
  static const aprobada = 'Aprobada';
  static const rechazada = 'Rechazada';

  final String idUsuario;
  final String nombreNegocio;
  final String ciudad;
  final String telefono;
  final String nit;
  final String mensaje;
  final String nombreSolicitante;
  final String correo;
  final String estado;
  final String motivo;
  final String? idNegocio;
  final DateTime? fecha;

  const SolicitudNegocio({
    required this.idUsuario,
    required this.nombreNegocio,
    required this.ciudad,
    required this.telefono,
    this.nit = '',
    this.mensaje = '',
    this.nombreSolicitante = '',
    this.correo = '',
    this.estado = pendiente,
    this.motivo = '',
    this.idNegocio,
    this.fecha,
  });

  factory SolicitudNegocio.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    return SolicitudNegocio(
      idUsuario: d.id,
      nombreNegocio: m['nombreNegocio'] as String? ?? '',
      ciudad: m['ciudad'] as String? ?? '',
      telefono: m['telefono'] as String? ?? '',
      nit: m['nit'] as String? ?? '',
      mensaje: m['mensaje'] as String? ?? '',
      nombreSolicitante: m['nombreSolicitante'] as String? ?? '',
      correo: m['correo'] as String? ?? '',
      estado: m['estado'] as String? ?? pendiente,
      motivo: m['motivo'] as String? ?? '',
      idNegocio: m['idNegocio'] as String?,
      fecha: (m['fecha'] as Timestamp?)?.toDate(),
    );
  }

  /// Lo que escribe quien la envía (las reglas solo aceptan estos campos).
  Map<String, dynamic> toMapNueva() => {
        'nombreNegocio': nombreNegocio,
        'ciudad': ciudad,
        'telefono': telefono,
        'nit': nit,
        'mensaje': mensaje,
        'nombreSolicitante': nombreSolicitante,
        'correo': correo,
        'estado': pendiente,
        'fecha': FieldValue.serverTimestamp(),
      };
}

class SolicitudesService {
  SolicitudesService._();
  static final instancia = SolicitudesService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('solicitudesNegocio');

  Stream<SolicitudNegocio?> streamMia(String uid) =>
      _col.doc(uid).snapshots().map((d) => d.exists ? SolicitudNegocio.fromSnapshot(d) : null);

  Future<void> enviar(SolicitudNegocio s) => _col.doc(s.idUsuario).set(s.toMapNueva());

  /// Quien la envió la retira (o la borra para enviar otra si la rechazaron).
  Future<void> retirar(String uid) => _col.doc(uid).delete();

  /// SuperAdmin: solicitudes pendientes, la más antigua primero.
  Stream<List<SolicitudNegocio>> streamPendientes() => _col
      .where('estado', isEqualTo: SolicitudNegocio.pendiente)
      .snapshots()
      .map((qs) => qs.docs.map(SolicitudNegocio.fromSnapshot).toList()
        ..sort((a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0))));

  /// SuperAdmin aprueba: crea el negocio, convierte a quien lo pidió en su
  /// Administrador y marca la solicitud como aprobada, todo junto.
  Future<String> aprobar(SolicitudNegocio s, {required String idSuperAdmin}) async {
    final negocio = _db.collection('negocios').doc();
    final batch = _db.batch();
    batch.set(
      negocio,
      NegocioModel(
        idNegocio: negocio.id,
        nombre: s.nombreNegocio,
        telefono: s.telefono,
        ciudad: s.ciudad,
        nit: s.nit,
        correoContacto: s.correo,
      ).toMap(),
    );
    batch.update(_db.collection('usuarios').doc(s.idUsuario), {
      'rol': Rol.administrador,
      'idNegocio': negocio.id,
    });
    batch.update(_col.doc(s.idUsuario), {
      'estado': SolicitudNegocio.aprobada,
      'idNegocio': negocio.id,
      'revisadaPor': idSuperAdmin,
      'revisadaEn': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return negocio.id;
  }

  Future<void> rechazar(SolicitudNegocio s, {required String motivo, required String idSuperAdmin}) =>
      _col.doc(s.idUsuario).update({
        'estado': SolicitudNegocio.rechazada,
        'motivo': motivo,
        'revisadaPor': idSuperAdmin,
        'revisadaEn': FieldValue.serverTimestamp(),
      });
}
