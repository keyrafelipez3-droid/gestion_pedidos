import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'sesion_actual.dart';
import 'version_service.dart';

/// Guarda en Firestore (`erroresApp`) los errores inesperados que ocurren
/// en el celular o en el navegador de los usuarios, para poder
/// corregirlos. Lo ve el SuperAdmin en "Errores de la app".
///
/// No guarda datos personales: solo el mensaje técnico, dónde ocurrió, la
/// versión y el rol de quien lo tuvo. Máximo 10 por sesión y sin repetir
/// el mismo error.
class RegistroErrores {
  RegistroErrores._();

  static int _enviados = 0;
  static final _vistos = <int>{};
  static const maxPorSesion = 10;

  /// Se llama una vez al iniciar la app.
  static void iniciar() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalles) {
      if (anterior != null) {
        anterior(detalles);
      } else {
        FlutterError.presentError(detalles);
      }
      registrar(detalles.exception, detalles.stack, contexto: detalles.context?.toString());
    };
    PlatformDispatcher.instance.onError = (error, pila) {
      registrar(error, pila);
      return true;
    };
  }

  static Future<void> registrar(Object error, StackTrace? pila, {String? contexto}) async {
    // En desarrollo los errores ya se ven en la consola.
    if (kDebugMode) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final mensaje = error.toString();
      if (_enviados >= maxPorSesion || !_vistos.add(mensaje.hashCode)) return;
      _enviados++;
      final usuario = SesionActual.instancia.actual;
      await FirebaseFirestore.instance.collection('erroresApp').add({
        ...datosDelError(
          mensaje: mensaje,
          pila: pila?.toString() ?? '',
          contexto: contexto ?? '',
          plataforma: kIsWeb ? 'web' : defaultTargetPlatform.name,
          version: await VersionService.instancia.etiqueta(),
          idUsuario: uid,
          rol: usuario?.rol ?? '',
          idNegocio: usuario?.idNegocio ?? '',
        ),
        'fecha': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Si no se puede guardar el error, no se hace nada más.
    }
  }
}

/// Datos que se guardan de un error, recortados a un tamaño razonable.
Map<String, dynamic> datosDelError({
  required String mensaje,
  required String pila,
  required String contexto,
  required String plataforma,
  required String version,
  required String idUsuario,
  required String rol,
  required String idNegocio,
}) {
  String recortar(String s, int max) => s.length <= max ? s : s.substring(0, max);
  return {
    'mensaje': recortar(mensaje, 500),
    'pila': recortar(pila, 3000),
    'contexto': recortar(contexto, 300),
    'plataforma': recortar(plataforma, 20),
    'version': recortar(version, 30),
    'idUsuario': idUsuario,
    'rol': recortar(rol, 30),
    'idNegocio': recortar(idNegocio, 60),
  };
}
