import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/idioma.dart';
import '../services/storage_service.dart';
import '../theme/design_tokens.dart';
import 'captura_camara.dart';

/// Selector de imagen reutilizable (Sprint 2, pedido del docente): en vez
/// de solo pegar un link a una imagen ya alojada en otro lugar, deja SUBIR
/// el archivo directamente o TOMAR UNA FOTO con la cámara. El campo de
/// texto para pegar un link se mantiene como alternativa, por si alguien
/// ya tiene la imagen alojada en otro sitio.
///
/// Cámara:
///  * Android / iOS: abre la cámara del teléfono.
///  * Navegador: abre una ventana con la vista de la cámara web (el
///    navegador pide permiso la primera vez).
///  * Windows / macOS / Linux de escritorio: no hay cámara compatible, así
///    que el botón no se muestra.
///
/// [controller] es el mismo TextEditingController que ya tenía cada
/// pantalla para el campo "...Url" — este widget solo lo rellena con la
/// URL que devuelve el servicio al subir, así que no cambia nada de cómo se
/// guarda ni se usa esa URL después.
///
/// [rutaStorage] debe ser estable para un mismo registro (ej.
/// `negocios/{idNegocio}/productos/{idProducto}`) para que subir una
/// imagen nueva reemplace la anterior en vez de acumular archivos sueltos.
class SelectorImagen extends StatefulWidget {
  final String etiqueta;
  final TextEditingController controller;
  final String rutaStorage;

  /// Muestra el botón "Tomar foto" (si el dispositivo tiene cámara compatible).
  final bool permitirCamara;

  /// Abre primero la cámara frontal (útil para la foto de perfil).
  final bool camaraFrontal;

  const SelectorImagen({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.rutaStorage,
    this.permitirCamara = true,
    this.camaraFrontal = false,
  });

  @override
  State<SelectorImagen> createState() => _SelectorImagenState();
}

class _SelectorImagenState extends State<SelectorImagen> {
  bool _subiendo = false;
  String? _error;

  /// Tamaño máximo de la foto: suficiente para verse bien y que suba rápido.
  static const double _ladoMaximo = 1600;

  bool get _camaraDisponible {
    if (!widget.permitirCamara) return false;
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _elegirDeGaleria() async {
    final picker = ImagePicker();
    XFile? archivo;
    try {
      archivo = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: _ladoMaximo,
        maxHeight: _ladoMaximo,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('No se pudo abrir el selector de archivos.'));
      return;
    }
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    await _subir(bytes, _tipoDesdeNombre(archivo.name));
  }

  Future<void> _tomarFoto() async {
    Uint8List? bytes;
    try {
      if (kIsWeb) {
        // En el navegador, el selector de archivos no usa la cámara web:
        // se abre la vista de la cámara dentro de la app.
        bytes = await capturarConCamara(context, frontal: widget.camaraFrontal);
      } else {
        final foto = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: widget.camaraFrontal ? CameraDevice.front : CameraDevice.rear,
          imageQuality: 85,
          maxWidth: _ladoMaximo,
          maxHeight: _ladoMaximo,
        );
        bytes = await foto?.readAsBytes();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = tr('No se pudo abrir la cámara. Revisa que la app tenga permiso.'));
      return;
    }
    if (bytes == null) return; // canceló
    await _subir(bytes, 'image/jpeg');
  }

  Future<void> _subir(Uint8List bytes, String contentType) async {
    if (!mounted) return;
    setState(() {
      _subiendo = true;
      _error = null;
    });
    try {
      final url = await StorageService.instancia.subirImagen(
        ruta: widget.rutaStorage,
        bytes: bytes,
        contentType: contentType,
      );
      if (!mounted) return;
      setState(() {
        widget.controller.text = url;
        _subiendo = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subiendo = false;
        _error = tr('No se pudo subir la imagen. Intenta de nuevo.');
      });
    }
  }

  String _tipoDesdeNombre(String nombreArchivo) {
    final nombre = nombreArchivo.toLowerCase();
    final extension = nombre.contains('.') ? nombre.split('.').last : 'jpg';
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final urlActual = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.etiqueta, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: Colors.black12),
                color: Colors.black.withValues(alpha: 0.03),
              ),
              child: urlActual.isEmpty
                  ? const Icon(Icons.image_outlined, color: Colors.black26)
                  : Image.network(
                      urlActual, webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_outlined, color: Colors.black26),
                    ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_subiendo)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        children: [
                          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          SizedBox(width: AppSpacing.sm),
                          Text(tr('Subiendo imagen...')),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _elegirDeGaleria,
                          icon: const Icon(Icons.upload_outlined, size: 18),
                          label: Text(tr('Subir imagen')),
                        ),
                        if (_camaraDisponible)
                          OutlinedButton.icon(
                            onPressed: _tomarFoto,
                            icon: const Icon(Icons.photo_camera_outlined, size: 18),
                            label: Text(tr('Tomar foto')),
                          ),
                      ],
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: widget.controller,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: tr('O pega un link'),
                      // El link tiene que ser el archivo de imagen en sí
                      // (ej. termina en .jpg/.png), no la página que lo
                      // muestra — un link de Pinterest, Google Imágenes o
                      // Instagram apunta a una página, no a la imagen, y
                      // no se puede mostrar aquí.
                      helperText: tr('Debe ser el link directo a la imagen, no el de una página que la contiene'),
                      helperMaxLines: 2,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
