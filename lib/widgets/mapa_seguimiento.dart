import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../theme/design_tokens.dart';

/// Mapa de seguimiento de un pedido en camino: muestra el lugar de entrega
/// y, cuando se conoce, la posición en vivo del repartidor.
class MapaSeguimiento extends StatefulWidget {
  final LatLng? destino;
  final LatLng? repartidor;
  final DateTime? actualizado;

  const MapaSeguimiento({
    super.key,
    this.destino,
    this.repartidor,
    this.actualizado,
  });

  @override
  State<MapaSeguimiento> createState() => _MapaSeguimientoState();
}

class _MapaSeguimientoState extends State<MapaSeguimiento> {
  final _mapa = MapController();

  List<LatLng> get _puntos => [
        if (widget.destino != null) widget.destino!,
        if (widget.repartidor != null) widget.repartidor!,
      ];

  @override
  void dispose() {
    _mapa.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapaSeguimiento anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.repartidor != widget.repartidor || anterior.destino != widget.destino) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ajustar());
    }
  }

  void _ajustar() {
    final puntos = _puntos;
    if (!mounted || puntos.isEmpty) return;
    try {
      if (puntos.length == 1) {
        _mapa.move(puntos.first, 16);
      } else {
        _mapa.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(puntos),
            padding: const EdgeInsets.all(56),
            maxZoom: 17,
          ),
        );
      }
    } catch (_) {
      // El mapa todavía no está listo: se ajusta en la próxima actualización.
    }
  }

  String _hora(DateTime t) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(t.hour)}:${dos(t.minute)}:${dos(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final puntos = _puntos;
    final scheme = Theme.of(context).colorScheme;
    if (puntos.isEmpty) {
      return const Text('Esperando la ubicación del repartidor…');
    }

    final opciones = puntos.length == 1
        ? MapOptions(
            initialCenter: puntos.first,
            initialZoom: 16,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          )
        : MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(puntos),
              padding: const EdgeInsets.all(56),
              maxZoom: 17,
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: FlutterMap(
              mapController: _mapa,
              options: opciones,
              children: [
                TileLayer(
                  urlTemplate: AppConfig.mapaTilesUrl,
                  userAgentPackageName: AppConfig.mapaUserAgent,
                ),
                MarkerLayer(
                  markers: [
                    if (widget.destino != null)
                      Marker(
                        point: widget.destino!,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: Icon(Icons.location_on, size: 44, color: scheme.error),
                      ),
                    if (widget.repartidor != null)
                      Marker(
                        point: widget.repartidor!,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
                          ),
                          child: Icon(Icons.two_wheeler, color: scheme.onPrimary, size: 22),
                        ),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [TextSourceAttribution(AppConfig.mapaAtribucion)],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          widget.repartidor == null
              ? 'Esperando la ubicación del repartidor…'
              : (widget.actualizado == null
                  ? 'Ubicación del repartidor en vivo'
                  : 'Ubicación actualizada a las ${_hora(widget.actualizado!)}'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
