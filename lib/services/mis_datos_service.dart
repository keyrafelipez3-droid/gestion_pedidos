import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// "Descargar mis datos": junta en un archivo JSON lo que la app guarda de
/// una persona (perfil, direcciones, favoritos, restaurantes a los que
/// entró, sus pedidos con su dirección y factura, sus reseñas y reclamos),
/// para que pueda verlo o llevárselo a otro lado (derecho de acceso a sus
/// datos).
class MisDatosService {
  MisDatosService._();
  static final instancia = MisDatosService._();

  final _db = FirebaseFirestore.instance;

  Future<String> generarJson(String uid) async {
    final usuarioRef = _db.collection('usuarios').doc(uid);
    final usuario = await usuarioRef.get();
    final datos = <String, dynamic>{
      'generadoEl': DateTime.now().toIso8601String(),
      'perfil': _mapa(usuario.data() ?? {}),
    };

    for (final sub in ['direcciones', 'favoritos', 'misNegocios']) {
      try {
        final qs = await usuarioRef.collection(sub).get();
        datos[sub] = [
          for (final d in qs.docs) {'id': d.id, ..._mapa(d.data())},
        ];
      } catch (_) {
        datos[sub] = [];
      }
    }

    final pedidos = await _db.collection('pedidos').where('idCliente', isEqualTo: uid).get();
    final lista = <Map<String, dynamic>>[];
    for (final p in pedidos.docs) {
      Map<String, dynamic>? contacto;
      try {
        contacto = (await p.reference.collection('privado').doc('contacto').get()).data();
      } catch (_) {
        // Pedidos anteriores: la dirección está dentro del propio pedido.
      }
      lista.add({
        'id': p.id,
        ..._mapa(p.data()),
        if (contacto != null) 'contacto': _mapa(contacto),
      });
    }
    datos['pedidos'] = lista;

    // Reseñas y reclamos que escribió en cada restaurante (en los que pidió
    // y en los que tiene guardados).
    final negocios = <String>{
      for (final p in pedidos.docs)
        if (p.data()['idNegocio'] is String) p.data()['idNegocio'] as String,
      for (final n in (datos['misNegocios'] as List)) (n as Map)['id'] as String,
    };
    for (final sub in ['resenas', 'reclamos']) {
      final escritos = <Map<String, dynamic>>[];
      for (final idNegocio in negocios) {
        try {
          final qs = await _db
              .collection('negocios')
              .doc(idNegocio)
              .collection(sub)
              .where('idCliente', isEqualTo: uid)
              .get();
          escritos.addAll([for (final d in qs.docs) {'id': d.id, ..._mapa(d.data())}]);
        } catch (_) {
          // Si no se pueden leer los de un restaurante, se sigue con los demás.
        }
      }
      datos[sub] = escritos;
    }

    return const JsonEncoder.withIndent('  ').convert(datos);
  }

  Map<String, dynamic> _mapa(Map<String, dynamic> m) => {
        for (final e in m.entries) e.key: _limpiar(e.value),
      };

  /// Firestore guarda fechas y ubicaciones en tipos propios: se pasan a
  /// texto y números para que el JSON se pueda leer en cualquier lado.
  dynamic _limpiar(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is GeoPoint) return {'latitud': v.latitude, 'longitud': v.longitude};
    if (v is DocumentReference) return v.path;
    if (v is FieldValue) return null;
    if (v is Map) return {for (final e in v.entries) '${e.key}': _limpiar(e.value)};
    if (v is List) return [for (final x in v) _limpiar(x)];
    return v;
  }
}
