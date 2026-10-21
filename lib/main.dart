import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/negocio_model.dart';
import 'screens/auth_gate.dart';
import 'services/app_theme_controller.dart';
import 'theme/design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Corrección pedida por el docente (multi-tenant): ya no hay un negocio
  // único que cargar al arrancar — el tema de cada Administrador/empleado
  // se carga recién al iniciar sesión (ver SesionActual.cargar()), según
  // a qué negocio pertenezca. Antes de eso se usa el tema por defecto.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NegocioModel?>(
      valueListenable: AppThemeController.instancia.negocio,
      builder: (context, negocio, _) {
        return MaterialApp(
          title: negocio?.nombre.isNotEmpty == true
              ? negocio!.nombre
              : AppBrand.nombre,
          debugShowCheckedModeBanner: false,
          theme: AppThemeController.instancia.buildTheme(Brightness.light),
          // HU-10 (Fase 5): "Modo" (claro/oscuro) es una preferencia del
          // negocio, guardada junto con el resto de la personalización.
          darkTheme: AppThemeController.instancia.buildTheme(Brightness.dark),
          themeMode: negocio?.modoOscuro == true ? ThemeMode.dark : ThemeMode.light,
          home: const AuthGate(),
        );
      },
    );
  }
}
