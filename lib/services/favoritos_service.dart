import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/favorito_model.dart';

/// HU-19: favoritos del cliente.
class FavoritosService {
  FavoritosService._();
  static final instancia = FavoritosService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _favoritos(String uid) =>
      _db.collection('usuarios').doc(uid).collection('favoritos');

  Stream<List<FavoritoModel>> streamFavoritos(String uid) => _favoritos(uid)
      .snapshots()
      .map((qs) => qs.docs.map(FavoritoModel.fromSnapshot).toList());

  /// Solo los ids, para que la pantalla del menú pinte el corazón
  /// lleno/vacío de cada producto comparando contra un Set en vez de
  /// comparar objetos completos.
  Stream<Set<String>> streamIdsFavoritos(String uid) =>
      streamFavoritos(uid).map((lista) => lista.map((f) => f.idProducto).toSet());

  Future<void> agregarFavorito({
    required String uid,
    required String idProducto,
    required String idNegocio,
  }) {
    final favorito = FavoritoModel(idProducto: idProducto, idNegocio: idNegocio);
    return _favoritos(uid).doc(idProducto).set(favorito.toMap());
  }

  Future<void> quitarFavorito({required String uid, required String idProducto}) =>
      _favoritos(uid).doc(idProducto).delete();

  /// Botón de corazón: si ya es favorito lo quita, si no lo agrega.
  /// `esFavoritoActual` lo decide la pantalla (ya tiene el Set cargado
  /// desde streamIdsFavoritos), así se evita una lectura extra acá.
  Future<void> alternarFavorito({
    required String uid,
    required String idProducto,
    required String idNegocio,
    required bool esFavoritoActual,
  }) {
    if (esFavoritoActual) {
      return quitarFavorito(uid: uid, idProducto: idProducto);
    }
    return agregarFavorito(uid: uid, idProducto: idProducto, idNegocio: idNegocio);
  }
}
