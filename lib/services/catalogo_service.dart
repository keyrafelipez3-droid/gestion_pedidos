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

  /// Lista de precios del negocio (`negocios/{id}/publico/precios`). Las
  /// reglas de Firestore la usan para comprobar los precios de un pedido,
  /// así que se actualiza siempre junto con el producto. Tiene:
  /// - `normal`: {idProducto: precio}
  /// - `promo`: {idProducto: precio de promoción} (solo promociones vigentes)
  /// - `hasta`: {idProducto: fin de la promoción}
  /// - `promoHasta`: la fecha de fin más cercana; desde ahí ninguna
  ///   promoción se acepta hasta que se vuelva a guardar un producto.
  DocumentReference<Map<String, dynamic>> _precios(String idNegocio) =>
      _db.collection('negocios').doc(idNegocio).collection('publico').doc('precios');

  /// Lista de precios con [producto] actualizado (o quitado, si
  /// [producto] es null). Las promociones vencidas se limpian.
  Future<Map<String, dynamic>> _listaCon(String idNegocio, String id, ProductoModel? producto) async {
    final data = (await _precios(idNegocio).get()).data() ?? {};
    final normal = Map<String, dynamic>.from(data['normal'] as Map? ?? {});
    final promo = Map<String, dynamic>.from(data['promo'] as Map? ?? {});
    final hasta = Map<String, dynamic>.from(data['hasta'] as Map? ?? {});
    normal.remove(id);
    promo.remove(id);
    hasta.remove(id);
    if (producto != null) {
      normal[id] = producto.precio;
      if (producto.promoActiva()) {
        promo[id] = producto.precioPromo;
        if (producto.promoHasta != null) hasta[id] = Timestamp.fromDate(producto.promoHasta!);
      }
    }
    // Se quitan las promociones que ya vencieron.
    final ahora = DateTime.now();
    for (final pid in hasta.keys.toList()) {
      final fin = (hasta[pid] as Timestamp).toDate();
      if (!ahora.isBefore(fin)) {
        promo.remove(pid);
        hasta.remove(pid);
      }
    }
    Timestamp? primera;
    for (final t in hasta.values) {
      final ts = t as Timestamp;
      if (primera == null || ts.compareTo(primera) < 0) primera = ts;
    }
    return {'normal': normal, 'promo': promo, 'hasta': hasta, 'promoHasta': primera};
  }

  Future<void> guardarProducto(ProductoModel item) async {
    final doc = item.id.isEmpty
        ? _collection('productos').doc()
        : _collection('productos').doc(item.id);
    final lote = _db.batch()..set(doc, item.toMap(), SetOptions(merge: true));
    final idNegocio = item.idNegocio;
    if (idNegocio != null && idNegocio.isNotEmpty) {
      lote.set(_precios(idNegocio), await _listaCon(idNegocio, doc.id, item));
    }
    await lote.commit();
  }

  Future<void> cambiarEstadoProducto(String id, bool estado) =>
      _collection('productos').doc(id).update({'estado': estado});

  /// Borra el producto y lo saca de la lista de precios (ya no se puede pedir).
  Future<void> eliminarProducto(String id) async {
    final doc = _collection('productos').doc(id);
    final idNegocio = (await doc.get()).data()?['idNegocio'] as String?;
    final lote = _db.batch()..delete(doc);
    if (idNegocio != null && idNegocio.isNotEmpty) {
      lote.set(_precios(idNegocio), await _listaCon(idNegocio, id, null));
    }
    await lote.commit();
  }

  /// La lista de precios guarda la fecha de la promoción que vence primero
  /// (`promoHasta`): pasada esa fecha, las reglas ya no aceptan NINGUNA
  /// promoción, aunque otras sigan vigentes. Si eso pasó, el Administrador
  /// la vuelve a escribir sin las promociones vencidas (se llama al abrir
  /// su panel). Si no venció nada, no escribe.
  Future<void> limpiarPromosVencidas(String idNegocio) async {
    try {
      final data = (await _precios(idNegocio).get()).data();
      final fin = (data?['promoHasta'] as Timestamp?)?.toDate();
      if (fin == null || DateTime.now().isBefore(fin)) return;
      await _precios(idNegocio).set(await _listaCon(idNegocio, '', null));
    } catch (_) {
      // Sin conexión o sin permiso: se intentará la próxima vez.
    }
  }

  Future<void> cambiarDisponibilidadProducto(String id, bool disponible) =>
      _collection('productos').doc(id).update({'disponible': disponible});

  /// Precio que se puede cobrar hoy por cada producto del negocio, leído de
  /// la lista de precios (lo mismo que comprueban las reglas). Un producto
  /// que no está en la lista no se puede pedir.
  Future<Map<String, double>> preciosVigentes(String idNegocio) async {
    final data = (await _precios(idNegocio).get()).data() ?? {};
    final normal = data['normal'] as Map? ?? {};
    final promo = data['promo'] as Map? ?? {};
    final fin = (data['promoHasta'] as Timestamp?)?.toDate();
    final promosVigentes = fin == null || DateTime.now().isBefore(fin);
    final precios = <String, double>{};
    normal.forEach((id, precio) {
      if (precio is! num) return;
      final p = promo[id];
      precios[id as String] = promosVigentes && p is num ? p.toDouble() : precio.toDouble();
    });
    return precios;
  }

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
