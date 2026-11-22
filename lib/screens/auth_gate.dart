import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/pantalla_carga.dart';
import 'auth/login_screen.dart';
import 'home_screen.dart';

/// Punto de entrada de la app después de Firebase.initializeApp().
/// Escucha el estado de sesión de Firebase Auth y decide qué mostrar:
/// - Sin sesión  -> LoginScreen (HU-02)
/// - Con sesión  -> HomeScreen (carga el documento usuarios/{uid})
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instancia.cambiosDeSesion,
      builder: (context, snapshot) {
        final Widget pantalla;
        if (snapshot.connectionState == ConnectionState.waiting) {
          pantalla = const KeyedSubtree(key: ValueKey('carga'), child: PantallaCarga());
        } else if (snapshot.data != null) {
          pantalla = const KeyedSubtree(key: ValueKey('inicio'), child: HomeScreen());
        } else {
          pantalla = const KeyedSubtree(key: ValueKey('login'), child: LoginScreen());
        }

        // Cambio suave (desvanecido) al iniciar o cerrar sesión.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: pantalla,
        );
      },
    );
  }
}
