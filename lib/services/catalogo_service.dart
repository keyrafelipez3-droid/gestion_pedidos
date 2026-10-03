import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalogo_models.dart';

/// Corrección pedida por el docente (multi-tenant): cada stream ahora
/// recibe el `idNegocio` del Administrador/personal logueado y filtra con
/// un solo `where` de igualdad — el orden se sigue haciendo en Dart (como
/// ya se hacía antes) para no obligar a crear un índice compuesto nuevo en
/// Firestore que bloquearía la app hasta crearlo manualmente.
class CatalogoService {
  CatalogoService._();
  static final instancia = CatalogoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String nombre) =>
      _db.collection(nombre);

  Stream<List<CategoriaModel>> streamCategorias(String idNegocio) =>
      _collection('categorias')
          .where('idNegocio', isEqualTo: idNegocio)
          .snapshots()
          .map((qs) {
        final lista = qs.docs.map(CategoriaModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  Stream<List<ProductoModel>> streamProductos(String idNegocio) =>
      _collection('productos')
          .where('idNegocio', isEqualTo: idNegocio)
          .snapshots()
          .map((qs) {
        final lista = qs.docs.map(ProductoModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  Stream<List<ComplementoModel>> streamComplementos(String idNegocio) =>
      _collection('complementos')
          .where('idNegocio', isEqualTo: idNegocio)
          .snapshots()
          .map((qs) {
        final lista = qs.docs.map(ComplementoModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  Stream<List<VarianteModel>> streamVariantes(String idNegocio) =>
      _collection('variantes')
          .where('idNegocio', isEqualTo: idNegocio)
          .snapshots()
          .map((qs) {
        final lista = qs.docs.map(VarianteModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  /// Igual que en sucursales: id de documento nuevo sin crear el
  /// documento todavía, para poder subir la imagen a Storage antes de
  /// guardar (misma ruta estable para la imagen y el documento final).
  String nuevaIdCategoria() => _collection('categorias').doc().id;
  String nuevaIdProducto() => _collection('productos').doc().id;

  Future<void> guardarCategoria(CategoriaModel item) async {
    final doc = item.id.isEmpty
        ? _collection('categorias').doc()
        : _collection('categorias').doc(item.id);
    await doc.set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> cambiarEstadoCategoria(String id, bool estado) =>
      _collection('categorias').doc(id).update({'estado': estado});

  Future<void> eliminarCategoria(String id) => _collection('categorias').doc(id).delete();

  Future<void> guardarProducto(ProductoModel item) async {
    final doc = item.id.isEmpty
        ? _collection('productos').doc()
        : _collection('productos').doc(item.id);
    await doc.set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> cambiarEstadoProducto(String id, bool estado) =>
      _collection('productos').doc(id).update({'estado': estado});

  Future<void> eliminarProducto(String id) => _collection('productos').doc(id).delete();

  Future<void> cambiarDisponibilidadProducto(String id, bool disponible) =>
      _collection('productos').doc(id).update({'disponible': disponible});

  Future<void> guardarComplemento(ComplementoModel item) async {
    final doc = item.id.isEmpty
        ? _collection('complementos').doc()
        : _collection('complementos').doc(item.id);
    await doc.set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> cambiarEstadoComplemento(String id, bool estado) =>
      _collection('complementos').doc(id).update({'estado': estado});

  Future<void> eliminarComplemento(String id) => _collection('complementos').doc(id).delete();

  Future<void> guardarVariante(VarianteModel item) async {
    final doc = item.id.isEmpty
        ? _collection('variantes').doc()
        : _collection('variantes').doc(item.id);
    await doc.set(item.toMap(), SetOptions(merge: true));
  }

  Future<void> cambiarEstadoVariante(String id, bool estado) =>
      _collection('variantes').doc(id).update({'estado': estado});

  Future<void> eliminarVariante(String id) => _collection('variantes').doc(id).delete();
}
