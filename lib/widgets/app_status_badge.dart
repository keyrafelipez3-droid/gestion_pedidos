import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../theme/design_tokens.dart';

enum AppStatusTone { success, neutral, warning, danger }

/// Badge de estado reutilizable (ej. "Activa" / "Inactiva",
/// "Disponible" / "No disponible") — reemplaza los switches sueltos sin
/// indicador visual que había antes en varias listas.
class AppStatusBadge extends StatelessWidget {
  final String label;
  final AppStatusTone tone;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final scheme = Theme.of(context).colorScheme;
    late final Color fg;
    late final Color bg;
    switch (tone) {
      case AppStatusTone.success:
        fg = semantic.success;
        bg = semantic.success.withValues(alpha: 0.14);
        break;
      case AppStatusTone.warning:
        fg = semantic.warning;
        bg = semantic.warning.withValues(alpha: 0.16);
        break;
      case AppStatusTone.danger:
        fg = scheme.error;
        bg = scheme.errorContainer;
        break;
      case AppStatusTone.neutral:
        fg = scheme.onSurfaceVariant;
        bg = scheme.surfaceContainerHighest;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            tr(label),
            style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
