import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/idioma.dart';
import '../services/traduccion_service.dart';
import '../theme/design_tokens.dart';

/// Muestra un texto que escribió el cliente (nota, referencia) traducido
/// al idioma de quien lo lee, con el original debajo. Si el cliente usó el
/// mismo idioma, lo muestra tal cual. Si la traducción automática falla,
/// queda el original y un enlace para abrirlo en Google Traductor.
class TextoTraducido extends StatefulWidget {
  final String texto;
  final String idiomaOrigen;
  final String etiqueta; // "Nota", "Referencia"...
  final IconData icono;
  final bool destacado;

  const TextoTraducido({
    super.key,
    required this.texto,
    required this.idiomaOrigen,
    required this.etiqueta,
    this.icono = Icons.sticky_note_2_outlined,
    this.destacado = false,
  });

  @override
  State<TextoTraducido> createState() => _TextoTraducidoState();
}

class _TextoTraducidoState extends State<TextoTraducido> {
  Future<String?>? _traduccion;

  String get _destino => IdiomaController.instancia.codigo.value;
  bool get _hayQueTraducir =>
      widget.idiomaOrigen.isNotEmpty && widget.idiomaOrigen != _destino && widget.texto.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _pedir();
  }

  @override
  void didUpdateWidget(covariant TextoTraducido oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.texto != widget.texto || oldWidget.idiomaOrigen != widget.idiomaOrigen) _pedir();
  }

  void _pedir() {
    _traduccion = _hayQueTraducir
        ? TraduccionService.instancia.traducir(widget.texto, desde: widget.idiomaOrigen, hacia: _destino)
        : null;
  }

  Future<void> _abrirGoogle() async {
    final uri = TraduccionService.enlaceGoogle(widget.texto, desde: widget.idiomaOrigen, hacia: _destino);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final estiloPrincipal = (widget.destacado ? textos.bodyLarge : textos.bodyMedium)
        ?.copyWith(fontWeight: widget.destacado ? FontWeight.w700 : FontWeight.w500);
    final estiloSecundario = textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    Widget envolver(Widget contenido) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(widget.icono, size: 18, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: contenido),
            ],
          ),
        );

    if (_traduccion == null) {
      return envolver(Text('${widget.etiqueta}: ${widget.texto}', style: estiloPrincipal));
    }
    final idioma = tr(TraduccionService.nombresIdioma[widget.idiomaOrigen] ?? widget.idiomaOrigen);
    return envolver(
      FutureBuilder<String?>(
        future: _traduccion,
        builder: (context, s) {
          final cargando = s.connectionState != ConnectionState.done;
          final traducido = s.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (traducido != null) ...[
                Text('${widget.etiqueta}: $traducido', style: estiloPrincipal),
                Text(
                  tr('Traducido automáticamente del {idioma}. Original: "{texto}"',
                      {'idioma': idioma, 'texto': widget.texto}),
                  style: estiloSecundario,
                ),
              ] else ...[
                Text('${widget.etiqueta} ($idioma): ${widget.texto}', style: estiloPrincipal),
                Text(
                  cargando ? tr('Traduciendo…') : tr('No se pudo traducir automáticamente.'),
                  style: estiloSecundario,
                ),
              ],
              if (!cargando)
                Wrap(
                  spacing: AppSpacing.xs,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _abrirGoogle,
                      icon: const Icon(Icons.g_translate, size: 16),
                      label: Text(tr('Ver en Google Traductor')),
                    ),
                    if (traducido == null)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () => setState(_pedir),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(tr('Reintentar')),
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
