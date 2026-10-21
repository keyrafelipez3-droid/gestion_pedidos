import 'package:cloud_firestore/cloud_firestore.dart';

import 'alergenos.dart';

/// Roles válidos del sistema (deben coincidir exactamente con los strings
/// usados en las reglas de seguridad de Firestore: rolDe(uid) / tieneRol([...])).
///
/// SuperAdmin (requisito del docente, corrección post-defensa Sprint 1):
/// es el único rol que personaliza TODOS los negocios (crea negocios,
/// asigna/edita su Personalización y Datos del negocio) y designa a los
/// Administradores de cada uno. Un Administrador ya NO personaliza el
/// negocio: solo gestiona la operación (sucursales, catálogo, empleados,
/// clientes) del negocio al que fue asignado (ver `idNegocio` abajo).
class Rol {
  static const String superAdmin = 'SuperAdmin';
  static const String cliente = 'Cliente';
  static const String administrador = 'Administrador';
  static const String cajero = 'Cajero';
  static const String cocina = 'Cocina';
  static const String repartidor = 'Repartidor';

  /// Roles de personal de UN negocio (todo lo que no es Cliente ni
  /// SuperAdmin) — todos quedan vinculados a un `idNegocio`.
  static const List<String> staff = [
    administrador,
    cajero,
    cocina,
    repartidor,
  ];

  /// Personal operativo que un Administrador SÍ puede crear/reasignar
  /// directamente (sin pasar por el SuperAdmin). Designar o reasignar a
  /// un Administrador es exclusivo del SuperAdmin — ver
  /// `crear_empleado_screen.dart` y `empleados_screen.dart`.
  static const List<String> staffOperativo = [
    cajero,
    cocina,
    repartidor,
  ];

  static const List<String> todos = [
    superAdmin,
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
  // Negocio al que pertenece este usuario — todo el personal de un negocio
  // (Administrador, Cajero, Cocina, Repartidor) tiene el mismo idNegocio.
  // El SuperAdmin no pertenece a ningún negocio en particular (null),
  // porque gestiona todos. Se agregó para el requisito de multi-tenant.
  final String? idNegocio;
  final bool estado; // activo / inactivo
  final DateTime? fechaRegistro;
  // HU-06: preferencia de notificaciones del propio usuario. No forma parte
  // del esquema original documentado en diseno-base-de-datos.md (que solo
  // define la subcolección usuarios/{id}/notificaciones para el historial
  // de notificaciones en sí), pero es el campo natural para guardar si el
  // usuario quiere recibirlas o no. Por defecto activo.
  final bool notificacionesActivas;

  /// Alergias del cliente (códigos de `Alergenos`). Se marcan solas en
  /// cada pedido nuevo para que la cocina las vea.
  final List<String> alergias;

  const UsuarioModel({
    required this.idUsuario,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rol,
    this.fotoPerfil = '',
    this.idSucursal,
    this.idNegocio,
    this.estado = true,
    this.fechaRegistro,
    this.notificacionesActivas = true,
    this.alergias = const [],
  });

  /// Copia con otras alergias (para actualizar la sesión sin recargar).
  UsuarioModel conAlergias(List<String> nuevas) => UsuarioModel(
        idUsuario: idUsuario,
        nombre: nombre,
        email: email,
        telefono: telefono,
        rol: rol,
        fotoPerfil: fotoPerfil,
        idSucursal: idSucursal,
        idNegocio: idNegocio,
        estado: estado,
        fechaRegistro: fechaRegistro,
        notificacionesActivas: notificacionesActivas,
        alergias: nuevas,
      );

  bool get esSuperAdmin => rol == Rol.superAdmin;
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
      'idNegocio': idNegocio,
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
      idNegocio: data['idNegocio'] as String?,
      estado: (data['estado'] ?? true) as bool,
      fechaRegistro: ts?.toDate(),
      notificacionesActivas: (data['notificacionesActivas'] ?? true) as bool,
      alergias: Alergenos.desdeFirestore(data['alergias']),
    );
  }

  factory UsuarioModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UsuarioModel.fromMap(doc.id, doc.data() ?? {});
  }
}
