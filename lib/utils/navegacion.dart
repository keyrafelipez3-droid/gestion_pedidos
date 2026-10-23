import 'package:flutter/material.dart';

/// Acceso al Navigator y a los mensajes (SnackBar) desde fuera de una
/// pantalla, por ejemplo para cerrar la sesión por inactividad.
final navigatorKey = GlobalKey<NavigatorState>();
final mensajesKey = GlobalKey<ScaffoldMessengerState>();
