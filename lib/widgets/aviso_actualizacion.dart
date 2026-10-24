import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../l10n/idioma.dart';
import '../services/version_service.dart';
import '../utils/recarga.dart';

/// Avisa cuando hay una versión nueva de la app:
/// - "disponible": franja arriba con "Actualizar" (se puede posponer).
/// - "obligatoria": pantalla completa; la versión instalada ya no se usa.
/// En la web, "Actualizar" recarga la página (toma lo último desplegado).
/// En Android abre el enlace de descarga de la APK.
class AvisoActualizacion extends StatefulWidget {
  final Widget child;
  const AvisoActualizacion({super.key, required this.child});

  @override
  State<AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<AvisoActualizacion> {
  StreamSubscription<VersionPublicada?>? _sub;
  VersionPublicada? _publicada;
  int _instalado = 0;
  int? _pospuesta; // build que el usuario dejó "para más tarde"

  @override
  void initState() {
    super.initState();
    VersionService.instancia.buildInstalado().then((b) {
      if (mounted) setState(() => _instalado = b);
    }).catchError((_) {});
    _sub = VersionService.instancia.stream().listen((v) {
      if (mounted) setState(() => _publicada = v);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _actualizar() async {
    if (kIsWeb) {
      recargarPagina();
      return;
    }
    final url = _publicada?.urlApk ?? '';
    if (url.isEmpty) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final publicada = _publicada;
    final estado = estadoActualizacion(buildInstalado: _instalado, publicada: publicada);
    if (publicada == null || estado == EstadoActualizacion.alDia) return widget.child;

    final scheme = Theme.of(context).colorScheme;
    final textoBoton = kIsWeb ? tr('Recargar') : tr('Actualizar');
    // Sin enlace de descarga no se puede ofrecer el botón en el celular.
    final puedeActualizar = kIsWeb || publicada.urlApk.isNotEmpty;

    if (estado == EstadoActualizacion.obligatoria) {
      return Material(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.system_update, size: 64, color: scheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      tr('Actualización obligatoria'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('Esta versión de {app} ya no se puede usar. Instala la versión {version} para continuar.',
                          {'app': AppConfig.nombrePlataforma, 'version': publicada.version}),
                      textAlign: TextAlign.center,
                    ),
                    if (publicada.notas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(publicada.notas,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 24),
                    if (puedeActualizar)
                      FilledButton.icon(
                        onPressed: _actualizar,
                        icon: const Icon(Icons.download),
                        label: Text(textoBoton),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_pospuesta == publicada.build) return widget.child;

    return Column(
      children: [
        Material(
          color: scheme.primaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  Icon(Icons.system_update_alt, color: scheme.onPrimaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Hay una nueva versión de {app} ({version}).',
                          {'app': AppConfig.nombrePlataforma, 'version': publicada.version}),
                      style: TextStyle(color: scheme.onPrimaryContainer),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _pospuesta = publicada.build),
                    child: Text(tr('Más tarde')),
                  ),
                  if (puedeActualizar)
                    FilledButton(onPressed: _actualizar, child: Text(textoBoton)),
                ],
              ),
            ),
          ),
        ),
        // La franja ya ocupa el espacio de la barra de estado.
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
