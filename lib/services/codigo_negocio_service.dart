import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/negocio_model.dart';
import 'negocio_service.dart';

/// Lo que se sabe de un restaurante a partir de su código, ANTES de entrar
/// (nombre, logo y colores), para que su enlace se vea como su propia app.
class InvitacionNegocio {
  final String codigo;
  final String idNegocio;
  final String nombre;
  final String logoUrl;
  final String colorPrimario;

  const InvitacionNegocio({
    required this.codigo,
    required this.idNegocio,
    required this.nombre,
    this.logoUrl = '',
    this.colorPrimario = '',
  });
}

/// Código de acceso de cada restaurante: lo crea el SuperAdmin y el cliente
/// lo escribe (o entra por el enlace del restaurante). Es opcional: el
/// cliente también puede elegir el restaurante en la lista con logos
/// (ver [unirseDesdeLista]). El código nunca se muestra en esa lista.
class CodigoNegocioService {
  CodigoNegocioService._();
  static final instancia = CodigoNegocioService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _codigos => _db.collection('codigosNegocio');

  /// Dirección pública de la app; cada restaurante tiene su enlace con su código.
  static const urlApp = 'https://gestion-pedidos-univalle.web.app';
  static String enlace(String codigo) => '$urlApp/?r=$codigo';

  /// Código que venía en el enlace con el que se abrió la app (solo web).
  static String? codigoDelEnlace;

  /// Letras y números fáciles de dictar (sin 0/O ni 1/I/L).
  static const _alfabeto = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String normalizar(String texto) =>
      texto.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String generar([Random? azar]) {
    final r = azar ?? Random.secure();
    return List.generate(6, (_) => _alfabeto[r.nextInt(_alfabeto.length)]).join();
  }

  /// Busca un código. null si no existe.
  Future<InvitacionNegocio?> buscar(String texto) async {
    final codigo = normalizar(texto);
    if (codigo.length < 4) return null;
    try {
      final doc = await _codigos.doc(codigo).get();
      final d = doc.data();
      if (!doc.exists || d == null || d['idNegocio'] is! String) return null;
      return InvitacionNegocio(
        codigo: codigo,
        idNegocio: d['idNegocio'] as String,
        nombre: d['nombre'] as String? ?? '',
        logoUrl: d['logoUrl'] as String? ?? '',
        colorPrimario: d['colorPrimario'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Documento privado con el código del negocio. Solo lo leen el
  /// SuperAdmin y el Administrador de ese negocio (ver firestore.rules).
  DocumentReference<Map<String, dynamic>> _acceso(String idNegocio) =>
      _db.collection('negocios').doc(idNegocio).collection('privado').doc('acceso');

  /// Código actual de un negocio (null si no tiene o si quien pregunta no
  /// lo puede ver: solo el SuperAdmin y el Administrador de ese negocio).
  Future<String?> codigoActual(String idNegocio) async {
    try {
      return (await _acceso(idNegocio).get()).data()?['codigo'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Código actual de un negocio, en vivo (null si todavía no tiene).
  Stream<String?> streamCodigo(String idNegocio) =>
      _acceso(idNegocio).snapshots().map((d) => d.data()?['codigo'] as String?);

  Map<String, dynamic> _marca(NegocioModel n) => {
        'idNegocio': n.idNegocio,
        'nombre': n.nombre,
        'logoUrl': n.logoUrl,
        'colorPrimario': n.colorPrimario,
      };

  /// SuperAdmin: crea (o cambia) el código del negocio. El código anterior
  /// deja de servir para entrar, pero quienes ya entraron siguen teniendo
  /// acceso.
  Future<String> asignarCodigo(NegocioModel negocio) async {
    final ref = _acceso(negocio.idNegocio);
    final anterior = (await ref.get()).data()?['codigo'] as String?;
    String codigo;
    var intentos = 0;
    do {
      codigo = generar();
      intentos++;
    } while ((await _codigos.doc(codigo).get()).exists && intentos < 10);
    final lote = _db.batch()
      ..set(_codigos.doc(codigo), _marca(negocio))
      ..set(ref, {'codigo': codigo});
    if (anterior != null && anterior.isNotEmpty) lote.delete(_codigos.doc(anterior));
    await lote.commit();
    // La tarjeta del restaurante en el inicio de sesión muestra el código
    // nuevo (aparte del lote: si falla, el código igual queda asignado).
    await NegocioService.instancia.publicarEnDirectorio(negocio, codigo: codigo);
    return codigo;
  }

  /// Mantiene el nombre, logo y color del enlace iguales a los del negocio.
  Future<void> sincronizarMarca(NegocioModel negocio) async {
    try {
      final codigo = (await _acceso(negocio.idNegocio).get()).data()?['codigo'] as String?;
      if (codigo == null || codigo.isEmpty) return;
      await _codigos.doc(codigo).set(_marca(negocio), SetOptions(merge: true));
    } catch (_) {
      // No es grave: el enlace sigue funcionando con los datos anteriores.
    }
  }

  CollectionReference<Map<String, dynamic>> _mios(String uid) =>
      _db.collection('usuarios').doc(uid).collection('misNegocios');

  /// El cliente entra a un restaurante con su código.
  Future<void> unirse(String uid, InvitacionNegocio inv) async {
    final ref = _mios(uid).doc(inv.idNegocio);
    if ((await ref.get()).exists) return; // ya había entrado
    await ref.set({'codigo': inv.codigo, 'fecha': FieldValue.serverTimestamp()});
  }

  /// El cliente entra a un restaurante eligiéndolo en la lista (sin
  /// código). Las reglas solo lo dejan si el restaurante está activo.
  Future<void> unirseDesdeLista(String uid, String idNegocio) async {
    final ref = _mios(uid).doc(idNegocio);
    if ((await ref.get()).exists) return; // ya había entrado
    await ref.set({'codigo': '', 'fecha': FieldValue.serverTimestamp()});
  }

  /// Ids de los restaurantes a los que el cliente entró, en vivo.
  Stream<List<String>> streamMisNegocios(String uid) =>
      _mios(uid).snapshots().map((qs) => qs.docs.map((d) => d.id).toList());
}
