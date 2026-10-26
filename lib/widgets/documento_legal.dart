import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../legal/textos_legales.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';

/// Muestra un documento legal fácil de leer: primero "En resumen" (lo
/// esencial en pocas líneas), y en cada sección una línea "En simple"
/// antes del texto completo.
class VistaDocumentoLegal extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<String> resumen;
  final List<SeccionLegal> secciones;

  const VistaDocumentoLegal({
    super.key,
    required this.titulo,
    required this.resumen,
    required this.secciones,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: textos.headlineSmall),
        if (subtitulo != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitulo!, style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        if (resumen.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: context.brand.card,
              border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('En resumen'),
                    style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.sm),
                for (final r in resumen)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs + 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_outline, size: 18, color: scheme.primary),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(r, style: textos.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final s in secciones) ...[
          Text(s.titulo, style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          if (s.enSimple != null) ...[
            Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '${tr('En simple')}: ',
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.primary),
                ),
                TextSpan(text: s.enSimple),
              ]),
              style: textos.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          for (final p in s.parrafos) ...[
            Text(p, style: textos.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
