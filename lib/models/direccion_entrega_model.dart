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

  /// Ubicacion marcada en el mapa (puede faltar en direcciones antiguas).
  final double? latitud;
  final double? longitud;

  const DireccionEntregaModel({
    required this.id,
    required this.etiqueta,
    required this.direccion,
    this.referencia = '',
    this.predeterminada = false,
    this.fechaRegistro,
    this.latitud,
    this.longitud,
  });

  bool get tieneUbicacion => latitud != null && longitud != null;

  Map<String, dynamic> toMap() => {
        'etiqueta': etiqueta,
        'direccion': direccion,
        'referencia': referencia,
        'predeterminada': predeterminada,
        'fechaRegistro': FieldValue.serverTimestamp(),
        if (tieneUbicacion) 'latitud': latitud,
        if (tieneUbicacion) 'longitud': longitud,
      };

  /// Snapshot "congelado" para guardar dentro de un Pedido: el pedido no
  /// depende de que esta dirección siga existiendo o sin cambios después
  /// (el cliente podría editarla o borrarla más adelante).
  Map<String, dynamic> toSnapshotMap() => {
        'etiqueta': etiqueta,
        'direccion': direccion,
        'referencia': referencia,
        if (tieneUbicacion) 'latitud': latitud,
        if (tieneUbicacion) 'longitud': longitud,
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
      latitud: (data['latitud'] as num?)?.toDouble(),
      longitud: (data['longitud'] as num?)?.toDouble(),
    );
  }
}
