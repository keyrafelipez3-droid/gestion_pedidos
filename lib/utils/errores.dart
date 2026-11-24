import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
import '../services/cupon_service.dart';
import '../services/registro_errores.dart';

/// Error "esperado" al cambiar el estado de un pedido (otro usuario ya lo
/// cambió, el pedido ya no existe, transición no permitida). El mensaje
/// está pensado para mostrarse tal cual a la persona.
class PedidoEstadoException implements Exception {
  final String mensaje;
  const PedidoEstadoException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Convierte cualquier error en un texto claro para mostrar en pantalla,
/// sin exponer códigos internos de Firebase.
String textoError(Object e) {
  if (e is PedidoEstadoException) return e.mensaje;
  if (e is CuponException) return e.mensaje;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return tr(
          'No tienes permiso para hacer esto. Puede que otra persona ya haya cambiado el pedido; revisa e intenta de nuevo.',
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return tr('No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.');
      case 'aborted':
      case 'failed-precondition':
        return tr('El pedido cambió mientras lo actualizabas. Revisa e intenta de nuevo.');
      case 'not-found':
        return tr('El pedido ya no existe.');
      case 'resource-exhausted':
        // Plan gratis de Firebase: se acabó la cuota del día (se renueva a
        // medianoche de California) o hay demasiadas solicitudes juntas.
        return tr('El servidor está ocupado en este momento. Espera un minuto e intenta de nuevo.');
      case 'unauthenticated':
        return tr('Tu sesión expiró. Vuelve a iniciar sesión.');
    }
  }
  final texto = e.toString();
  // Mensajes propios del código (Exception('...')): se muestran sin el prefijo.
  if (e is Exception && texto.startsWith('Exception: ')) {
    return texto.substring('Exception: '.length);
  }
  // Error que no esperábamos: se guarda (lo ve el SuperAdmin en "Errores
  // de la app") y se muestra el código para poder encontrar la causa.
  RegistroErrores.registrar(e, StackTrace.current, contexto: 'textoError');
  final codigo = e is FirebaseException ? e.code : e.runtimeType.toString();
  return '${tr('Ocurrió un error inesperado. Intenta de nuevo.')} ($codigo)';
}
