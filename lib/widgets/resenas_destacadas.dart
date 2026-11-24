import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/resena_model.dart';
import '../services/resena_service.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';
import 'estrellas.dart';

/// "Lo que dicen nuestros clientes": las mejores reseñas visibles de los
/// restaurantes de la plataforma, en la pantalla de inicio de sesión. Se
/// leen una sola vez. Si no hay reseñas o no se pueden leer, no se muestra
/// nada (el inicio de sesión nunca depende de esto).
class ResenasDestacadas extends StatefulWidget {
  const ResenasDestacadas({super.key});

  @override
  State<ResenasDestacadas> createState() => _ResenasDestacadasState();
}

class _ResenasDestacadasState extends State<ResenasDestacadas> {
  late final Future<List<ResenaModel>> _resenas = ResenaService.instancia.destacadasPublicas();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ResenaModel>>(
      future: _resenas,
      builder: (context, snap) {
        final lista = snap.data ?? const <ResenaModel>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        final textos = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Lo que dicen nuestros clientes'),
                textAlign: TextAlign.center,
                style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final r in lista) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: context.brand.decoracionTarjeta(scheme),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Estrellas(valor: r.calificacion.toDouble(), tamano: 18),
                      const SizedBox(height: AppSpacing.sm),
                      // El comentario completo, sin cortarlo.
                      Text('“${r.comentario.trim()}”', style: textos.bodyMedium),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        r.nombreCliente.trim().isEmpty ? tr('Cliente') : r.nombreCliente.trim(),
                        style: textos.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        );
      },
    );
  }
}
