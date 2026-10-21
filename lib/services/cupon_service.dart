import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
import '../models/cupon_model.dart';

class CuponException implements Exception {
  final String mensaje;
  const CuponException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Cupones de descuento de cada negocio.
class CuponService {
  CuponService._();
  static final instancia = CuponService._();

  CollectionReference<Map<String, dynamic>> _col(String idNegocio) =>
      FirebaseFirestore.instance.collection('negocios').doc(idNegocio).collection('cupones');

  static String normalizar(String codigo) =>
      codigo.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9_-]'), '');

  Stream<List<CuponModel>> stream(String idNegocio) => _col(idNegocio).snapshots().map((qs) {
        final lista = qs.docs.map(CuponModel.fromSnapshot).toList();
        lista.sort((a, b) => a.codigo.compareTo(b.codigo));
        return lista;
      });

  Future<void> guardar(String idNegocio, CuponModel cupon) =>
      _col(idNegocio).doc(cupon.codigo).set(cupon.toMap());

  Future<void> cambiarActivo(String idNegocio, String codigo, bool activo) =>
      _col(idNegocio).doc(codigo).update({'activo': activo});

  Future<void> eliminar(String idNegocio, String codigo) => _col(idNegocio).doc(codigo).delete();

  /// Busca el cupón y comprueba que se pueda usar en una compra de
  /// [subtotal] Bs. Lanza [CuponException] con un mensaje para el cliente.
  Future<CuponModel> validar(String idNegocio, String codigo, double subtotal) async {
    final limpio = normalizar(codigo);
    if (limpio.isEmpty) throw CuponException(tr('Escribe el código del cupón.'));
    final doc = await _col(idNegocio).doc(limpio).get();
    if (!doc.exists) throw CuponException(tr('Ese cupón no existe en este negocio.'));
    final cupon = CuponModel.fromSnapshot(doc);
    if (!cupon.activo) throw CuponException(tr('Ese cupón ya no está activo.'));
    if (cupon.vencido) throw CuponException(tr('Ese cupón ya venció.'));
    if (subtotal < cupon.minimo) {
      throw CuponException(tr('Este cupón es para compras desde Bs {minimo}.',
          {'minimo': cupon.minimo.toStringAsFixed(2)}));
    }
    return cupon;
  }
}
