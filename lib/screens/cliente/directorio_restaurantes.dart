import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/negocio_model.dart';
import '../../services/codigo_negocio_service.dart';
import '../../services/negocio_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/brand_style.dart';
import '../../theme/design_tokens.dart';
import '../../utils/colores.dart';
import '../../widgets/app_fotos_comida.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/codigo_restaurante.dart';
import 'condiciones_restaurante_screen.dart';

/// El cliente entra al restaurante que eligió en la lista (sin código) y
/// abre su menú. Si ya había entrado antes, solo abre el menú.
///
/// Se usa el contexto del Navigator: al entrar, la pantalla de inicio se
/// redibuja (pasa a mostrar la portada del restaurante) y la tarjeta que
/// se tocó deja de existir.
Future<void> entrarDesdeLista(BuildContext context, NegocioModel negocio, {required bool yaEntro}) async {
  final nav = Navigator.of(context);
  final avisos = ScaffoldMessenger.of(context);
  final uid = SesionActual.instancia.actual?.idUsuario;
  if (uid == null) return;
  if (!yaEntro) {
    try {
      await CodigoNegocioService.instancia.unirseDesdeLista(uid, negocio.idNegocio);
    } catch (_) {
      avisos.showSnackBar(SnackBar(
        content: Text(tr('No pudimos abrir este restaurante. Inténtalo de nuevo o usa su código.')),
      ));
      return;
    }
  }
  if (!nav.mounted) return;
  await abrirRestaurante(nav.context, negocio, fotoRespaldo: fotoComidaPara(negocio.idNegocio));
}

/// Lista de los restaurantes activos con su logo, nombre y ciudad, para
/// que un cliente nuevo elija dónde pedir sin saber ningún código. No
/// muestra nunca el código de acceso (ese está en un documento privado).
///
/// No tiene su propio desplazamiento: se pone dentro de la pantalla de
/// inicio o de [DirectorioRestaurantesScreen].
class DirectorioRestaurantes extends StatefulWidget {
  /// Restaurantes a los que el cliente ya entró (se marcan como "Tuyo").
  final Set<String> misIds;

  /// Se muestra si la lista no se puede cargar: así el cliente siempre
  /// tiene la opción del código.
  final Widget respaldo;

  const DirectorioRestaurantes({super.key, required this.misIds, required this.respaldo});

  @override
  State<DirectorioRestaurantes> createState() => _DirectorioRestaurantesState();
}

class _DirectorioRestaurantesState extends State<DirectorioRestaurantes> {
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  // Una sola consulta: si se creara en build(), cada letra del buscador
  // volvería a leer de Firestore.
  late final Stream<List<NegocioModel>> _lista = NegocioService.instancia.streamDirectorio();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<NegocioModel>>(
      stream: _lista,
      builder: (context, s) {
        if (s.hasError) return widget.respaldo;
        if (!s.hasData) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final todos = s.data!;
        if (todos.isEmpty) return widget.respaldo;
        final q = _busqueda.trim().toLowerCase();
        final negocios = q.isEmpty
            ? todos
            : todos
                .where((n) =>
                    n.nombre.toLowerCase().contains(q) ||
                    n.ciudad.toLowerCase().contains(q) ||
                    n.descripcion.toLowerCase().contains(q))
                .toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('¿Dónde quieres pedir hoy?'),
              style: textos.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr('Elige un restaurante para ver su menú. No necesitas código.'),
              style: textos.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.md),
            if (todos.length > 3) ...[
              AppSearchField(
                controller: _busquedaCtrl,
                hint: tr('Buscar un negocio'),
                onChanged: (v) => setState(() => _busqueda = v),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (negocios.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  tr('No encontramos ese negocio'),
                  textAlign: TextAlign.center,
                  style: textos.bodyLarge,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, c) {
                  const gap = AppSpacing.md;
                  final columnas = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
                  final ancho = (c.maxWidth - gap * (columnas - 1)) / columnas;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final n in negocios)
                        SizedBox(
                          width: ancho,
                          child: _TarjetaDirectorio(negocio: n, yaEntro: widget.misIds.contains(n.idNegocio)),
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Un restaurante de la lista: logo grande, nombre, ciudad y descripción.
class _TarjetaDirectorio extends StatelessWidget {
  final NegocioModel negocio;
  final bool yaEntro;

  const _TarjetaDirectorio({required this.negocio, required this.yaEntro});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textos = theme.textTheme;
    final n = negocio;
    final colorMarca = colorDesdeHex(n.colorPrimario, scheme.primary);
    final ciudad = n.ciudad.trim();
    final descripcion = n.descripcion.trim();
    return Semantics(
      button: true,
      label: tr('Ver el menú de {restaurante}', {'restaurante': n.nombre}),
      excludeSemantics: true,
      child: Container(
        decoration: context.brand.decoracionTarjeta(scheme),
        child: ClipRRect(
          borderRadius: context.brand.card,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => entrarDesdeLista(context, n, yaEntro: yaEntro),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colorMarca, width: 2),
                      ),
                      child: ClipOval(
                        child: n.logoUrl.isNotEmpty
                            ? AppImagenRed(
                                url: n.logoUrl,
                                icono: Icons.storefront_outlined,
                                descripcion: tr('Logo de {restaurante}', {'restaurante': n.nombre}),
                              )
                            : Container(
                                color: colorMarca,
                                alignment: Alignment.center,
                                child: Text(
                                  n.nombre.isNotEmpty ? n.nombre[0].toUpperCase() : '?',
                                  style: textos.titleLarge?.copyWith(color: textoSobreColor(colorMarca)),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            n.nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (ciudad.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.place_outlined, size: 16, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ciudad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (descripcion.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textos.bodySmall,
                            ),
                          ],
                          if (yaEntro) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: colorMarca),
                                const SizedBox(width: 4),
                                Text(
                                  tr('Ya es uno de tus restaurantes'),
                                  style: textos.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pantalla con todos los restaurantes (desde "Añadir restaurante"). Abajo
/// queda la opción de entrar con el código o el enlace del restaurante.
class DirectorioRestaurantesScreen extends StatelessWidget {
  final Set<String> misIds;

  const DirectorioRestaurantesScreen({super.key, required this.misIds});

  @override
  Widget build(BuildContext context) {
    final uid = SesionActual.instancia.actual?.idUsuario;
    final codigo = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      onPressed: uid == null ? null : () => pedirCodigoRestaurante(context, uid),
      icon: const Icon(Icons.vpn_key_outlined),
      label: Text(tr('Tengo un código')),
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr('Restaurantes'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DirectorioRestaurantes(misIds: misIds, respaldo: const SizedBox.shrink()),
                  const SizedBox(height: AppSpacing.lg),
                  codigo,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
