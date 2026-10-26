import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../l10n/idioma.dart';
import '../../legal/textos_legales.dart';
import '../../theme/design_tokens.dart';
import '../../utils/documento_imprimible.dart';
import '../../widgets/documento_legal.dart';

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
    final resumen = esPolitica ? TextosLegales.resumenPrivacidad() : TextosLegales.resumenTerminos();
    final version = tr('Versión {versionTerminos}', {'versionTerminos': AppConfig.versionTerminos});
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(titulo)),
        actions: [
          IconButton(
            tooltip: tr('Imprimir o guardar como PDF'),
            icon: const Icon(Icons.print_outlined),
            onPressed: () async {
              final ok = await imprimirDocumentoLegal(
                titulo: titulo,
                subtitulo: version,
                resumen: resumen,
                secciones: secciones,
              );
              if (!ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(tr('Para imprimir o guardar en PDF, abre la app en el navegador.')),
                ));
              }
            },
          ),
        ],
      ),
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
                        tr('Aviso (solo en modo desarrollo): faltan datos de la plataforma en lib/config/app_config.dart. Los textos muestran marcadores "[COMPLETAR ...]".'),
                        style: textos.bodyMedium
                            ?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (IdiomaController.instancia.codigo.value != 'es') ...[
                  Card(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.translate, color: scheme.onSecondaryContainer),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              tr('Este documento legal está disponible solo en español, que es la versión válida.'),
                              style: textos.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                VistaDocumentoLegal(
                  titulo: titulo,
                  subtitulo: version,
                  resumen: resumen,
                  secciones: secciones,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
