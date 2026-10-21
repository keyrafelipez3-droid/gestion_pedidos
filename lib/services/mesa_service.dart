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
      _mesas(idSucursal).doc(idMesa).update({
        'estado': nuevoEstado,
        // Si deja de estar ocupada, ya no hay personas sentadas.
        if (nuevoEstado != MesaEstado.ocupada) 'personas': FieldValue.delete(),
      });

  /// El Cajero recibe a los clientes en la puerta y les asigna esta mesa:
  /// queda Ocupada, con el número de personas si lo sabe.
  Future<void> asignarMesa(String idSucursal, String idMesa, {int? personas}) =>
      _mesas(idSucursal).doc(idMesa).update({
        'estado': MesaEstado.ocupada,
        'personas': personas,
      });

  /// La mesa vuelve a quedar Libre (al cerrar la cuenta).
  Future<void> liberarMesa(String idSucursal, String idMesa) =>
      _mesas(idSucursal).doc(idMesa).update({
        'estado': MesaEstado.libre,
        'personas': FieldValue.delete(),
      });

  Future<void> eliminarMesa(String idSucursal, String idMesa) =>
      _mesas(idSucursal).doc(idMesa).delete();
}
