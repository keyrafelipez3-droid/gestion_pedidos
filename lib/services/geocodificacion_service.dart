import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';

/// Resultado de buscar una dirección.
class LugarEncontrado {
  final String nombre;
  final LatLng punto;
  const LugarEncontrado(this.nombre, this.punto);
}

/// Búsqueda de direcciones y "dirección a partir de un punto" usando el
/// servicio configurado en [AppConfig.geocodificadorUrl] (por defecto
/// Nominatim de OpenStreetMap). Se usa SOLO cuando el usuario toca un botón
/// (nunca mientras escribe), como exige la política de uso del servicio
/// público. Para producción conviene un proveedor comercial.
class GeocodificacionService {
  GeocodificacionService._();
  static final instancia = GeocodificacionService._();

  Map<String, String> get _cabeceras => {
        'Accept-Language': 'es',
        // En web el navegador no permite fijar este encabezado.
        if (!kIsWeb) 'User-Agent': AppConfig.mapaUserAgent,
      };

  Future<List<LugarEncontrado>> buscar(String texto) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) return [];
    final uri = Uri.parse('${AppConfig.geocodificadorUrl}/search').replace(
      queryParameters: {
        'q': consulta,
        'format': 'jsonv2',
        'limit': '6',
        if (AppConfig.paisBusqueda.isNotEmpty) 'countrycodes': AppConfig.paisBusqueda,
      },
    );
    final resp =
        await http.get(uri, headers: _cabeceras).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('El buscador no respondió (${resp.statusCode}).');
    }
    final datos = jsonDecode(resp.body) as List<dynamic>;
    final lugares = <LugarEncontrado>[];
    for (final d in datos) {
      final m = d as Map<String, dynamic>;
      final lat = double.tryParse('${m['lat']}');
      final lon = double.tryParse('${m['lon']}');
      if (lat == null || lon == null) continue;
      lugares.add(LugarEncontrado('${m['display_name'] ?? ''}', LatLng(lat, lon)));
    }
    return lugares;
  }

  /// Dirección aproximada de un punto, o null si no se pudo obtener.
  Future<String?> direccionDe(LatLng punto) async {
    try {
      final uri = Uri.parse('${AppConfig.geocodificadorUrl}/reverse').replace(
        queryParameters: {
          'lat': '${punto.latitude}',
          'lon': '${punto.longitude}',
          'format': 'jsonv2',
          'zoom': '18',
        },
      );
      final resp =
          await http.get(uri, headers: _cabeceras).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final m = jsonDecode(resp.body) as Map<String, dynamic>;
      final nombre = m['display_name'] as String?;
      return (nombre == null || nombre.trim().isEmpty) ? null : nombre.trim();
    } catch (_) {
      return null;
    }
  }
}
