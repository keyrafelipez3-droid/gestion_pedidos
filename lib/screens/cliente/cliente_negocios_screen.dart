import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/colores.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_fotos_comida.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/app_search_field.dart';
import 'cliente_menu_screen.dart';

/// HU-16 (parte 1): el Cliente elige de qué negocio quiere ver el menú.
/// Es la puerta de entrada a todo el flujo de Cliente (menú → carrito →
/// checkout). Tarjetas grandes con foto, estilo apps de delivery; cada
/// negocio muestra su propio color de marca.
class ClienteNegociosScreen extends StatefulWidget {
  const ClienteNegociosScreen({super.key});

  @override
  State<ClienteNegociosScreen> createState() => _ClienteNegociosScreenState();
}

class _ClienteNegociosScreenState extends State<ClienteNegociosScreen> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  // Se crea una sola vez: si se creara en build(), cada letra escrita en el
  // buscador volvería a abrir la consulta a Firestore.
  late final Stream<List<NegocioModel>> _negocios = NegocioService.instancia.streamNegocios();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pedir ahora')),
      body: StreamBuilder<List<NegocioModel>>(
        stream: _negocios,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todos = snapshot.data!.where((n) => n.estado).toList();
          if (todos.isEmpty) {
            return const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Todavía no hay negocios disponibles',
              message: 'Vuelve a intentarlo más tarde.',
            );
          }
          final q = _busqueda.trim().toLowerCase();
          final negocios = q.isEmpty
              ? todos
              : todos
                  .where((n) =>
                      n.nombre.toLowerCase().contains(q) ||
                      n.descripcion.toLowerCase().contains(q))
                  .toList();
          return AppContenidoCentrado(
            maxWidth: 1100,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¿Dónde quieres pedir hoy?',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppSearchField(
                          controller: _busquedaCtrl,
                          hint: 'Buscar un negocio',
                          onChanged: (v) => setState(() => _busqueda = v),
                        ),
                      ],
                    ),
                  ),
                ),
                if (negocios.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.search_off,
                      title: 'No encontramos ese negocio',
                      message: 'Prueba con otro nombre.',
                    ),
                  )
                else
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
                        mainAxisExtent: 236,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _TarjetaNegocio(negocio: negocios[i], indice: i),
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

class _TarjetaNegocio extends StatefulWidget {
  final NegocioModel negocio;
  final int indice;

  const _TarjetaNegocio({required this.negocio, required this.indice});

  @override
  State<_TarjetaNegocio> createState() => _TarjetaNegocioState();
}

class _TarjetaNegocioState extends State<_TarjetaNegocio> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negocio = widget.negocio;
    final colorMarca = colorDesdeHex(negocio.colorPrimario, theme.colorScheme.primary);

    return MouseRegion(
      onEnter: (_) => setState(() => _encima = true),
      onExit: (_) => setState(() => _encima = false),
      child: AnimatedScale(
        scale: _encima ? 1.02 : 1,
        duration: AppMotion.normal,
        curve: AppMotion.curva,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.lgAll,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ClienteMenuScreen(
                  negocio: negocio,
                  fotoRespaldo: fotoComidaPorIndice(widget.indice),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: AppRadius.lgAll,
                  child: SizedBox(
                    height: 150,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImagenRed(
                          url: negocio.bannerUrl,
                          icono: Icons.storefront_outlined,
                          respaldoAsset: fotoComidaPorIndice(widget.indice),
                        ),
                        // Franja con el color de marca del negocio.
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(height: 5, color: colorMarca),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorMarca, width: 2),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: negocio.logoUrl.isNotEmpty
                              ? AppImagenRed(
                                  url: negocio.logoUrl,
                                  icono: Icons.storefront_outlined,
                                )
                              : Container(
                                  color: colorMarca,
                                  alignment: Alignment.center,
                                  child: Text(
                                    negocio.nombre.isNotEmpty
                                        ? negocio.nombre[0].toUpperCase()
                                        : '?',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: textoSobreColor(colorMarca),
                                    ),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
        ),
      ),
    );
  }
}
