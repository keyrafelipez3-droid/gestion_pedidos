/// Motivo obligatorio para acciones del Administrador que afectan a un
/// cliente: bloquearlo en el negocio u ocultar su reseña. Queda escrito
/// quién lo hizo, cuándo y por qué. Las reglas de Firestore exigen el
/// mismo largo (entre [motivoMinimo] y [motivoMaximo] letras).
const int motivoMinimo = 5;
const int motivoMaximo = 140;

/// Devuelve el error a mostrar, o null si el motivo es válido.
String? validarMotivo(String? motivo) {
  final t = (motivo ?? '').trim();
  if (t.isEmpty) return 'Escribe el motivo.';
  if (t.length < motivoMinimo) return 'El motivo debe tener al menos $motivoMinimo letras.';
  if (t.length > motivoMaximo) return 'El motivo puede tener hasta $motivoMaximo letras.';
  return null;
}

/// Error cuando se intenta bloquear u ocultar sin un motivo válido.
class MotivoInvalidoException implements Exception {
  final String mensaje;
  const MotivoInvalidoException(this.mensaje);
  @override
  String toString() => mensaje;
}

/// Lanza [MotivoInvalidoException] si el motivo no es válido; si lo es,
/// lo devuelve sin espacios al inicio ni al final.
String exigirMotivo(String? motivo) {
  final error = validarMotivo(motivo);
  if (error != null) throw MotivoInvalidoException(error);
  return motivo!.trim();
}
