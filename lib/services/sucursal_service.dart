import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sucursal_model.dart';

class SucursalService {
  SucursalService._();
  static final instancia = SucursalService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('sucursales');

  /// Corrección pedida por el docente (multi-tenant): se filtra por el
  /// negocio del Administrador logueado con un `where` de igualdad — el
  /// orden sigue haciéndose en Dart para no requerir un índice compuesto
  /// nuevo en Firestore.
  Stream<List<SucursalModel>> streamSucursales(String idNegocio) => _ref
      .where('idNegocio', isEqualTo: idNegocio)
      .snapshots()
      .map(
        (qs) => qs.docs.map(SucursalModel.fromSnapshot).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
      );

  /// Genera un id de documento NUEVO sin crearlo todavía en Firestore —
  /// se usa para poder subir la foto a Storage (que necesita una ruta
  /// estable) ANTES de que la sucursal exista como documento.
  String nuevoId() => _ref.doc().id;

  Future<void> guardar(SucursalModel sucursal) async {
    final doc = sucursal.id.isEmpty ? _ref.doc() : _ref.doc(sucursal.id);
    await doc.set(sucursal.toMap(), SetOptions(merge: true));
  }

  /// Lee la sucursal una sola vez (null si ya no existe).
  Future<SucursalModel?> obtener(String id) async {
    final doc = await _ref.doc(id).get();
    return doc.exists ? SucursalModel.fromSnapshot(doc) : null;
  }

  /// Zonas y costos de envío. Se guardan aparte de los demás datos para
  /// que editar la sucursal no los borre.
  Future<void> guardarDelivery(String id, Map<String, double> zonas, double minimo) =>
      _ref.doc(id).update({'zonasDelivery': zonas, 'pedidoMinimoDelivery': minimo});

  Future<void> cambiarEstado(String id, bool estado) =>
      _ref.doc(id).update({'estado': estado});

  /// HU-47: pausa o reanuda la recepción de pedidos de una sucursal. Se
  /// guarda aparte para que editar la sucursal no la borre.
  Future<void> pausarPedidos(String id, {required bool pausar, String motivo = ''}) =>
      _ref.doc(id).update({
        'pedidosPausados': pausar,
        'motivoPausa': pausar ? motivo.trim() : '',
      });

  Future<void> eliminar(String id) => _ref.doc(id).delete();

  Future<Map<String, HorarioDia>> obtenerHorarios(String idSucursal) async {
    final snapshot = await _ref.doc(idSucursal).collection('horarios').get();
    final horarios = <String, HorarioDia>{};
    for (final doc in snapshot.docs) {
      horarios[doc.id] = HorarioDia.fromMap(doc.data());
    }
    return horarios;
  }

  Future<void> guardarHorarios(String idSucursal, Map<String, HorarioDia> horarios) async {
    final batch = _db.batch();
    for (final entry in horarios.entries) {
      final ref = _ref.doc(idSucursal).collection('horarios').doc(entry.key);
      batch.set(ref, entry.value.toMap(), SetOptions(merge: true));
    }
    batch.set(
      _ref.doc(idSucursal),
      {'horarios': {for (final e in horarios.entries) e.key: e.value.toMap()}},
      SetOptions(merge: true),
    );
    await batch.commit();
  }
}
