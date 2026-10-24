import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/cliente_negocio_model.dart';
import '../models/usuario_model.dart';

/// Operaciones exclusivas del Administrador sobre la colección `usuarios`.
class AdminService {
  AdminService._();
  static final AdminService instancia = AdminService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// HU-05 — Crea la cuenta de un empleado (Administrador, Cajero, Cocina o
  /// Repartidor) y su documento en `usuarios/{uid}`.
  ///
  /// `createUserWithEmailAndPassword` inicia sesión automáticamente con la
  /// cuenta recién creada, lo que cerraría la sesión del administrador que
  /// está usando la app. Para evitarlo, se crea una app de Firebase
  /// SECUNDARIA y temporal solo para este registro, y se elimina apenas
  /// termina — la sesión del administrador (en la app principal) nunca se
  /// toca.
  ///
  /// Devuelve null si funcionó, o un mensaje de error en español si no.
  Future<String?> crearEmpleado({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
    required String rol,
    String? idSucursal,
    // Negocio al que queda asignado el empleado (multi-tenant). Para un
    // Administrador que crea a su propio personal, es su propio
    // idNegocio; para un SuperAdmin designando al Administrador de un
    // negocio nuevo, es el idNegocio de ESE negocio.
    String? idNegocio,
  }) async {
    FirebaseApp? appTemporal;
    try {
      appTemporal = await Firebase.initializeApp(
        name: 'appTemporalCrearEmpleado_${DateTime.now().microsecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final authTemporal = FirebaseAuth.instanceFor(app: appTemporal);

      final credencial = await authTemporal.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credencial.user!.uid;

      final nuevoEmpleado = UsuarioModel(
        idUsuario: uid,
        nombre: nombre.trim(),
        email: email.trim(),
        telefono: telefono.trim(),
        rol: rol,
        idSucursal: (idSucursal != null && idSucursal.trim().isNotEmpty)
            ? idSucursal.trim()
            : null,
        idNegocio: idNegocio,
        estado: true,
      );

      // Se escribe con la instancia principal de Firestore (no depende de
      // qué app de Auth esté logueada en ese momento).
      await _db.collection('usuarios').doc(uid).set(nuevoEmpleado.toMap());

      await authTemporal.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeError(e.code);
    } catch (e) {
      return 'Ocurrió un error inesperado creando el empleado.';
    } finally {
      // Limpieza: se borra la app secundaria para no dejarla acumulada.
      if (appTemporal != null) {
        await appTemporal.delete();
      }
    }
  }

  /// Lista en tiempo real de los empleados de UN negocio (cualquier rol
  /// distinto de Cliente), ordenados por nombre. Corrección pedida por el
  /// docente: antes era global; ahora cada Administrador solo ve el
  /// personal de su propio negocio. El filtro de rol y el orden se hacen
  /// en Dart (no en la consulta) para que el único `where` a Firestore
  /// sea una igualdad simple y no requiera crear un índice compuesto.
  Stream<List<UsuarioModel>> streamEmpleados(String idNegocio) {
    return _db
        .collection('usuarios')
        .where('idNegocio', isEqualTo: idNegocio)
        .snapshots()
        .map((qs) => qs.docs
            .map(UsuarioModel.fromSnapshot)
            .where((u) => Rol.staff.contains(u.rol))
            .toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));
  }

  /// Lista en tiempo real de TODOS los Administradores (de cualquier
  /// negocio) — solo para el dashboard del SuperAdmin.
  Stream<List<UsuarioModel>> streamAdministradores() {
    return _db
        .collection('usuarios')
        .where('rol', isEqualTo: Rol.administrador)
        .snapshots()
        .map((qs) => qs.docs.map(UsuarioModel.fromSnapshot).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));
  }

  /// Lista en tiempo real de los Administradores asignados a UN negocio
  /// — para el detalle de ese negocio en el panel del SuperAdmin.
  Stream<List<UsuarioModel>> streamAdministradoresDeNegocio(String idNegocio) {
    return _db
        .collection('usuarios')
        .where('idNegocio', isEqualTo: idNegocio)
        .snapshots()
        .map((qs) => qs.docs
            .map(UsuarioModel.fromSnapshot)
            .where((u) => u.rol == Rol.administrador)
            .toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));
  }

  /// Lista en tiempo real de TODOS los Clientes de la plataforma. Solo el
  /// SuperAdmin puede leerlos (las reglas lo exigen): un Administrador ve
  /// únicamente a los clientes de su propio negocio.
  Stream<List<UsuarioModel>> streamTodosLosClientes() {
    return _db
        .collection('usuarios')
        .where('rol', isEqualTo: Rol.cliente)
        .orderBy('nombre')
        .snapshots()
        .map((qs) => qs.docs.map(UsuarioModel.fromSnapshot).toList());
  }

  /// HU-04 — Clientes de UN negocio: quienes ya hicieron al menos un
  /// pedido allí (se registran en `negocios/{id}/clientes` al confirmar
  /// su primer pedido).
  Stream<List<ClienteNegocioModel>> streamClientesDeNegocio(String idNegocio) {
    return _db
        .collection('negocios')
        .doc(idNegocio)
        .collection('clientes')
        .snapshots()
        .map((qs) => qs.docs.map(ClienteNegocioModel.fromSnapshot).toList()
          ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));
  }

  /// Clientes del negocio por partes (orden alfabético), para la lista.
  Stream<List<ClienteNegocioModel>> streamClientesPaginado(String idNegocio, int limite) => _db
      .collection('negocios')
      .doc(idNegocio)
      .collection('clientes')
      .orderBy('nombre')
      .limit(limite)
      .snapshots()
      .map((qs) => qs.docs.map(ClienteNegocioModel.fromSnapshot).toList());

  /// Bloquea o desbloquea a un cliente SOLO en este negocio. Un cliente
  /// bloqueado ya no puede hacer pedidos aquí; en los demás negocios sigue
  /// igual. Es reversible y no borra nada.
  Future<void> cambiarBloqueoCliente({
    required String idNegocio,
    required String idCliente,
    required bool bloqueado,
    String? motivo,
    required String idAdmin,
  }) {
    return _db
        .collection('negocios')
        .doc(idNegocio)
        .collection('clientes')
        .doc(idCliente)
        .update({
      'bloqueado': bloqueado,
      'motivoBloqueo': bloqueado ? (motivo ?? '') : FieldValue.delete(),
      'fechaBloqueo': bloqueado ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'idAdminBloqueo': bloqueado ? idAdmin : FieldValue.delete(),
    });
  }

  /// Activa / desactiva la cuenta de un empleado (no lo borra).
  Future<void> cambiarEstado(String idUsuario, bool estado) {
    return _db.collection('usuarios').doc(idUsuario).update({
      'estado': estado,
    });
  }

  /// Cambia el rol asignado a un empleado.
  Future<void> cambiarRol(String idUsuario, String nuevoRol) {
    return _db.collection('usuarios').doc(idUsuario).update({
      'rol': nuevoRol,
    });
  }

  String _mensajeError(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo ingresado no es válido.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con ese correo.';
      case 'weak-password':
      case 'password-does-not-meet-requirements':
        return 'La contraseña es muy débil: usa mínimo 8 caracteres con letras y números.';
      case 'network-request-failed':
        return 'Sin conexión a internet. Revisa tu red.';
      default:
        return 'Error creando la cuenta ($codigo).';
    }
  }
}
