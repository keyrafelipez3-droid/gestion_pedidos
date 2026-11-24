import 'package:flutter/material.dart';

import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';

/// Tarjeta de estadística del dashboard: ícono con insignia de color +
/// valor grande + etiqueta. El valor viene de un stream real (mismo
/// servicio que usa la pantalla completa de esa sección) — nunca de un
/// número inventado.
class AppStatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String etiqueta;
  final Stream<int> stream;

  /// Ancho fijo de la tarjeta; null = ocupa el ancho que le den (por
  /// ejemplo, dentro de una grilla que llena la fila).
  final double? ancho;

  const AppStatCard({
    super.key,
    required this.icon,
    required this.color,
    required this.etiqueta,
    required this.stream,
    this.ancho = 168,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: ancho,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: context.brand.decoracionTarjeta(scheme),
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) {
          final valor = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                valor == null ? '—' : '$valor',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }
}
