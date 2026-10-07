import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_imagen_red.dart';
import 'cliente_menu_screen.dart';

/// HU-16 (parte 1): el Cliente elige de qué negocio quiere ver el menú.
/// Es la puerta de entrada a todo el flujo de Cliente (menú → carrito →
/// checkout). Tarjetas grandes con foto, estilo apps de delivery.
class ClienteNegociosScreen extends StatelessWidget {
  const ClienteNegociosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedir ahora')),
      body: StreamBuilder<List<NegocioModel>>(
        stream: NegocioService.instancia.streamNegocios(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final negocios = snapshot.data!.where((n) => n.estado).toList();
          if (negocios.isEmpty) {
            return const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Todavía no hay negocios disponibles',
              message: 'Vuelve a intentarlo más tarde.',
            );
          }
          return AppContenidoCentrado(
            maxWidth: 1100,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '¿Dónde quieres pedir hoy?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.lg,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      mainAxisExtent: 224,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _TarjetaNegocio(negocio: negocios[i]),
                      childCount: negocios.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaNegocio extends StatelessWidget {
  final NegocioModel negocio;

  const _TarjetaNegocio({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ClienteMenuScreen(negocio: negocio)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.lgAll,
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: AppImagenRed(
                  url: negocio.bannerUrl,
                  icono: Icons.storefront_outlined,
                  respaldoAsset: 'assets/images/comida_banner.jpg',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: negocio.logoUrl.isNotEmpty
                        ? AppImagenRed(url: negocio.logoUrl, icono: Icons.storefront_outlined)
                        : Container(
                            color: theme.colorScheme.primaryContainer,
                            alignment: Alignment.center,
                            child: Text(
                              negocio.nombre.isNotEmpty ? negocio.nombre[0].toUpperCase() : '?',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        negocio.nombre,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (negocio.descripcion.isNotEmpty)
                        Text(
                          negocio.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
