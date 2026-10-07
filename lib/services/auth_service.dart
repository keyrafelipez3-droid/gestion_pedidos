import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario_model.dart';

/// Encapsula toda la lógica de Firebase Authentication + el documento
/// correspondiente en la colección `usuarios` de Firestore.
///
/// Cada método público devuelve `null` si todo salió bien, o un mensaje de
/// error en español listo para mostrar en pantalla (ej. en un SnackBar).
///
/// Nota: la creación de EMPLEADOS por parte de un Administrador (HU-05) vive
/// en un servicio aparte (admin_service.dart) porque necesita una app de
/// Firebase secundaria para no cerrar la sesión del administrador — se
/// implementa cuando se aborde esa historia.
class AuthService {
  AuthService._();
  static final AuthService instancia = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Emite el usuario de Firebase Auth actual (o null si no hay sesión).
  /// Úsalo para saber en tiempo real si hay alguien logueado.
  Stream<User?> get cambiosDeSesion => _auth.authStateChanges();

  User? get usuarioActualAuth => _auth.currentUser;

  /// Trae el documento de Firestore (nombre, rol, etc.) del usuario logueado.
  Future<UsuarioModel?> obtenerUsuarioActual() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    return UsuarioModel.fromSnapshot(doc);
  }

  /// HU-01 — Registro de un nuevo Cliente.
  /// Crea el usuario en Firebase Authentication y su documento en
  /// `usuarios/{uid}` con rol = Cliente.
  /// Devuelve null si funcionó, o un mensaje de error si no.
  Future<String?> registrarCliente({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
  }) async {
    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credencial.user!.uid;

      final nuevoUsuario = UsuarioModel(
        idUsuario: uid,
        nombre: nombre.trim(),
        email: email.trim(),
        telefono: telefono.trim(),
        rol: Rol.cliente,
        estado: true,
      );

      await _db.collection('usuarios').doc(uid).set(nuevoUsuario.toMap());

      // Nombre visible en Firebase Auth (opcional, útil para depurar en la consola).
      await credencial.user!.updateDisplayName(nombre.trim());

      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  /// HU-02 — Inicio de sesión.
  Future<String?> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  Future<void> cerrarSesion() => _auth.signOut();

  /// HU-06 — Modificar nombre y teléfono del propio usuario logueado
  /// (cualquier rol: Cliente, Administrador, Cajero, Cocina, Repartidor).
  /// Usa update() en vez de set(toMap()) para no pisar campos que no se
  /// están editando aquí (rol, estado, fechaRegistro, etc.).
  Future<String?> actualizarPerfil({
    required String nombre,
    required String telefono,
    String? fotoPerfil,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'No hay una sesión activa.';
    try {
      await _db.collection('usuarios').doc(uid).update({
        'nombre': nombre.trim(),
        'telefono': telefono.trim(),
        // fotoPerfil es opcional: si no se pasa (pantallas que todavía no
        // la editan) no se toca el campo ya guardado.
        if (fotoPerfil != null) 'fotoPerfil': fotoPerfil.trim(),
      });
      // Mantiene el nombre visible de Firebase Auth sincronizado (igual que
      // en el registro), aunque el dato "real" vive en Firestore.
      await _auth.currentUser?.updateDisplayName(nombre.trim());
      return null;
    } catch (e) {
      return 'No se pudo actualizar el perfil. Intenta de nuevo.';
    }
  }

  /// HU-06 — Activar/desactivar las notificaciones del usuario.
  Future<String?> actualizarNotificaciones(bool activas) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 'No hay una sesión activa.';
    try {
      await _db.collection('usuarios').doc(uid).update({
        'notificacionesActivas': activas,
      });
      return null;
    } catch (e) {
      return 'No se pudo guardar la preferencia. Intenta de nuevo.';
    }
  }

  /// HU-06 — Cambiar la contraseña del usuario logueado.
  /// Firebase exige "reautenticar" (volver a confirmar la contraseña
  /// actual) antes de permitir cambiarla, por seguridad: si el usuario dejó
  /// la sesión abierta en un dispositivo y alguien más la usa, no puede
  /// cambiar la contraseña sin saber la actual.
  Future<String?> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'No hay una sesión activa.';
    }
    try {
      final credencial = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordActual,
      );
      await user.reauthenticateWithCredential(credencial);
      await user.updatePassword(passwordNueva);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Ocurrió un error inesperado. Intenta de nuevo.';
    }
  }

  /// Traduce los códigos de error de Firebase Auth a mensajes en español.
  String _mensajeError(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo ingresado no es válido.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'user-not-found':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Correo o contraseña incorrectos.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada. Contacta al administrador.';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento y vuelve a intentar.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión e intenta de nuevo.';
      default:
        return 'Error de autenticación ($codigo).';
    }
  }
}
