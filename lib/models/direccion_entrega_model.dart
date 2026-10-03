import 'package:cloud_firestore/cloud_firestore.dart';

/// Documento de `usuarios/{uid}/direcciones/{direccionId}` (HU-25:
/// registrar y seleccionar dirección de delivery). Subcolección propia
/// del usuario, cubierta por la regla genérica de `usuarios/{userId}` en
/// firestore.rules — no necesitó reglas nuevas.
class DireccionEntregaModel {
  final String id;
  final String etiqueta; // ej. "Casa", "Trabajo"
  final String direccion;
  final String referencia;
  final bool predeterminada;
  final DateTime? fechaRegistro;

  const DireccionEntregaModel({
    required this.id,
    required this.etiqueta,
    required this.direccion,
    this.referencia = '',
    this.predeterminada = false,
    this.fechaRegistro,
  });

  Map<String, dynamic> toMap() => {
        'etiqueta': etiqueta,
        'direccion': direccion,
        'referencia': referencia,
        'predeterminada': predeterminada,
        'fechaRegistro': FieldValue.serverTimestamp(),
      };

  /// Snapshot "congelado" para guardar dentro de un Pedido: el pedido no
  /// depende de que esta dirección siga existiendo o sin cambios después
  /// (el cliente podría editarla o borrarla más adelante).
  Map<String, dynamic> toSnapshotMap() => {
        'etiqueta': etiqueta,
        'direccion': direccion,
        'referencia': referencia,
      };

  factory DireccionEntregaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['fechaRegistro'] as Timestamp?;
    return DireccionEntregaModel(
      id: doc.id,
      etiqueta: data['etiqueta'] as String? ?? '',
      direccion: data['direccion'] as String? ?? '',
      referencia: data['referencia'] as String? ?? '',
      predeterminada: data['predeterminada'] as bool? ?? false,
      fechaRegistro: ts?.toDate(),
    );
  }
}
