import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Tarjeta de métrica del dashboard: ícono, valor grande (ya formateado,
/// por ejemplo "Bs 120.50") y etiqueta. El valor viene de un stream real;
/// mientras llega se muestra "—", nunca un número inventado.
class AppMetricaCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String etiqueta;
  final String? valor;
  final String? detalle;

  const AppMetricaCard({
    super.key,
    required this.icon,
    required this.color,
    required this.etiqueta,
    required this.valor,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.normal,
      width: 200,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            child: Text(
              valor ?? '—',
              key: ValueKey(valor),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 2),
            Text(
              detalle!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
