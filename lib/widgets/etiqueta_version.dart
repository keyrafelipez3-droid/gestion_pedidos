import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/version_service.dart';

/// "Caro v1.0.0 (1)" en letra pequeña. Sirve para saber qué versión tiene
/// cada persona cuando reporta un problema.
class EtiquetaVersion extends StatelessWidget {
  final TextAlign textAlign;
  const EtiquetaVersion({super.key, this.textAlign = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: VersionService.instancia.etiqueta(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        return Text(
          '${AppConfig.nombrePlataforma} ${snap.data}',
          textAlign: textAlign,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        );
      },
    );
  }
}
