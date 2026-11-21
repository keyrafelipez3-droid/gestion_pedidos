import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/negocio_model.dart';
import 'codigo_negocio_service.dart';

/// HU-07 — "Gestionar información general del negocio".
///
/// Corrección pedida por el docente: el sistema ahora es multi-tenant —
/// la colección `negocios` puede tener VARIOS documentos. El SuperAdmin
/// los crea y personaliza todos (ver `superadmin_negocios_screen.dart`);
/// cada Administrador queda asignado a uno solo (`UsuarioModel.idNegocio`)
/// y lo usa como de siempre desde "Datos del negocio"/dashboard, solo que
/// ahora pasando explícitamente SU idNegocio en vez de uno fijo.
class NegocioService {
  NegocioService._();
  static final NegocioService instancia = NegocioService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('negocios');

  /// Trae los datos de UN negocio por su id. Si el documento todavía no
  /// existe, devuelve un NegocioModel con valores por defecto (mismo
  /// comportamiento de siempre, para no romper pantallas que ya lo
  /// esperaban así).
  Future<NegocioModel> obtenerNegocioPorId(String idNegocio) async {
    final snap = await _col.doc(idNegocio).get();
    if (!snap.exists) {
      return NegocioModel(idNegocio: idNegocio, nombre: '');
    }
    return NegocioModel.fromMap(idNegocio, snap.data() ?? {});
  }

  /// Lista en tiempo real de TODOS los negocios — SOLO para el panel del
  /// SuperAdmin (elegir cuál personalizar, o a cuál asignar un nuevo
  /// Administrador). Las reglas no dejan listar a nadie más.
  Stream<List<NegocioModel>> streamNegocios() => _col.snapshots().map(
        (qs) => qs.docs
            .map((d) => NegocioModel.fromMap(d.id, d.data()))
            .toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())),
      );

  /// Los negocios a los que entró el cliente, leídos uno por uno por su id
  /// (el cliente no puede listar todos los negocios). Si alguno falla o ya
  /// no existe, simplemente no aparece.
  Future<List<NegocioModel>> obtenerNegociosPorIds(List<String> ids) async {
    final lista = <NegocioModel>[];
    for (final id in ids) {
      try {
        final snap = await _col.doc(id).get();
        if (snap.exists) lista.add(NegocioModel.fromMap(id, snap.data() ?? {}));
      } catch (_) {}
    }
    lista.sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
    return lista;
  }

  /// Crea un negocio nuevo (id autogenerado por Firestore) y devuelve su
  /// id — lo necesita el SuperAdmin para luego asignarlo a un
  /// Administrador recién creado.
  Future<String> crearNegocio(NegocioModel negocio) async {
    final doc = _col.doc();
    await doc.set(negocio.toMap());
    return doc.id;
  }

  /// Crea o actualiza el documento de un negocio ya existente (set con
  /// merge, así no hace falta preocuparse de si ya existía o no).
  Future<void> guardarNegocio(NegocioModel negocio) async {
    await _col.doc(negocio.idNegocio).set(negocio.toMap(), SetOptions(merge: true));
    // El enlace del restaurante muestra su nombre y logo actuales.
    await CodigoNegocioService.instancia.sincronizarMarca(negocio);
  }

  Future<void> cambiarEstadoNegocio(String idNegocio, bool estado) =>
      _col.doc(idNegocio).update({'estado': estado});
}
