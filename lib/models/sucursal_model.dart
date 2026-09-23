import 'package:cloud_firestore/cloud_firestore.dart';

class HorarioDia {
  final bool activo;
  final String apertura;
  final String cierre;

  const HorarioDia({this.activo = false, this.apertura = '08:00', this.cierre = '18:00'});

  Map<String, dynamic> toMap() => {
        'activo': activo,
        'apertura': apertura,
        'cierre': cierre,
      };

  factory HorarioDia.fromMap(Map<String, dynamic> data) => HorarioDia(
        activo: data['activo'] as bool? ?? false,
        apertura: data['apertura'] as String? ?? '08:00',
        cierre: data['cierre'] as String? ?? '18:00',
      );
}

class SucursalModel {
  final String id;
  final String nombre;
  final String direccion;
  final String telefono;
  final String imagenUrl;
  final bool estado;
  final Map<String, HorarioDia> horarios;

  const SucursalModel({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.telefono = '',
    this.imagenUrl = '',
    this.estado = true,
    this.horarios = const {},
  });

  static const dias = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static Map<String, HorarioDia> horariosPorDefecto() => {
        for (final dia in dias) dia: const HorarioDia(),
      };

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'imagenUrl': imagenUrl,
        'estado': estado,
        'horarios': {
          for (final entry in horarios.entries) entry.key: entry.value.toMap(),
        },
      };

  factory SucursalModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawHorarios = data['horarios'];
    final horarios = <String, HorarioDia>{};
    if (rawHorarios is Map) {
      for (final entry in rawHorarios.entries) {
        if (entry.value is Map) {
          horarios[entry.key.toString()] = HorarioDia.fromMap(
            Map<String, dynamic>.from(entry.value as Map),
          );
        }
      }
    }
    return SucursalModel(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      direccion: data['direccion'] as String? ?? '',
      telefono: data['telefono'] as String? ?? '',
      imagenUrl: data['imagenUrl'] as String? ?? '',
      estado: data['estado'] as bool? ?? true,
      horarios: horarios.isEmpty ? horariosPorDefecto() : horarios,
    );
  }
}
