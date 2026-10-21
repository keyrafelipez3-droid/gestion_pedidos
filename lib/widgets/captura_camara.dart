import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../theme/design_tokens.dart';

/// Abre la cámara dentro de la app (pensado para el navegador, donde el
/// selector de archivos no puede usar la cámara web) y devuelve los bytes
/// JPG de la foto tomada, o null si la persona cancela.
///
/// El navegador pide permiso para usar la cámara la primera vez. Funciona
/// en `localhost` y en sitios con https (requisito de los navegadores).
Future<Uint8List?> capturarConCamara(BuildContext context, {bool frontal = false}) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCamara(frontal: frontal),
  );
}

class _DialogoCamara extends StatefulWidget {
  final bool frontal;
  const _DialogoCamara({required this.frontal});

  @override
  State<_DialogoCamara> createState() => _DialogoCamaraState();
}

class _DialogoCamaraState extends State<_DialogoCamara> {
  CameraController? _ctrl;
  List<CameraDescription> _camaras = const [];
  int _indice = 0;
  String? _error;
  bool _tomando = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      final camaras = await availableCameras();
      if (!mounted) return;
      if (camaras.isEmpty) {
        setState(() => _error = tr('No se encontró ninguna cámara en este dispositivo.'));
        return;
      }
      final preferida = widget.frontal ? CameraLensDirection.front : CameraLensDirection.back;
      final i = camaras.indexWhere((c) => c.lensDirection == preferida);
      _camaras = camaras;
      _indice = i >= 0 ? i : 0;
      await _abrir();
    } on CameraException catch (e) {
      _mostrarError(e);
    } catch (_) {
      if (mounted) setState(() => _error = tr('No se pudo acceder a la cámara.'));
    }
  }

  Future<void> _abrir() async {
    final anterior = _ctrl;
    if (mounted) setState(() => _ctrl = null);
    await anterior?.dispose();

    final ctrl = CameraController(
      _camaras[_indice],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await ctrl.initialize();
    } on CameraException catch (e) {
      await ctrl.dispose();
      _mostrarError(e);
      return;
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    setState(() {
      _ctrl = ctrl;
      _error = null;
    });
  }

  void _mostrarError(CameraException e) {
    if (!mounted) return;
    final codigo = e.code.toLowerCase();
    final sinPermiso = codigo.contains('denied') ||
        codigo.contains('permission') ||
        codigo.contains('notallowed');
    setState(() {
      _error = sinPermiso
          ? tr('No se dio permiso para usar la cámara. Actívalo en el navegador (ícono de la cámara en la barra de direcciones) o en los ajustes del dispositivo, y vuelve a intentarlo.')
          : tr('No se pudo abrir la cámara. Revisa que no la esté usando otra aplicación e inténtalo de nuevo.');
    });
  }

  Future<void> _cambiarCamara() async {
    if (_camaras.length < 2) return;
    _indice = (_indice + 1) % _camaras.length;
    await _abrir();
  }

  Future<void> _capturar() async {
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized || _tomando) return;
    setState(() => _tomando = true);
    try {
      final foto = await ctrl.takePicture();
      final bytes = await foto.readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tomando = false;
        _error = tr('No se pudo tomar la foto. Inténtalo de nuevo.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctrl = _ctrl;

    Widget vista;
    if (_error != null) {
      vista = Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.no_photography_outlined, color: scheme.error),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(_error!)),
          ],
        ),
      );
    } else if (ctrl == null || !ctrl.value.isInitialized) {
      vista = const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      vista = ClipRRect(
        borderRadius: AppRadius.mdAll,
        child: AspectRatio(
          aspectRatio: ctrl.value.aspectRatio,
          child: CameraPreview(ctrl),
        ),
      );
    }

    return AlertDialog(
      title: Text(tr('Tomar foto')),
      content: SizedBox(width: 480, child: vista),
      actions: [
        TextButton(
          onPressed: _tomando ? null : () => Navigator.of(context).pop(),
          child: Text(tr('Cancelar')),
        ),
        if (_camaras.length > 1 && _error == null)
          IconButton(
            tooltip: tr('Cambiar de cámara'),
            onPressed: _tomando || ctrl == null ? null : _cambiarCamara,
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        if (_error != null)
          OutlinedButton(
            onPressed: () {
              setState(() => _error = null);
              _iniciar();
            },
            child: Text(tr('Reintentar')),
          )
        else
          FilledButton.icon(
            onPressed: _tomando || ctrl == null ? null : _capturar,
            icon: _tomando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.photo_camera_outlined),
            label: Text(tr('Capturar')),
          ),
      ],
    );
  }
}
