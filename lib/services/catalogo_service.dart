import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/catalogo_models.dart';

class CatalogoService {
  CatalogoService._();
  static final instancia = CatalogoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String nombre) =>
      _db.collection(nombre);

  Stream<List<CategoriaModel>> streamCategorias() =>
      _collection('categorias').snapshots().map((qs) {
        final lista = qs.docs.map(CategoriaModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  Stream<List<ProductoModel>> streamProductos() =>
      _collection('productos').snapshots().map((qs) {
        final lista = qs.docs.map(ProductoModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  Stream<List<ComplementoModel>> streamComplementos() =>
      _collection('complementos').snapshots().map((qs) {
        final lista = qs.docs.map(ComplementoModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

  Stream<List<VarianteModel>> streamVariantes() =>
      _collection('variantes').snapshots().map((qs) {
        final lista = qs.docs.map(VarianteModel.fromSnapshot).toList();
        lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
        return lista;
      });

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
