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

  static const String nombrePlataforma = 'Caro';

  /// Subir esta versión cada vez que cambien los textos legales. Se guarda
  /// junto con la aceptación de cada usuario.
  static const String versionTerminos = '2026-10-22';

  /// Quién ofrece la plataforma (persona o empresa titular).
  static const String titularPlataforma =
      'Alaitz Keyra Felipez Ledezma y Susan Dilana Romero Valdez';

  /// Correo para consultas de privacidad y solicitudes sobre datos.
  static const String correoPrivacidad = 'keyrafelipez3@gmail.com';

  static const String ciudadPais = 'Cochabamba, Bolivia';

  // ------------------------------------------------------------------ mapas
  // Proveedor de mapa y de busqueda de direcciones. Por defecto usa los
  // servicios publicos de OpenStreetMap, que sirven para desarrollo y poco
  // trafico. ANTES DE VENDER la app hay que cambiarlos por un proveedor con
  // plan comercial (por ejemplo MapTiler, Stadia Maps o Geoapify): solo hay
  // que cambiar estas constantes. Politica de OSM:
  // https://operations.osmfoundation.org/policies/tiles/

  /// Plantilla de los mosaicos del mapa. Con un proveedor de pago suele
  /// llevar una clave: pegala aca.
  static const String mapaTilesUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Texto de atribucion que exige el proveedor del mapa.
  static const String mapaAtribucion = '© colaboradores de OpenStreetMap';

  /// Identificador de la app (el mismo applicationId de Android).
  static const String mapaUserAgent = 'com.univalle.gestion_pedidos';

  /// Servicio de busqueda de direcciones (geocodificacion).
  static const String geocodificadorUrl = 'https://nominatim.openstreetmap.org';

  /// Limita la busqueda a un pais (codigo ISO de 2 letras, minusculas).
  static const String paisBusqueda = 'bo';

  /// Centro inicial del mapa cuando no se conoce la ubicacion del usuario
  /// (Cochabamba).
  static const double mapaLatInicial = -17.3935;
  static const double mapaLngInicial = -66.1570;

  /// Traducción automática de las notas que escriben los clientes
  /// extranjeros (servicio gratuito MyMemory, sin clave).
  static const String traductorUrl = 'https://api.mymemory.translated.net/get';

  /// Opcional: un correo de contacto para MyMemory. Sin correo el límite
  /// gratuito es menor; con correo es más alto. Vacío = no se envía.
  static const String traductorCorreo = '';

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
