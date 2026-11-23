import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/permisos_negocio.dart';
import '../models/usuario_model.dart';
import '../utils/navegacion.dart';
import 'app_theme_controller.dart';
import 'auth_service.dart';
import 'pedido_service.dart';
import 'permisos_service.dart';

/// Guarda en memoria el `UsuarioModel` de quien tiene la sesión abierta,
/// para que cualquier pantalla del panel (Sucursales, Catálogo,
/// Empleados, etc.) sepa su rol y su `idNegocio` sin repetir un
/// FutureBuilder cada vez. Se agregó junto con la corrección pedida por el
/// docente (SuperAdmin / multi-tenant): ahora casi toda pantalla de
/// operación necesita saber a qué negocio pertenece el Administrador
/// logueado para filtrar sus datos.
///
/// También dispara la carga del tema del negocio correspondiente
/// (`AppThemeController`): un Administrador/empleado ve el tema de SU
/// negocio; un SuperAdmin (no tiene uno fijo, gestiona todos) ve el tema
/// por defecto de la app.
class SesionActual {
  SesionActual._();
  static final instancia = SesionActual._();

  final ValueNotifier<UsuarioModel?> usuario = ValueNotifier(null);

  /// Permisos ajustables del negocio (para mostrar u ocultar botones; el
  /// servidor los vuelve a comprobar).
  PermisosNegocio permisos = PermisosNegocio.porDefecto;

  /// Carga (o recarga) el usuario logueado desde Firestore. Se llama una
  /// sola vez al entrar a HomeScreen; `obtener()` reutiliza el valor ya
  /// cargado si existe.
  Future<void> cargar() async {
    final u = await AuthService.instancia.obtenerUsuarioActual();
    if (u != null && !u.estado) {
      // Cuenta desactivada mientras tenía la sesión abierta.
      await AuthService.instancia.cerrarSesion();
      limpiar();
      return;
    }
    usuario.value = u;
    if (u != null) _vigilar(u);
    // El panel del personal se muestra siempre en español.
    IdiomaController.instancia.soloEspanol(u != null && !u.esCliente);
    if (u?.idNegocio != null) {
      try {
        permisos = await PermisosService.instancia.leer(u!.idNegocio!);
      } catch (_) {
        permisos = PermisosNegocio.porDefecto;
      }
      await AppThemeController.instancia.cargar(idNegocio: u!.idNegocio);
    } else {
      AppThemeController.instancia.limpiar();
    }
  }

  /// Devuelve el usuario ya cargado, o lo carga si todavía no se hizo
  /// (ej. al entrar directo a una pantalla sin pasar por HomeScreen).
  Future<UsuarioModel?> obtener() async {
    // Si quedó en memoria el usuario de otra sesión (por ejemplo, la sesión
    // se cerró sin pasar por "Cerrar sesión"), se vuelve a cargar.
    final uid = AuthService.instancia.usuarioActualAuth?.uid;
    if (usuario.value == null || usuario.value!.idUsuario != uid) {
      await cargar();
    }
    return usuario.value;
  }

  /// Se llama al cerrar sesión, para que la próxima persona que inicie
  /// sesión en el mismo dispositivo no vea datos ni tema de la anterior.
  void limpiar() {
    _vigilancia?.cancel();
    _vigilancia = null;
    usuario.value = null;
    PedidoService.olvidarDatosLeidos();
    permisos = PermisosNegocio.porDefecto;
    IdiomaController.instancia.soloEspanol(false);
    AppThemeController.instancia.limpiar();
  }

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vigilancia;

  /// Escucha el documento del usuario mientras tiene la sesión abierta. Si
  /// el Administrador lo da de baja o le cambia el rol, el negocio o la
  /// sucursal, la sesión se cierra al momento (no espera a que vuelva a
  /// entrar). Otros cambios (nombre, firma del acuerdo) se actualizan solos.
  void _vigilar(UsuarioModel u) {
    _vigilancia?.cancel();
    _vigilancia = FirebaseFirestore.instance
        .collection('usuarios')
        .doc(u.idUsuario)
        .snapshots()
        .listen((doc) {
      final actual = usuario.value;
      // Un documento borrado es la propia eliminación de la cuenta: de eso
      // se encarga Mi cuenta.
      if (actual == null || actual.idUsuario != doc.id || !doc.exists) return;
      // Solo cuenta lo que confirma el servidor (la copia guardada en el
      // dispositivo puede ser de antes).
      if (doc.metadata.isFromCache) return;
      final nuevo = UsuarioModel.fromSnapshot(doc);
      if (!nuevo.estado) {
        _cerrarSesion(tr('Tu cuenta fue desactivada. Consulta con el administrador.'));
      } else if (!actual.esCliente &&
          (nuevo.rol != actual.rol ||
              nuevo.idNegocio != actual.idNegocio ||
              nuevo.idSucursal != actual.idSucursal)) {
        _cerrarSesion(tr('Cambiaron los permisos de tu cuenta. Vuelve a iniciar sesión.'));
      } else if (nuevo.rol == actual.rol) {
        // Un cliente cuya solicitud de negocio se aprobó pasa a
        // Administrador al tocar "Ir al panel" (vuelve a cargar la cuenta).
        usuario.value = nuevo;
      }
    }, onError: (_) {
      // Sin permiso o sin conexión: se sigue con lo que ya se cargó.
    });
  }

  Future<void> _cerrarSesion(String mensaje) async {
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    limpiar();
    await AuthService.instancia.cerrarSesion();
    mensajesKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensaje)));
  }

  UsuarioModel? get actual => usuario.value;
  bool get esSuperAdmin => actual?.esSuperAdmin ?? false;
  bool get esAdministrador => actual?.esAdministrador ?? false;
  String? get idNegocio => actual?.idNegocio;
  // Sprint 2 (Cajero/Cocina): su sucursal asignada, para que sus
  // pantallas (mesas, pedidos) no tengan que volver a consultar
  // Firestore solo para saber dónde trabajan.
  String? get idSucursal => actual?.idSucursal;
  bool get esCajero => actual?.rol == Rol.cajero;
  bool get esCocina => actual?.rol == Rol.cocina;
  bool get esCliente => actual?.esCliente ?? false;
}
