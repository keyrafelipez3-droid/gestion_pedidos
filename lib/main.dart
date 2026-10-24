import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config/app_config.dart';
import 'firebase_options.dart';
import 'l10n/idioma.dart';
import 'models/negocio_model.dart';
import 'screens/auth_gate.dart';
import 'services/app_theme_controller.dart';
import 'theme/design_tokens.dart';
import 'utils/navegacion.dart';
import 'widgets/aviso_actualizacion.dart';
import 'widgets/vigilante_inactividad.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await _activarAppCheck();
  // Corrección pedida por el docente (multi-tenant): ya no hay un negocio
  // único que cargar al arrancar — el tema de cada Administrador/empleado
  // se carga recién al iniciar sesión (ver SesionActual.cargar()), según
  // a qué negocio pertenezca. Antes de eso se usa el tema por defecto.
  await IdiomaController.instancia.cargar();
  runApp(const MyApp());
}

/// App Check: Firebase solo acepta pedidos de la app real (no de scripts
/// o bots que copien la configuración). Se activa cuando hay clave
/// configurada en AppConfig (ver "Claude outputs/SEGURIDAD.md"). Mientras
/// no se active la "aplicación forzosa" en la consola, no bloquea nada.
Future<void> _activarAppCheck() async {
  try {
    if (kIsWeb) {
      if (AppConfig.appCheckClaveWeb.isEmpty) return;
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(AppConfig.appCheckClaveWeb),
      );
    } else if (defaultTargetPlatform == TargetPlatform.android && AppConfig.appCheckAndroid) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    }
  } catch (_) {
    // Si App Check falla al iniciar, la app sigue funcionando.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Al cambiar de idioma se cambia el `locale` (textos de Material como
    // calendarios y botones) y IdiomaController vuelve a dibujar toda la
    // app con los textos traducidos, sin perder la pantalla actual.
    return ValueListenableBuilder<String>(
      valueListenable: IdiomaController.instancia.codigo,
      builder: (context, idioma, _) => ValueListenableBuilder<NegocioModel?>(
      valueListenable: AppThemeController.instancia.negocio,
      builder: (context, negocio, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: mensajesKey,
          // Cierra la sesión del personal tras 20 minutos sin uso.
          builder: (context, child) => VigilanteInactividad(
            child: AvisoActualizacion(child: child ?? const SizedBox.shrink()),
          ),
          locale: Locale(idioma),
          supportedLocales: Idioma.locales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
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
      ),
    );
  }
}
