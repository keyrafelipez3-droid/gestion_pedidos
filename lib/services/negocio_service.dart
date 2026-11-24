import 'dart:async';

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

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('negocios');

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
  ///
  /// De paso mantiene al día la lista pública de restaurantes
  /// (`directorio`): así los restaurantes que ya existían aparecen en el
  /// inicio de sesión apenas el SuperAdmin abre su panel.
  Stream<List<NegocioModel>> streamNegocios() => _col.snapshots().map((qs) {
    final lista =
        qs.docs.map((d) => NegocioModel.fromMap(d.id, d.data())).toList()..sort(
          (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
        );
    for (final n in lista) {
      unawaited(publicarEnDirectorio(n));
    }
    return lista;
  });

  // ------------------------------------------------ lista pública
  // `directorio/{idNegocio}`: SOLO nombre, logo, color, ciudad y el código
  // para entrar de cada restaurante activo. La lee cualquiera, incluso sin
  // sesión (pantalla de inicio de sesión), para que el cliente vea el
  // código en la tarjeta del restaurante y pueda entrar. No lleva NIT,
  // teléfono, dirección ni QR de pago.
  CollectionReference<Map<String, dynamic>> get _directorio =>
      _db.collection('directorio');

  /// Lo último que se publicó de cada negocio en esta sesión, para no
  /// escribir lo mismo otra vez.
  final Map<String, String> _publicado = {};

  /// Código de cada negocio ya leído en esta sesión ('' = no tiene).
  final Map<String, String> _codigoConocido = {};

  /// Quita espacios de más ("pollos     locos" -> "pollos locos").
  static String limpio(String? texto) =>
      (texto ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();

  static Map<String, dynamic> datosPublicos(NegocioModel n) => {
    'nombre': limpio(n.nombre),
    'logoUrl': n.logoUrl.trim(),
    'colorPrimario': n.colorPrimario.trim(),
    'ciudad': limpio(n.ciudad),
  };

  /// Publica (o quita, si está desactivado o sin nombre) un restaurante en
  /// la lista pública, con su código para entrar si ya tiene uno. Nunca
  /// falla: si no se puede, queda como estaba.
  ///
  /// [codigo]: si ya se conoce (recién asignado), se usa ese; si no, se lee
  /// el actual del negocio.
  Future<void> publicarEnDirectorio(NegocioModel n, {String? codigo}) async {
    if (n.idNegocio.isEmpty) return;
    final visible = n.estado && n.nombre.trim().isNotEmpty;
    final datos = datosPublicos(n);
    if (visible) {
      // El código se lee una sola vez por sesión (la lista del SuperAdmin
      // llama a esto con cada cambio; así no se gastan lecturas de más).
      if (codigo != null) _codigoConocido[n.idNegocio] = codigo;
      final c = _codigoConocido[n.idNegocio] ??=
          await CodigoNegocioService.instancia.codigoActual(n.idNegocio) ?? '';
      if (c.isNotEmpty) datos['codigo'] = c;
    }
    final firma = visible ? datos.values.join('|') : '-';
    if (_publicado[n.idNegocio] == firma) return;
    try {
      if (visible) {
        try {
          await _directorio.doc(n.idNegocio).set(datos);
        } on FirebaseException {
          // Si las reglas publicadas todavía no aceptan el código, se
          // publica igual el resto (nombre, logo...) para no perder la
          // tarjeta del restaurante.
          if (!datos.containsKey('codigo')) rethrow;
          // Pero si la tarjeta ya tiene su código (por ejemplo, publicado
          // con scripts/demo/publicar_directorio.js), no se le quita.
          final actual = await _directorio.doc(n.idNegocio).get();
          if ((actual.data()?['codigo'] as String? ?? '').isNotEmpty) rethrow;
          datos.remove('codigo');
          await _directorio.doc(n.idNegocio).set(datos);
        }
      } else {
        await _directorio.doc(n.idNegocio).delete();
      }
      _publicado[n.idNegocio] = firma;
    } catch (_) {
      // No es grave: la lista pública se vuelve a intentar la próxima vez.
    }
  }

  /// Restaurantes de la lista pública (para la pantalla de inicio de
  /// sesión). Se leen una sola vez; si falla, la lista queda vacía.
  Future<List<Map<String, String>>> directorioPublico() async {
    try {
      final qs = await _directorio.limit(30).get();
      final lista = [
        for (final d in qs.docs)
          {
            'nombre': limpio(d.data()['nombre'] as String?),
            'logoUrl': d.data()['logoUrl'] as String? ?? '',
            'colorPrimario': d.data()['colorPrimario'] as String? ?? '',
            'ciudad': limpio(d.data()['ciudad'] as String?),
            'codigo': d.data()['codigo'] as String? ?? '',
          },
      ]..removeWhere((m) => m['nombre']!.isEmpty);
      lista.sort(
        (a, b) =>
            a['nombre']!.toLowerCase().compareTo(b['nombre']!.toLowerCase()),
      );
      return lista;
    } catch (_) {
      return const [];
    }
  }

  /// Restaurantes ACTIVOS, en vivo, ordenados por nombre: la lista con
  /// logo que ve el cliente para elegir dónde pedir sin saber el código.
  /// Las reglas solo dejan esta consulta a clientes y solo con
  /// `estado == true`; el código de acceso no está en estos documentos.
  Stream<List<NegocioModel>> streamDirectorio() => _col
      .where('estado', isEqualTo: true)
      .snapshots()
      .map(
        (qs) =>
            qs.docs
                .map((d) => NegocioModel.fromMap(d.id, d.data()))
                .where((n) => n.nombre.trim().isNotEmpty)
                .toList()
              ..sort(
                (a, b) =>
                    a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
              ),
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
    lista.sort(
      (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
    );
    return lista;
  }

  /// Crea un negocio nuevo (id autogenerado por Firestore) y devuelve su
  /// id — lo necesita el SuperAdmin para luego asignarlo a un
  /// Administrador recién creado.
  Future<String> crearNegocio(NegocioModel negocio) async {
    final doc = _col.doc();
    await doc.set(negocio.toMap());
    await publicarEnDirectorio(NegocioModel.fromMap(doc.id, negocio.toMap()));
    return doc.id;
  }

  /// Crea o actualiza el documento de un negocio ya existente (set con
  /// merge, así no hace falta preocuparse de si ya existía o no).
  Future<void> guardarNegocio(NegocioModel negocio) async {
    await _col
        .doc(negocio.idNegocio)
        .set(negocio.toMap(), SetOptions(merge: true));
    // El enlace del restaurante muestra su nombre y logo actuales.
    await CodigoNegocioService.instancia.sincronizarMarca(negocio);
    // Y la lista pública de restaurantes, con el estado real del negocio
    // (el Administrador no puede cambiar el estado).
    try {
      await publicarEnDirectorio(await obtenerNegocioPorId(negocio.idNegocio));
    } catch (_) {}
  }

  Future<void> cambiarEstadoNegocio(String idNegocio, bool estado) async {
    await _col.doc(idNegocio).update({'estado': estado});
    try {
      await publicarEnDirectorio(await obtenerNegocioPorId(idNegocio));
    } catch (_) {}
  }
}
