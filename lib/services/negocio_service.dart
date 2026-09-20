import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/negocio_model.dart';

/// HU-07 — "Gestionar información general del negocio".
/// El sistema administra UN solo negocio, así que se usa un id fijo y
/// conocido (`principal`) para su documento en la colección raíz
/// `negocios`, en vez de tener que buscarlo cada vez.
class NegocioService {
  NegocioService._();
  static final NegocioService instancia = NegocioService._();

  static const String idNegocioPrincipal = 'principal';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('negocios').doc(idNegocioPrincipal);

  /// Trae los datos del negocio. Si el documento todavía no existe
  /// (proyecto recién configurado), devuelve un NegocioModel con valores
  /// por defecto para que el Administrador los complete por primera vez.
  Future<NegocioModel> obtenerNegocio() async {
    final snap = await _doc.get();
    if (!snap.exists) {
      return NegocioModel(idNegocio: idNegocioPrincipal, nombre: '');
    }
    return NegocioModel.fromMap(idNegocioPrincipal, snap.data() ?? {});
  }

  /// Crea o actualiza el documento del negocio (set con merge, así no hace
  /// falta preocuparse de si ya existía o no).
  Future<void> guardarNegocio(NegocioModel negocio) {
    return _doc.set(negocio.toMap(), SetOptions(merge: true));
  }
}
