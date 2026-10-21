import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../theme/design_tokens.dart';

/// Ficha del negocio para el cliente: quién es, cómo contactarlo y cómo
/// reclamar. Los datos los ingresa el Administrador del negocio en "Datos
/// del negocio"; lo que no completó no se muestra.
class InfoNegocioScreen extends StatelessWidget {
  final NegocioModel negocio;
  const InfoNegocioScreen({super.key, required this.negocio});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final filas = <(IconData, String, String)>[
      if (negocio.razonSocial.isNotEmpty)
        (Icons.business_outlined, 'Razón social', negocio.razonSocial),
      if (negocio.nit.isNotEmpty) (Icons.badge_outlined, 'NIT', negocio.nit),
      if (negocio.direccion.isNotEmpty || negocio.ciudad.isNotEmpty)
        (
          Icons.place_outlined,
          'Dirección',
          [negocio.direccion, negocio.ciudad].where((e) => e.isNotEmpty).join(', ')
        ),
      if (negocio.telefono.isNotEmpty)
        (Icons.phone_outlined, 'Teléfono', negocio.telefono),
      if (negocio.correoContacto.isNotEmpty)
        (Icons.email_outlined, 'Correo de contacto', negocio.correoContacto),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Información del negocio')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(negocio.nombre, style: textos.headlineSmall),
                if (negocio.descripcion.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(negocio.descripcion, style: textos.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (filas.isEmpty)
                  Text(
                    'Este negocio todavía no completó sus datos de contacto.',
                    style: textos.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (final f in filas)
                          ListTile(
                            leading: Icon(f.$1),
                            title: Text(f.$2),
                            subtitle: SelectableText(f.$3),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Text('¿Tienes un reclamo?', style: textos.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Puedes presentarlo directamente a este negocio, de forma '
                  'verbal o escrita y sin formalidades, usando los datos de '
                  'contacto de arriba.',
                  style: textos.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
