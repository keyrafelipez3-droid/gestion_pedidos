import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mesa_model.dart';

/// HU-32: el Cajero (y Administrador/SuperAdmin) gestiona mesas y
/// pedidos desde mesa.
class MesaService {
  MesaService._();
  static final instancia = MesaService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _mesas(String idSucursal) =>
      _db.collection('sucursales').doc(idSucursal).collection('mesas');

  Stream<List<MesaModel>> streamMesas(String idSucursal) =>
      _mesas(idSucursal).snapshots().map((qs) {
        final lista = qs.docs.map(MesaModel.fromSnapshot).toList();
        lista.sort((a, b) => a.numero.compareTo(b.numero));
        return lista;
      });

  String nuevaId(String idSucursal) => _mesas(idSucursal).doc().id;

  Future<void> guardarMesa(String idSucursal, MesaModel mesa) async {
    final doc = mesa.id.isEmpty ? _mesas(idSucursal).doc() : _mesas(idSucursal).doc(mesa.id);
    await doc.set(mesa.toMap(), SetOptions(merge: true));
  }

  Future<void> cambiarEstado(String idSucursal, String idMesa, String nuevoEstado) =>
      _mesas(idSucursal).doc(idMesa).update({'estado': nuevoEstado});

  Future<void> eliminarMesa(String idSucursal, String idMesa) =>
      _mesas(idSucursal).doc(idMesa).delete();
}
