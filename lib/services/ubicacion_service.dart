import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Error con un mensaje listo para mostrar al usuario.
class UbicacionException implements Exception {
  final String mensaje;
  const UbicacionException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Acceso a la ubicación del dispositivo (GPS). Siempre pide permiso al
/// usuario y solo se llama cuando él lo pide o durante una entrega activa.
class UbicacionService {
  UbicacionService._();
  static final instancia = UbicacionService._();

  /// Verifica servicio y permisos. Lanza [UbicacionException] con un
  /// mensaje claro si no se puede usar la ubicación.
  Future<void> asegurarPermiso() async {
    final servicioActivo = await Geolocator.isLocationServiceEnabled();
    if (!servicioActivo) {
      throw const UbicacionException(
        'Activa la ubicación (GPS) de tu dispositivo e inténtalo de nuevo.',
      );
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      throw const UbicacionException(
        'No diste permiso de ubicación. Puedes marcar el punto moviendo el mapa.',
      );
    }
    if (permiso == LocationPermission.deniedForever) {
      throw const UbicacionException(
        'El permiso de ubicación está bloqueado. Actívalo en los ajustes del '
        'dispositivo o del navegador, o marca el punto moviendo el mapa.',
      );
    }
  }

  /// Posición actual del dispositivo.
  Future<LatLng> obtenerPosicionActual() async {
    await asegurarPermiso();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      throw const UbicacionException(
        'No se pudo obtener tu ubicación. Intenta de nuevo o marca el punto en el mapa.',
      );
    }
  }
}
