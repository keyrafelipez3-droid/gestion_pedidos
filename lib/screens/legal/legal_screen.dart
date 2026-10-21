import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../legal/textos_legales.dart';
import '../../theme/design_tokens.dart';

enum TipoTextoLegal { politicaPrivacidad, terminos }

/// Muestra la política de privacidad o los términos y condiciones.
/// Se abre desde el registro, el inicio de sesión y "Mi cuenta".
class LegalScreen extends StatelessWidget {
  final TipoTextoLegal tipo;
  const LegalScreen({super.key, required this.tipo});

  @override
  Widget build(BuildContext context) {
    final esPolitica = tipo == TipoTextoLegal.politicaPrivacidad;
    final titulo =
        esPolitica ? TextosLegales.tituloPolitica : TextosLegales.tituloTerminos;
    final secciones =
        esPolitica ? TextosLegales.politicaPrivacidad() : TextosLegales.terminos();
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (AppConfig.mostrarAvisoDatosPendientes) ...[
                  Card(
                    color: scheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Aviso (solo en modo desarrollo): faltan datos de la '
                        'plataforma en lib/config/app_config.dart. Los textos '
                        'muestran marcadores "[COMPLETAR ...]".',
                        style: textos.bodyMedium
                            ?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(titulo, style: textos.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Versión ${AppConfig.versionTerminos}',
                  style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final s in secciones) ...[
                  Text(s.titulo, style: textos.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  for (final p in s.parrafos) ...[
                    Text(p, style: textos.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
