import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa un documento de `usuarios/{uid}/favoritos/{idProducto}`
/// (HU-19). El id del documento ES el idProducto (no uno autogenerado):
/// así, marcar/desmarcar un favorito es un solo set()/delete() por id
/// conocido, sin tener que hacer una query para saber si ya existe.
///
/// Vive como subcolección de usuarios/{uid}, así que ya queda cubierto
/// por la regla genérica `match /{subcollection}/{documentId}` dentro de
/// `usuarios/{userId}` en firestore.rules (el dueño lee/escribe las
/// suyas; Administrador del negocio o SuperAdmin también, igual que
/// direcciones o notificaciones) — no hizo falta agregar reglas nuevas.
class FavoritoModel {
  final String idProducto;
  final String idNegocio;
  final DateTime? fechaAgregado;

  const FavoritoModel({
    required this.idProducto,
    required this.idNegocio,
    this.fechaAgregado,
  });

  Map<String, dynamic> toMap() => {
        'idNegocio': idNegocio,
        'fechaAgregado': FieldValue.serverTimestamp(),
      };

  factory FavoritoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['fechaAgregado'] as Timestamp?;
    return FavoritoModel(
      idProducto: doc.id,
      idNegocio: data['idNegocio'] as String? ?? '',
      fechaAgregado: ts?.toDate(),
    );
  }
}
