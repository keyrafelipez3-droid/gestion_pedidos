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

/// Resultado de consultar si una sucursal está atendiendo en este momento.
class AperturaSucursal {
  final bool abierta;
  final String mensaje;
  const AperturaSucursal(this.abierta, this.mensaje);
}

int? _aMinutos(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

class SucursalModel {
  final String id;
  final String nombre;
  final String direccion;
  final String telefono;
  final String imagenUrl;
  final bool estado;
  final Map<String, HorarioDia> horarios;
  // Negocio al que pertenece esta sucursal (multi-tenant). Nullable solo
  // por compatibilidad con documentos antiguos de antes de la corrección
  // pedida por el docente; una sucursal nueva siempre lo trae.
  final String? idNegocio;

  const SucursalModel({
    required this.id,
    required this.nombre,
    this.direccion = '',
    this.telefono = '',
    this.imagenUrl = '',
    this.estado = true,
    this.horarios = const {},
    this.idNegocio,
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

  /// ¿Está atendiendo ahora? Usa la hora del dispositivo. Si el negocio
  /// nunca configuró horarios (ningún día activo), se considera abierta para
  /// no bloquear pedidos por un dato que simplemente no se cargó.
  /// Soporta horarios que cruzan la medianoche (ej. 18:00 a 02:00).
  AperturaSucursal estadoApertura([DateTime? ahora]) {
    final t = ahora ?? DateTime.now();
    if (!estado) return const AperturaSucursal(false, 'Esta sucursal no está disponible.');
    if (!horarios.values.any((h) => h.activo)) {
      return const AperturaSucursal(true, '');
    }
    final minAhora = t.hour * 60 + t.minute;
    final hoy = horarios[dias[t.weekday - 1]];
    if (hoy != null && hoy.activo) {
      final a = _aMinutos(hoy.apertura);
      final c = _aMinutos(hoy.cierre);
      if (a != null && c != null) {
        if (a < c && minAhora >= a && minAhora < c) {
          return AperturaSucursal(true, 'Abierto hasta las ${hoy.cierre}');
        }
        if (a > c && minAhora >= a) {
          return AperturaSucursal(true, 'Abierto hasta las ${hoy.cierre} (mañana)');
        }
      }
    }
    // Horario de ayer que cruza la medianoche y todavía sigue.
    final ayer = horarios[dias[(t.weekday + 5) % 7]];
    if (ayer != null && ayer.activo) {
      final a = _aMinutos(ayer.apertura);
      final c = _aMinutos(ayer.cierre);
      if (a != null && c != null && a > c && minAhora < c) {
        return AperturaSucursal(true, 'Abierto hasta las ${ayer.cierre}');
      }
    }
    // Cerrada: buscar la próxima apertura.
    if (hoy != null && hoy.activo) {
      final a = _aMinutos(hoy.apertura);
      if (a != null && minAhora < a) {
        return AperturaSucursal(false, 'Cerrado ahora. Abre hoy a las ${hoy.apertura}.');
      }
    }
    for (var i = 1; i <= 7; i++) {
      final dia = dias[(t.weekday - 1 + i) % 7];
      final h = horarios[dia];
      if (h != null && h.activo && _aMinutos(h.apertura) != null) {
        final cuando = i == 1 ? 'mañana' : 'el $dia';
        return AperturaSucursal(false, 'Cerrado ahora. Abre $cuando a las ${h.apertura}.');
      }
    }
    return const AperturaSucursal(false, 'Cerrado ahora.');
  }

  static Map<String, HorarioDia> horariosPorDefecto() => {
        for (final dia in dias) dia: const HorarioDia(),
      };

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'imagenUrl': imagenUrl,
        'estado': estado,
        'idNegocio': idNegocio,
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
      idNegocio: data['idNegocio'] as String?,
      horarios: horarios.isEmpty ? horariosPorDefecto() : horarios,
    );
  }
}
