import 'package:flutter/foundation.dart';

import '../models/usuario_model.dart';
import 'app_theme_controller.dart';
import 'auth_service.dart';

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

  /// Carga (o recarga) el usuario logueado desde Firestore. Se llama una
  /// sola vez al entrar a HomeScreen; `obtener()` reutiliza el valor ya
  /// cargado si existe.
  Future<void> cargar() async {
    final u = await AuthService.instancia.obtenerUsuarioActual();
    usuario.value = u;
    if (u?.idNegocio != null) {
      await AppThemeController.instancia.cargar(idNegocio: u!.idNegocio);
    } else {
      AppThemeController.instancia.limpiar();
    }
  }

  /// Devuelve el usuario ya cargado, o lo carga si todavía no se hizo
  /// (ej. al entrar directo a una pantalla sin pasar por HomeScreen).
  Future<UsuarioModel?> obtener() async {
    if (usuario.value == null) {
      await cargar();
    }
    return usuario.value;
  }

  /// Se llama al cerrar sesión, para que la próxima persona que inicie
  /// sesión en el mismo dispositivo no vea datos ni tema de la anterior.
  void limpiar() {
    usuario.value = null;
    AppThemeController.instancia.limpiar();
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
