import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/actividad_model.dart';
import 'auth_service.dart';
import 'sesion_actual.dart';

/// Registro de actividad del negocio (quién hizo qué y cuándo). Lo escribe
/// la propia persona que hace la acción (con su uid y la hora del
/// servidor); solo el Administrador del negocio y el SuperAdmin lo leen, y
/// nadie lo puede editar ni borrar (ver firestore.rules).
class ActividadService {
  ActividadService._();
  static final instancia = ActividadService._();

  final _db = FirebaseFirestore.instance;
  final _sesionesRegistradas = <String>{};

  CollectionReference<Map<String, dynamic>> _col(String idNegocio) =>
      _db.collection('negocios').doc(idNegocio).collection('actividad');

  /// Registra una acción. Nunca lanza error: si no se puede guardar, la
  /// acción principal ya se hizo y no debe fallar por esto.
  Future<void> registrar(String tipo, String descripcion, {String? idNegocio}) async {
    final u = SesionActual.instancia.actual;
    if (u == null) return;
    final negocio = idNegocio ?? u.idNegocio;
    if (negocio == null || negocio.isEmpty) return;
    try {
      await _col(negocio).add({
        'tipo': tipo,
        'descripcion': descripcion.length > 300 ? descripcion.substring(0, 300) : descripcion,
        'idUsuario': u.idUsuario,
        'nombreUsuario': u.nombre,
        'rol': u.rol,
        'fecha': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Inicio de sesión del personal (una vez por sesión).
  Future<void> registrarInicioSesion() async {
    final u = SesionActual.instancia.actual;
    if (u == null || u.esCliente || _sesionesRegistradas.contains(u.idUsuario)) return;
    _sesionesRegistradas.add(u.idUsuario);
    await registrar(ActividadTipo.sesion, 'Inició sesión');
  }

  void olvidarSesion(String idUsuario) => _sesionesRegistradas.remove(idUsuario);

  /// Cierre de sesión normal (botón "Cerrar sesión"): queda registrado si
  /// es personal del negocio.
  Future<void> cerrarSesion() async {
    final u = SesionActual.instancia.actual;
    if (u != null && !u.esCliente) {
      await registrar(ActividadTipo.sesion, 'Cerró sesión');
      olvidarSesion(u.idUsuario);
    }
    SesionActual.instancia.limpiar();
    await AuthService.instancia.cerrarSesion();
  }

  Stream<List<ActividadModel>> stream(String idNegocio, {int limite = 300}) => _col(idNegocio)
      .orderBy('fecha', descending: true)
      .limit(limite)
      .snapshots()
      .map((qs) => qs.docs.map(ActividadModel.fromSnapshot).toList());
}
