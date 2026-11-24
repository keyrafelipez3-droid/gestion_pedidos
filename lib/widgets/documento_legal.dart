import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../legal/textos_legales.dart';
import '../theme/design_tokens.dart';

/// Muestra un documento legal en su forma formal: título, versión y las
/// cláusulas (PRIMERA.-, SEGUNDA.-…) con el texto justificado, igual que la
/// versión para imprimir y firmar. [resumen] y los "En simple" de cada
/// cláusula ya no se muestran (decisión: formal en todo); se conservan en
/// los textos por si se quieren volver a usar.
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
        Text(titulo.toUpperCase(), style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (subtitulo != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(subtitulo!, style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
        // Los textos legales están solo en español (es la versión que vale).
        if (IdiomaController.instancia.codigo.value != 'es') ...[
          const SizedBox(height: AppSpacing.sm),
          Text(tr('Este documento está disponible solo en español, que es la versión válida.'),
              style: textos.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: AppSpacing.lg),
        for (final s in secciones) ...[
          Text(s.titulo, style: textos.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: AppSpacing.xs),
          for (final p in s.parrafos) ...[
            Text(p, style: textos.bodyMedium?.copyWith(height: 1.5), textAlign: TextAlign.justify),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
