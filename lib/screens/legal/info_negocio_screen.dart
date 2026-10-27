import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/negocio_model.dart';
import '../../theme/design_tokens.dart';
import '../cliente/condiciones_restaurante_screen.dart';

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
        (Icons.business_outlined, tr('Razón social'), negocio.razonSocial),
      if (negocio.nit.isNotEmpty) (Icons.badge_outlined, negocio.datosPais.idFiscal, negocio.nit),
      if (negocio.direccion.isNotEmpty || negocio.ciudad.isNotEmpty)
        (
          Icons.place_outlined,
          tr('Dirección'),
          [negocio.direccion, negocio.ciudad].where((e) => e.isNotEmpty).join(', ')
        ),
      if (negocio.telefono.isNotEmpty)
        (Icons.phone_outlined, tr('Teléfono'), negocio.telefono),
      if (negocio.correoContacto.isNotEmpty)
        (Icons.email_outlined, tr('Correo de contacto'), negocio.correoContacto),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Información del negocio'))),
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
                    tr('Este negocio todavía no completó sus datos de contacto.'),
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
                Text(tr('¿Tienes un reclamo?'), style: textos.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr('Puedes presentarlo directamente a este negocio, de forma verbal o escrita y sin formalidades, usando los datos de contacto de arriba.'),
                  style: textos.bodyMedium,
                ),
                if (negocio.condiciones.contactoReclamos.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SelectableText(
                    '${tr('Contacto para reclamos')}: ${negocio.condiciones.contactoReclamos}',
                    style: textos.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.gavel_outlined),
                    title: Text(tr('Condiciones de {restaurante}', {'restaurante': negocio.nombre})),
                    subtitle: Text(tr('Pagos, entregas, devoluciones y reclamos')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => CondicionesRestauranteScreen(negocio: negocio, soloLectura: true),
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
