import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/permisos_negocio.dart';

class PermisosService {
  PermisosService._();
  static final instancia = PermisosService._();

  DocumentReference<Map<String, dynamic>> _negocio(String id) =>
      FirebaseFirestore.instance.collection('negocios').doc(id);

  Future<PermisosNegocio> leer(String idNegocio) async {
    final d = await _negocio(idNegocio).get();
    return PermisosNegocio.desde(d.data()?['permisos']);
  }

  Stream<PermisosNegocio> stream(String idNegocio) =>
      _negocio(idNegocio).snapshots().map((d) => PermisosNegocio.desde(d.data()?['permisos']));

  Future<void> guardar(String idNegocio, PermisosNegocio permisos) =>
      _negocio(idNegocio).update({'permisos': permisos.toMap()});
}
