import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/actividad_model.dart';
import '../services/actividad_service.dart';
import '../services/auth_service.dart';
import '../models/usuario_model.dart';
import '../services/sesion_actual.dart';
import '../utils/navegacion.dart';

/// Cierra la sesión del PERSONAL después de [limite] sin tocar la app
/// (mouse, teclado o pantalla). Sirve sobre todo en la computadora de la
/// caja, que suele quedar sola. Un minuto antes avisa con la opción
/// "Seguir conectado". No se desconectan los clientes, ni la Cocina (su
/// tablero queda abierto en una tablet sin que nadie lo toque) ni el
/// Repartidor (maneja sin tocar el celular mientras comparte su ubicación).
class VigilanteInactividad extends StatefulWidget {
  final Widget child;
  final Duration limite;
  const VigilanteInactividad({
    super.key,
    required this.child,
    this.limite = const Duration(minutes: 20),
  });

  @override
  State<VigilanteInactividad> createState() => _VigilanteInactividadState();
}

class _VigilanteInactividadState extends State<VigilanteInactividad> with WidgetsBindingObserver {
  DateTime _ultimaActividad = DateTime.now();
  bool _avisado = false;
  Timer? _reloj;

  /// Mientras se está cerrando la sesión no se vuelve a revisar. Antes,
  /// si guardar el registro tardaba, se juntaban varios cierres y uno de
  /// ellos sacaba a la persona apenas volvía a entrar.
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_tecla);
    WidgetsBinding.instance.addObserver(this);
    _reloj = Timer.periodic(const Duration(seconds: 15), (_) => _revisar());
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_tecla);
    WidgetsBinding.instance.removeObserver(this);
    _reloj?.cancel();
    super.dispose();
  }

  /// En el celular, volver a abrir la app cuenta como actividad: el propio
  /// teléfono ya tiene su bloqueo, y no se corta la sesión apenas se abre.
  /// En la computadora de la caja (web) se sigue contando el tiempo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (!kIsWeb && estado == AppLifecycleState.resumed) _actividad();
  }

  bool _tecla(KeyEvent _) {
    _actividad();
    return false; // no consume la tecla
  }

  void _actividad() {
    _ultimaActividad = DateTime.now();
    if (_avisado) {
      _avisado = false;
      mensajesKey.currentState?.hideCurrentSnackBar();
    }
  }

  Future<void> _revisar() async {
    if (_cerrando) return;
    final u = SesionActual.instancia.actual;
    if (u == null || u.esCliente || u.rol == Rol.cocina || u.rol == Rol.repartidor) {
      _ultimaActividad = DateTime.now();
      return;
    }
    final inactivo = DateTime.now().difference(_ultimaActividad);
    if (inactivo >= widget.limite) {
      await _cerrarSesion();
    } else if (!_avisado && inactivo >= widget.limite - const Duration(minutes: 1)) {
      _avisado = true;
      mensajesKey.currentState?.showSnackBar(
        SnackBar(
          duration: const Duration(minutes: 1),
          content: const Text('Tu sesión se cerrará en 1 minuto por inactividad.'),
          action: SnackBarAction(label: 'SEGUIR CONECTADO', onPressed: _actividad),
        ),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    final u = SesionActual.instancia.actual;
    if (u == null) return;
    _cerrando = true;
    try {
      // El registro no puede demorar el cierre (sin conexión, la escritura
      // queda esperando): se espera como máximo 3 segundos.
      await ActividadService.instancia
          .registrar(
            ActividadTipo.sesion,
            'Sesión cerrada por inactividad (${widget.limite.inMinutes} min)',
          )
          .timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
    ActividadService.instancia.olvidarSesion(u.idUsuario);
    _cerrando = false;
    // Si mientras tanto la sesión ya cambió (cerró sesión, o entró otra
    // vez), no se cierra la nueva.
    if (AuthService.instancia.usuarioActualAuth?.uid != u.idUsuario) return;
    // Si en esos segundos la persona tocó la app, sigue conectada.
    if (DateTime.now().difference(_ultimaActividad) < widget.limite) return;
    _avisado = false;
    _ultimaActividad = DateTime.now();
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    SesionActual.instancia.limpiar();
    await AuthService.instancia.cerrarSesion();
    mensajesKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Cerramos tu sesión por inactividad. Vuelve a iniciar sesión.'),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _actividad(),
      onPointerMove: (_) => _actividad(),
      onPointerSignal: (_) => _actividad(),
      onPointerHover: (_) => _actividad(),
      child: widget.child,
    );
  }
}
