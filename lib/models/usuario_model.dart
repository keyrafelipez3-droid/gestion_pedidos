import 'package:cloud_firestore/cloud_firestore.dart';

/// Roles válidos del sistema (deben coincidir exactamente con los strings
/// usados en las reglas de seguridad de Firestore: rolDe(uid) / tieneRol([...])).
class Rol {
  static const String cliente = 'Cliente';
  static const String administrador = 'Administrador';
  static const String cajero = 'Cajero';
  static const String cocina = 'Cocina';
  static const String repartidor = 'Repartidor';

  /// Roles de personal del negocio (todo lo que no es Cliente).
  static const List<String> staff = [
    administrador,
    cajero,
    cocina,
    repartidor,
  ];

  static const List<String> todos = [
    cliente,
    administrador,
    cajero,
    cocina,
    repartidor,
  ];
}

/// Representa un documento de la colección `usuarios` (colección raíz de Firestore).
/// idUsuario = UID de Firebase Authentication (mismo id que el documento).
class UsuarioModel {
  final String idUsuario;
  final String nombre;
  final String email;
  final String telefono;
  final String rol;
  final String fotoPerfil;
  final String? idSucursal; // solo aplica a empleados (Cajero/Cocina/Repartidor)
  final bool estado; // activo / inactivo
  final DateTime? fechaRegistro;
  // HU-06: preferencia de notificaciones del propio usuario. No forma parte
  // del esquema original documentado en diseno-base-de-datos.md (que solo
  // define la subcolección usuarios/{id}/notificaciones para el historial
  // de notificaciones en sí), pero es el campo natural para guardar si el
  // usuario quiere recibirlas o no. Por defecto activo.
  final bool notificacionesActivas;

  const UsuarioModel({
    required this.idUsuario,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rol,
    this.fotoPerfil = '',
    this.idSucursal,
    this.estado = true,
    this.fechaRegistro,
    this.notificacionesActivas = true,
  });

  bool get esCliente => rol == Rol.cliente;
  bool get esAdministrador => rol == Rol.administrador;
  bool get esPersonalDelNegocio => Rol.staff.contains(rol);

  /// Datos a escribir en Firestore al crear el documento (registro).
  /// OJO: usa FieldValue.serverTimestamp() en fechaRegistro, así que este
  /// mapa es solo para CREAR el documento por primera vez — nunca para
  /// actualizar un usuario ya existente (eso pisaría su fecha de registro
  /// original). Para editar datos de un usuario ya creado, usar
  /// AuthService.actualizarPerfil()/actualizarNotificaciones(), que hacen
  /// update() solo de los campos que cambian.
  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'rol': rol,
      'fotoPerfil': fotoPerfil,
      'idSucursal': idSucursal,
      'estado': estado,
      'fechaRegistro': FieldValue.serverTimestamp(),
      'notificacionesActivas': notificacionesActivas,
    };
  }

  factory UsuarioModel.fromMap(String idUsuario, Map<String, dynamic> data) {
    final Timestamp? ts = data['fechaRegistro'] as Timestamp?;
    return UsuarioModel(
      idUsuario: idUsuario,
      nombre: (data['nombre'] ?? '') as String,
      email: (data['email'] ?? '') as String,
      telefono: (data['telefono'] ?? '') as String,
      rol: (data['rol'] ?? Rol.cliente) as String,
      fotoPerfil: (data['fotoPerfil'] ?? '') as String,
      idSucursal: data['idSucursal'] as String?,
      estado: (data['estado'] ?? true) as bool,
      fechaRegistro: ts?.toDate(),
      notificacionesActivas: (data['notificacionesActivas'] ?? true) as bool,
    );
  }

  factory UsuarioModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UsuarioModel.fromMap(doc.id, doc.data() ?? {});
  }
}
