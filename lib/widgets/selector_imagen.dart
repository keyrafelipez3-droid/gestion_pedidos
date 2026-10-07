import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/storage_service.dart';
import '../theme/design_tokens.dart';

/// Selector de imagen reutilizable (Sprint 2, pedido del docente): en vez
/// de solo pegar un link a una imagen ya alojada en otro lugar, deja SUBIR
/// el archivo directamente (se guarda en Firebase Storage). El campo de
/// texto para pegar un link se mantiene como alternativa, por si alguien
/// ya tiene la imagen alojada en otro sitio.
///
/// [controller] es el mismo TextEditingController que ya tenía cada
/// pantalla para el campo "...Url" — este widget solo lo rellena con la
/// URL que devuelve Storage al subir, así que no cambia nada de cómo se
/// guarda ni se usa esa URL después.
///
/// [rutaStorage] debe ser estable para un mismo registro (ej.
/// `negocios/{idNegocio}/productos/{idProducto}`) para que subir una
/// imagen nueva reemplace la anterior en vez de acumular archivos sueltos.
class SelectorImagen extends StatefulWidget {
  final String etiqueta;
  final TextEditingController controller;
  final String rutaStorage;

  const SelectorImagen({
    super.key,
    required this.etiqueta,
    required this.controller,
    required this.rutaStorage,
  });

  @override
  State<SelectorImagen> createState() => _SelectorImagenState();
}

class _SelectorImagenState extends State<SelectorImagen> {
  bool _subiendo = false;
  String? _error;

  Future<void> _elegirYSubir() async {
    final ImagePicker picker = ImagePicker();
    XFile? archivo;
    try {
      archivo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo abrir el selector de archivos.');
      return;
    }
    if (archivo == null) return;

    setState(() {
      _subiendo = true;
      _error = null;
    });

    try {
      final bytes = await archivo.readAsBytes();
      final nombre = archivo.name.toLowerCase();
      final extension = nombre.contains('.') ? nombre.split('.').last : 'jpg';
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
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
        _error = 'No se pudo subir la imagen. Intenta de nuevo.';
      });
    }
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
                  OutlinedButton.icon(
                    onPressed: _subiendo ? null : _elegirYSubir,
                    icon: _subiendo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_outlined, size: 18),
                    label: Text(_subiendo ? 'Subiendo...' : 'Subir imagen'),
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
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'O pega un link',
                      // El link tiene que ser el archivo de imagen en sí
                      // (ej. termina en .jpg/.png), no la página que lo
                      // muestra — un link de Pinterest, Google Imágenes o
                      // Instagram apunta a una página, no a la imagen, y
                      // no se puede mostrar aquí.
                      helperText: 'Debe ser el link directo a la imagen, '
                          'no el de una página que la contiene',
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
