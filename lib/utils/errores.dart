import 'package:cloud_firestore/cloud_firestore.dart';

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
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'No tienes permiso para hacer esto. Puede que otra persona '
            'ya haya cambiado el pedido; revisa e intenta de nuevo.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'No hay conexión con el servidor. Revisa tu internet e intenta de nuevo.';
      case 'aborted':
      case 'failed-precondition':
        return 'El pedido cambió mientras lo actualizabas. Revisa e intenta de nuevo.';
      case 'not-found':
        return 'El pedido ya no existe.';
    }
  }
  final texto = e.toString();
  // Mensajes propios del código (Exception('...')): se muestran sin el prefijo.
  if (e is Exception && texto.startsWith('Exception: ')) {
    return texto.substring('Exception: '.length);
  }
  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}
