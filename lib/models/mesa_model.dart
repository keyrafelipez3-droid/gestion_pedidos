import 'package:cloud_firestore/cloud_firestore.dart';

class MesaEstado {
  static const String libre = 'Libre';
  static const String ocupada = 'Ocupada';
  static const String reservada = 'Reservada';
  static const List<String> todos = [libre, ocupada, reservada];
}

/// Documento de `sucursales/{sucursalId}/mesas/{mesaId}` (HU-32: el
/// Cajero gestiona mesas y pedidos desde mesa).
class MesaModel {
  final String id;
  final String numero;
  final int capacidad;
  final String estado;
  final String? idNegocio;

  /// Cuántas personas ocupan la mesa ahora (opcional: el Cajero lo anota
  /// al asignarla). Solo tiene sentido mientras `estado == Ocupada`.
  final int? personas;

  const MesaModel({
    required this.id,
    required this.numero,
    this.capacidad = 4,
    this.estado = MesaEstado.libre,
    this.idNegocio,
    this.personas,
  });

  Map<String, dynamic> toMap() => {
        'numero': numero,
        'capacidad': capacidad,
        'estado': estado,
        'idNegocio': idNegocio,
        'personas': personas,
      };

  factory MesaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return MesaModel(
      id: doc.id,
      numero: data['numero'] as String? ?? '',
      capacidad: (data['capacidad'] as num?)?.toInt() ?? 4,
      estado: data['estado'] as String? ?? MesaEstado.libre,
      idNegocio: data['idNegocio'] as String?,
      personas: (data['personas'] as num?)?.toInt(),
    );
  }
}
