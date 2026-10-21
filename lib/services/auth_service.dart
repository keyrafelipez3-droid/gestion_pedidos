import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';
import '../models/pedido_models.dart';
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

      // Se guarda también qué versión de los términos aceptó y cuándo
      // (prueba del consentimiento al registrarse).
      final datos = nuevoUsuario.toMap()
        ..['terminosVersion'] = AppConfig.versionTerminos
        ..['terminosAceptadosEn'] = FieldValue.serverTimestamp();
      await _db.collection('usuarios').doc(uid).set(datos);

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
      final credencial = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Una cuenta desactivada no puede usar la app: se cierra la sesión
      // de inmediato y se avisa. (Antes entraba igual y solo fallaban
      // algunas operaciones.)
      final uid = credencial.user?.uid;
      if (uid != null) {
        final doc = await _db.collection('usuarios').doc(uid).get();
        if (doc.exists && doc.data()?['estado'] == false) {
          await _auth.signOut();
          return 'Tu cuenta está desactivada. Contacta al administrador.';
        }
      }
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

  /// Elimina la cuenta de un Cliente (requisito de Google Play y Apple).
  ///
  /// - Pide la contraseña actual (reautenticación).
  /// - No deja eliminar si hay pedidos en curso.
  /// - Borra perfil, direcciones, favoritos y carrito.
  /// - Los pedidos pasados se conservan SIN el identificador del cliente
  ///   ni su dirección (el negocio los necesita para contabilidad y
  ///   reclamos), y en la ficha del negocio se borran su nombre y teléfono.
  /// - Las imágenes en Cloudinary no se pueden borrar desde la app (ver la
  ///   política de privacidad).
  /// Las cuentas del personal las administra el Administrador del negocio.
  Future<String?> eliminarCuenta({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      return 'No hay una sesión activa.';
    }
    try {
      final uid = user.uid;
      final doc = await _db.collection('usuarios').doc(uid).get();
      if (doc.data()?['rol'] != Rol.cliente) {
        return 'Las cuentas del personal las administra el Administrador de tu negocio.';
      }

      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );

      final pedidos =
          await _db.collection('pedidos').where('idCliente', isEqualTo: uid).get();
      final hayEnCurso = pedidos.docs.any((d) {
        final estado = d.data()['estado'];
        return estado != PedidoEstado.entregado && estado != PedidoEstado.cancelado;
      });
      if (hayEnCurso) {
        return 'Tienes pedidos en curso. Espera a que se entreguen o cancélalos '
            'antes de eliminar tu cuenta.';
      }

      // 0) Reseñas escritas por el cliente: se borran (el id de la reseña
      // es el del pedido).
      for (final p in pedidos.docs) {
        final idNegocio = p.data()['idNegocio'];
        if (idNegocio is! String) continue;
        final ref =
            _db.collection('negocios').doc(idNegocio).collection('resenas').doc(p.id);
        try {
          final existente = await ref.get();
          if (existente.exists) await ref.delete();
        } catch (_) {
          // Si no se puede leer o borrar una reseña, se sigue con el resto.
        }
      }

      // 1) Pedidos pasados: se quita el identificador y la dirección.
      final negocios = <String>{};
      var batch = _db.batch();
      var operaciones = 0;
      for (final p in pedidos.docs) {
        final idNegocio = p.data()['idNegocio'];
        if (idNegocio is String) negocios.add(idNegocio);
        batch.update(p.reference, {
          'idCliente': 'cuenta-eliminada',
          'direccionEntrega': null,
          'nombreCliente': null,
          'telefonoCliente': null,
        });
        if (++operaciones == 400) {
          await batch.commit();
          batch = _db.batch();
          operaciones = 0;
        }
      }
      if (operaciones > 0) await batch.commit();

      // 2) Ficha del cliente en cada negocio donde pidió: sin nombre ni teléfono.
      for (final idNegocio in negocios) {
        try {
          await _db
              .collection('negocios')
              .doc(idNegocio)
              .collection('clientes')
              .doc(uid)
              .update({'nombre': 'Cuenta eliminada', 'telefono': ''});
        } catch (_) {
          // Si el negocio no tenía ficha de este cliente, no hay nada que limpiar.
        }
      }

      // 3) Datos propios de la cuenta.
      for (final sub in ['carritoItems', 'direcciones', 'favoritos', 'notificaciones']) {
        final qs = await _db.collection('usuarios').doc(uid).collection(sub).get();
        var b = _db.batch();
        var n = 0;
        for (final d in qs.docs) {
          b.delete(d.reference);
          if (++n == 400) {
            await b.commit();
            b = _db.batch();
            n = 0;
          }
        }
        if (n > 0) await b.commit();
      }
      await _db.collection('usuarios').doc(uid).delete();

      // 4) Por último, la cuenta de acceso.
      await user.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'No se pudo eliminar la cuenta. Intenta de nuevo o escribe a '
          '${AppConfig.correoPrivacidad}.';
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
