import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/negocio_model.dart';
import 'screens/auth_gate.dart';
import 'services/app_theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AppThemeController.instancia.cargar();
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
              : 'Gestión de Pedidos',
          debugShowCheckedModeBanner: false,
          theme: AppThemeController.instancia.buildTheme(Brightness.light),
          home: const AuthGate(),
        );
      },
    );
  }
}
