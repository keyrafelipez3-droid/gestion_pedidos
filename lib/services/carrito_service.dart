import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/carrito_models.dart';

/// HU-20 a HU-23: carrito del cliente.
///
/// El carrito se filtra por `idNegocio` (igual que categorías/productos
/// en CatalogoService): un cliente solo ve en pantalla los items del
/// negocio que está viendo en ese momento. Si cambia de negocio sin
/// vaciar el carrito, los items del otro negocio simplemente no
/// aparecen en el stream (siguen guardados por si vuelve) — decisión
/// para no perder el carrito sin avisar; `vaciarCarrito` existe para el
/// flujo explícito de "¿vaciar tu carrito actual para pedir en este
/// negocio?" si la pantalla lo necesita.
class CarritoService {
  CarritoService._();
  static final instancia = CarritoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('usuarios').doc(uid).collection('carritoItems');

  Stream<List<CarritoItemModel>> streamCarrito(String uid, String idNegocio) =>
      _items(uid).where('idNegocio', isEqualTo: idNegocio).snapshots().map((qs) {
        final lista = qs.docs.map(CarritoItemModel.fromSnapshot).toList();
        lista.sort((a, b) =>
            (a.fechaAgregado ?? DateTime(0)).compareTo(b.fechaAgregado ?? DateTime(0)));
        return lista;
      });

  /// Agrega un producto al carrito. Si ya existe una línea con el mismo
  /// producto + mismas variantes/complementos + misma nota (ver
  /// `CarritoItemModel.claveAgrupacion`), le suma la cantidad en vez de
  /// crear una línea duplicada.
  Future<void> agregarAlCarrito(String uid, CarritoItemModel nuevoItem) async {
    final existentes =
        await _items(uid).where('idProducto', isEqualTo: nuevoItem.idProducto).get();
    final coleccion = existentes.docs.map(CarritoItemModel.fromSnapshot).toList();
    final iguales = coleccion.where((i) => i.claveAgrupacion == nuevoItem.claveAgrupacion);

    if (iguales.isNotEmpty) {
      final existente = iguales.first;
      await _items(uid).doc(existente.id).update({
        'cantidad': existente.cantidad + nuevoItem.cantidad,
      });
      return;
    }

    await _items(uid).add(nuevoItem.toMap());
  }

  /// HU-22: editar cantidad (si llega a 0 o menos, elimina el item).
  Future<void> actualizarCantidad(String uid, String itemId, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      return eliminarItem(uid, itemId);
    }
    return _items(uid).doc(itemId).update({'cantidad': nuevaCantidad});
  }

  /// HU-22: eliminar producto del carrito.
  Future<void> eliminarItem(String uid, String itemId) =>
      _items(uid).doc(itemId).delete();

  /// Vacía todos los items del carrito para un negocio (ej. después de
  /// confirmar el pedido, o al cambiar de negocio si el cliente acepta).
  Future<void> vaciarCarrito(String uid, String idNegocio) async {
    final items = await _items(uid).where('idNegocio', isEqualTo: idNegocio).get();
    final batch = _db.batch();
    for (final doc in items.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// HU-23: consultar el total del carrito.
  double calcularTotal(List<CarritoItemModel> items) =>
      items.fold(0, (acc, item) => acc + item.subtotal);
}
