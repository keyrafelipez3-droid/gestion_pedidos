import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
import '../models/pedido_models.dart';
import '../models/resena_model.dart';
import '../utils/moderacion.dart';
import 'sesion_actual.dart';

/// Reseñas de pedidos entregados y su moderación por el negocio.
class ResenaService {
  ResenaService._();
  static final instancia = ResenaService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _resenas(String idNegocio) =>
      _db.collection('negocios').doc(idNegocio).collection('resenas');

  List<ResenaModel> _ordenar(QuerySnapshot<Map<String, dynamic>> qs) {
    final lista = qs.docs.map(ResenaModel.fromSnapshot).toList();
    lista.sort((a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)));
    return lista;
  }

  /// Reseñas visibles del negocio (las que ve cualquier cliente).
  Stream<List<ResenaModel>> streamVisibles(String idNegocio) => _resenas(idNegocio)
      .where('estado', isEqualTo: ResenaEstado.visible)
      .snapshots()
      .map(_ordenar);

  /// Todas las reseñas, incluidas las ocultas (solo el Administrador).
  Stream<List<ResenaModel>> streamTodas(String idNegocio) =>
      _resenas(idNegocio).snapshots().map(_ordenar);

  /// La reseña de un pedido, o null si todavía no se escribió.
  Stream<ResenaModel?> streamDePedido(String idNegocio, String idPedido) =>
      _resenas(idNegocio)
          .doc(idPedido)
          .snapshots()
          .map((d) => d.exists ? ResenaModel.fromSnapshot(d) : null);

  /// "Ana Pérez Gómez" -> "Ana P."
  static String nombreCorto(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return 'Cliente';
    if (partes.length == 1) return partes.first;
    return '${partes.first} ${partes[1][0].toUpperCase()}.';
  }

  /// Publica la reseña de un pedido Entregado. Lanza un Exception con un
  /// mensaje claro si no se puede (comentario ofensivo, cuenta bloqueada...).
  Future<void> crear({
    required PedidoModel pedido,
    required int calificacion,
    required String comentario,
  }) async {
    final usuario = SesionActual.instancia.actual;
    if (usuario == null) throw Exception(tr('Inicia sesión para escribir una reseña.'));
    if (calificacion < 1 || calificacion > 5) {
      throw Exception(tr('Elige de 1 a 5 estrellas.'));
    }
    final texto = comentario.trim();
    if (texto.length > 500) {
      throw Exception(tr('El comentario es muy largo (máximo 500 letras).'));
    }
    if (Moderacion.contieneLenguajeInapropiado(texto)) {
      throw Exception(
          tr('Tu comentario tiene lenguaje no permitido. Reescríbelo con respeto y vuelve a intentar.'));
    }
    try {
      await _resenas(pedido.idNegocio).doc(pedido.id).set({
        'idNegocio': pedido.idNegocio,
        'idPedido': pedido.id,
        'idCliente': usuario.idUsuario,
        'nombreCliente': nombreCorto(usuario.nombre),
        'calificacion': calificacion,
        'comentario': texto,
        'fecha': FieldValue.serverTimestamp(),
        'estado': ResenaEstado.visible,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(
            tr('No puedes dejar una reseña en este negocio. Si crees que es un error, comunícate con el local.'));
      }
      rethrow;
    }
  }

  /// El cliente borra su propia reseña.
  Future<void> eliminar(String idNegocio, String idPedido) =>
      _resenas(idNegocio).doc(idPedido).delete();

  /// El Administrador oculta o vuelve a mostrar una reseña (no se borra).
  Future<void> moderar({
    required String idNegocio,
    required String idResena,
    required bool ocultar,
    String? motivo,
    required String idAdmin,
  }) =>
      _resenas(idNegocio).doc(idResena).update({
        'estado': ocultar ? ResenaEstado.oculta : ResenaEstado.visible,
        'motivoModeracion': ocultar ? (motivo ?? '') : FieldValue.delete(),
        'fechaModeracion': ocultar ? FieldValue.serverTimestamp() : FieldValue.delete(),
        'idAdminModeracion': ocultar ? idAdmin : FieldValue.delete(),
      });
}
