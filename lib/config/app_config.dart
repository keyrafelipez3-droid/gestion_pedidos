import 'package:flutter/foundation.dart';

/// Datos de la PLATAFORMA (quien ofrece la app a los negocios). Los datos
/// de cada NEGOCIO (razón social, NIT, contacto, dirección) los ingresa su
/// propio Administrador en "Datos del negocio" y se muestran en la ficha
/// del negocio; no van aquí.
///
/// IMPORTANTE antes de publicar la app: completar los campos marcados con
/// "[COMPLETAR ...]". Los textos legales (política de privacidad y
/// términos) los muestran tal cual, y un abogado en Bolivia debe
/// revisarlos antes de la venta.
class AppConfig {
  AppConfig._();

  static const String nombrePlataforma = 'Gestión de Pedidos';

  /// Subir esta versión cada vez que cambien los textos legales. Se guarda
  /// junto con la aceptación de cada usuario.
  static const String versionTerminos = '2026-10-21';

  /// Quién ofrece la plataforma (persona o empresa titular).
  static const String titularPlataforma =
      '[COMPLETAR: nombre legal del titular de la plataforma]';

  /// Correo para consultas de privacidad y solicitudes sobre datos.
  static const String correoPrivacidad = '[COMPLETAR: correo de privacidad]';

  static const String ciudadPais = 'Cochabamba, Bolivia';

  /// Dirección web pública (de la versión web desplegada) donde el
  /// usuario puede pedir la eliminación de su cuenta sin instalar la app.
  /// Google Play pide este enlace en el formulario "Seguridad de los
  /// datos". Vacío hasta que la web esté publicada.
  static const String urlEliminacionCuenta = '';

  /// true mientras falte completar algún dato de arriba.
  static bool get faltanDatos =>
      titularPlataforma.contains('[COMPLETAR') ||
      correoPrivacidad.contains('[COMPLETAR');

  /// Solo en modo desarrollo: avisa en pantalla que faltan datos.
  static bool get mostrarAvisoDatosPendientes => kDebugMode && faltanDatos;
}
