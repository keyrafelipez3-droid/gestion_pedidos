import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/app_config.dart';
import '../../l10n/idioma.dart';
import '../../services/geocodificacion_service.dart';
import '../../services/ubicacion_service.dart';
import '../../theme/design_tokens.dart';

/// Lo que devuelve el selector: el punto marcado y, si se pudo obtener,
/// una dirección aproximada para sugerirla al usuario.
class UbicacionElegida {
  final LatLng punto;
  final String? direccionSugerida;
  const UbicacionElegida(this.punto, this.direccionSugerida);
}

/// Pantalla para marcar la dirección de entrega en un mapa: el pin queda
/// fijo en el centro y el usuario mueve el mapa; también puede usar su
/// ubicación actual o buscar una dirección por texto.
class SelectorUbicacionScreen extends StatefulWidget {
  final LatLng? inicial;

  const SelectorUbicacionScreen({super.key, this.inicial});

  @override
  State<SelectorUbicacionScreen> createState() => _SelectorUbicacionScreenState();
}

class _SelectorUbicacionScreenState extends State<SelectorUbicacionScreen> {
  final _mapa = MapController();
  final _busquedaCtrl = TextEditingController();

  late LatLng _centro;
  List<LugarEncontrado> _resultados = [];
  bool _buscando = false;
  bool _cargandoGps = false;
  bool _confirmando = false;
  String? _aviso;

  @override
  void initState() {
    super.initState();
    _centro = widget.inicial ??
        const LatLng(AppConfig.mapaLatInicial, AppConfig.mapaLngInicial);
    // Si no hay un punto de partida, se intenta centrar en el usuario.
    if (widget.inicial == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _irAMiUbicacion(silencioso: true));
    }
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _mapa.dispose();
    super.dispose();
  }

  void _moverA(LatLng punto, {double zoom = 17}) {
    _centro = punto;
    _mapa.move(punto, zoom);
  }

  Future<void> _irAMiUbicacion({bool silencioso = false}) async {
    setState(() {
      _cargandoGps = true;
      _aviso = null;
    });
    try {
      final punto = await UbicacionService.instancia.obtenerPosicionActual();
      if (!mounted) return;
      _moverA(punto);
    } on UbicacionException catch (e) {
      if (mounted && !silencioso) setState(() => _aviso = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoGps = false);
    }
  }

  Future<void> _buscar() async {
    final texto = _busquedaCtrl.text.trim();
    if (texto.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _buscando = true;
      _aviso = null;
      _resultados = [];
    });
    try {
      final lugares = await GeocodificacionService.instancia.buscar(texto);
      if (!mounted) return;
      setState(() {
        _resultados = lugares;
        if (lugares.isEmpty) {
          _aviso = tr('No encontramos esa dirección. Prueba con otra o mueve el mapa.');
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _aviso = tr('No se pudo buscar ahora. Mueve el mapa para marcar el punto.'));
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _confirmar() async {
    setState(() => _confirmando = true);
    final punto = _centro;
    final direccion = await GeocodificacionService.instancia.direccionDe(punto);
    if (!mounted) return;
    Navigator.of(context).pop(UbicacionElegida(punto, direccion));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Marca tu ubicación'))),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapa,
                  options: MapOptions(
                    initialCenter: _centro,
                    initialZoom: widget.inicial == null ? 14 : 17,
                    minZoom: 3,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onPositionChanged: (camara, _) => _centro = camara.center,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: AppConfig.mapaTilesUrl,
                      userAgentPackageName: AppConfig.mapaUserAgent,
                    ),
                    RichAttributionWidget(
                      attributions: [TextSourceAttribution(AppConfig.mapaAtribucion)],
                    ),
                  ],
                ),
                // Pin fijo en el centro: la punta queda justo en el punto elegido.
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -22),
                      child: Icon(Icons.location_on, size: 48, color: scheme.error),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        elevation: 3,
                        borderRadius: BorderRadius.circular(28),
                        color: scheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.md),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _busquedaCtrl,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => _buscar(),
                                  decoration: InputDecoration(
                                    hintText: tr('Buscar calle, zona o lugar'),
                                    border: InputBorder.none,
                                    filled: false,
                                  ),
                                ),
                              ),
                              _buscando
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    )
                                  : IconButton(
                                      tooltip: tr('Buscar'),
                                      icon: const Icon(Icons.search),
                                      onPressed: _buscar,
                                    ),
                            ],
                          ),
                        ),
                      ),
                      if (_resultados.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: AppSpacing.xs),
                          constraints: const BoxConstraints(maxHeight: 220),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _resultados.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final r = _resultados[i];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.place_outlined),
                                title: Text(r.nombre, maxLines: 2, overflow: TextOverflow.ellipsis),
                                onTap: () {
                                  setState(() => _resultados = []);
                                  _moverA(r.punto);
                                },
                              );
                            },
                          ),
                        ),
                      if (_aviso != null)
                        Container(
                          margin: const EdgeInsets.only(top: AppSpacing.xs),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _aviso!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: FloatingActionButton.small(
                    heroTag: 'mi-ubicacion',
                    tooltip: tr('Usar mi ubicación'),
                    onPressed: _cargandoGps ? null : () => _irAMiUbicacion(),
                    child: _cargandoGps
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    tr('Mueve el mapa hasta dejar el pin en la puerta de tu domicilio.'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _confirmando ? null : _confirmar,
                    icon: _confirmando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(tr('Confirmar ubicación')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
