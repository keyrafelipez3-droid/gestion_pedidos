import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/sucursal_model.dart';

class SucursalService {
  SucursalService._();
  static final instancia = SucursalService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _ref => _db.collection('sucursales');

  Stream<List<SucursalModel>> streamSucursales() => _ref.snapshots().map(
        (qs) => qs.docs.map(SucursalModel.fromSnapshot).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
      );

  Future<void> guardar(SucursalModel sucursal) async {
    final doc = sucursal.id.isEmpty ? _ref.doc() : _ref.doc(sucursal.id);
    await doc.set(sucursal.toMap(), SetOptions(merge: true));
  }

  Future<void> cambiarEstado(String id, bool estado) =>
      _ref.doc(id).update({'estado': estado});

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
