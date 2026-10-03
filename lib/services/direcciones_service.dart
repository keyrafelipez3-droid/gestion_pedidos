import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/direccion_entrega_model.dart';

/// HU-25: registrar y seleccionar dirección de delivery.
class DireccionesService {
  DireccionesService._();
  static final instancia = DireccionesService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _direcciones(String uid) =>
      _db.collection('usuarios').doc(uid).collection('direcciones');

  Stream<List<DireccionEntregaModel>> streamDirecciones(String uid) =>
      _direcciones(uid).snapshots().map((qs) {
        final lista = qs.docs.map(DireccionEntregaModel.fromSnapshot).toList();
        // La predeterminada primero, para que la pantalla la preseleccione.
        lista.sort((a, b) {
          if (a.predeterminada == b.predeterminada) return 0;
          return a.predeterminada ? -1 : 1;
        });
        return lista;
      });

  Future<void> guardarDireccion(String uid, DireccionEntregaModel direccion) async {
    final doc = direccion.id.isEmpty
        ? _direcciones(uid).doc()
        : _direcciones(uid).doc(direccion.id);

    // Si esta se marca como predeterminada, se desmarca cualquier otra
    // (una sola predeterminada a la vez).
    if (direccion.predeterminada) {
      final actuales = await _direcciones(uid).where('predeterminada', isEqualTo: true).get();
      final batch = _db.batch();
      for (final d in actuales.docs) {
        if (d.id != doc.id) {
          batch.update(d.reference, {'predeterminada': false});
        }
      }
      batch.set(doc, direccion.toMap(), SetOptions(merge: true));
      await batch.commit();
      return;
    }

    await doc.set(direccion.toMap(), SetOptions(merge: true));
  }

  Future<void> eliminarDireccion(String uid, String idDireccion) =>
      _direcciones(uid).doc(idDireccion).delete();
}
