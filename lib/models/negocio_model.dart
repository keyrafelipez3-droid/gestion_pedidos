/// Representa el documento único de la colección raíz `negocios`.
/// El sistema es para UN negocio (no multi-tenant), así que en la práctica
/// solo existe un documento en esta colección.
class NegocioModel {
  final String idNegocio;
  final String nombre;
  final String logoUrl;
  final String descripcion;
  final String telefono;
  final String colorPrimario; // hex, ej. "#E65100"
  final String colorSecundario; // hex, ej. "#FFF3E0"
  final bool estado;

  const NegocioModel({
    required this.idNegocio,
    required this.nombre,
    this.logoUrl = '',
    this.descripcion = '',
    this.telefono = '',
    this.colorPrimario = '#E65100',
    this.colorSecundario = '#FFF3E0',
    this.estado = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'logoUrl': logoUrl,
      'descripcion': descripcion,
      'telefono': telefono,
      'colorPrimario': colorPrimario,
      'colorSecundario': colorSecundario,
      'estado': estado,
    };
  }

  factory NegocioModel.fromMap(String idNegocio, Map<String, dynamic> data) {
    return NegocioModel(
      idNegocio: idNegocio,
      nombre: (data['nombre'] ?? '') as String,
      logoUrl: (data['logoUrl'] ?? '') as String,
      descripcion: (data['descripcion'] ?? '') as String,
      telefono: (data['telefono'] ?? '') as String,
      colorPrimario: (data['colorPrimario'] ?? '#E65100') as String,
      colorSecundario: (data['colorSecundario'] ?? '#FFF3E0') as String,
      estado: (data['estado'] ?? true) as bool,
    );
  }
}
