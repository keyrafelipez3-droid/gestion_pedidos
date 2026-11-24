import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
import '../models/reclamo_model.dart';
import 'resena_service.dart';
import 'sesion_actual.dart';

/// Libro de reclamos de cada negocio.
class ReclamoService {
  ReclamoService._();
  static final instancia = ReclamoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _reclamos(String idNegocio) =>
      _db.collection('negocios').doc(idNegocio).collection('reclamos');

  List<ReclamoModel> _ordenar(QuerySnapshot<Map<String, dynamic>> qs) {
    final lista = qs.docs.map(ReclamoModel.fromSnapshot).toList();
    lista.sort((a, b) => (b.fecha ?? DateTime(0)).compareTo(a.fecha ?? DateTime(0)));
    return lista;
  }

  /// Los reclamos que hizo el cliente en este negocio.
  Stream<List<ReclamoModel>> streamMios(String idNegocio, String idCliente) =>
      _reclamos(idNegocio).where('idCliente', isEqualTo: idCliente).snapshots().map(_ordenar);

  /// Todos los reclamos del negocio (solo el Administrador).
  Stream<List<ReclamoModel>> streamTodos(String idNegocio) =>
      _reclamos(idNegocio).snapshots().map(_ordenar);

  /// Los [limite] reclamos más recientes del negocio (solo el
  /// Administrador). Para los avisos: no lee todos los reclamos.
  Stream<List<ReclamoModel>> streamRecientes(String idNegocio, {int limite = 15}) =>
      _reclamos(idNegocio).orderBy('fecha', descending: true).limit(limite).snapshots().map(_ordenar);

  /// El cliente presenta un reclamo. Lanza un Exception con un mensaje claro
  /// si algo no está bien.
  Future<void> crear({
    required String idNegocio,
    String idPedido = '',
    required String motivo,
    required String descripcion,
  }) async {
    final usuario = SesionActual.instancia.actual;
    if (usuario == null) throw Exception(tr('Inicia sesión para presentar un reclamo.'));
    final texto = descripcion.trim();
    if (texto.length < 10) {
      throw Exception(tr('Cuéntanos un poco más (mínimo 10 letras).'));
    }
    if (texto.length > 1000) {
      throw Exception(tr('El texto es muy largo (máximo 1000 letras).'));
    }
    if (!ReclamoMotivo.todos.contains(motivo)) {
      throw Exception(tr('Elige un motivo.'));
    }
    try {
      await _reclamos(idNegocio).add({
        'idNegocio': idNegocio,
        'idCliente': usuario.idUsuario,
        'nombreCliente': ResenaService.nombreCorto(usuario.nombre),
        'idPedido': idPedido,
        'motivo': motivo,
        'descripcion': texto,
        'estado': ReclamoEstado.abierto,
        'fecha': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception(tr('No se pudo enviar el reclamo. Comunícate con el negocio por sus datos de contacto.'));
      }
      rethrow;
    }
  }

  /// El Administrador marca que ya lo está viendo.
  Future<void> ponerEnRevision(String idNegocio, String idReclamo) =>
      _reclamos(idNegocio).doc(idReclamo).update({'estado': ReclamoEstado.enRevision});

  /// El Administrador responde y cierra el reclamo.
  Future<void> responder({
    required String idNegocio,
    required String idReclamo,
    required String respuesta,
    required String idAdmin,
  }) async {
    final texto = respuesta.trim();
    if (texto.length < 5) throw Exception('Escribe una respuesta para el cliente.');
    if (texto.length > 1000) throw Exception('La respuesta es muy larga (máximo 1000 letras).');
    await _reclamos(idNegocio).doc(idReclamo).update({
      'estado': ReclamoEstado.resuelto,
      'respuesta': texto,
      'fechaRespuesta': FieldValue.serverTimestamp(),
      'idRespondio': idAdmin,
    });
  }
}
