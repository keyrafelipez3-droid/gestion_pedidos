import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/idioma.dart';
import '../services/codigo_negocio_service.dart';
import '../services/negocio_service.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';
import '../utils/colores.dart';
import 'app_imagen_red.dart';

/// "Restaurantes donde puedes pedir": tarjetas animadas con el logo, el
/// nombre, la ciudad y el CÓDIGO de cada restaurante activo, en la pantalla
/// de inicio de sesión. El cliente ve el código y, al tocar la tarjeta, ese
/// código queda elegido: al iniciar sesión o crear su cuenta entra directo
/// a ese restaurante. Se leen una sola vez de la lista pública
/// (`directorio`), que no lleva datos sensibles. Si no hay restaurantes o
/// no se pueden leer, no se muestra nada.
class RestaurantesPublicos extends StatefulWidget {
  /// Se llama cuando el cliente toca un restaurante con código (para que la
  /// pantalla muestre "Vas a pedir en …").
  final VoidCallback? onElegido;

  const RestaurantesPublicos({super.key, this.onElegido});

  @override
  State<RestaurantesPublicos> createState() => _RestaurantesPublicosState();
}

class _RestaurantesPublicosState extends State<RestaurantesPublicos> with SingleTickerProviderStateMixin {
  late final Future<List<Map<String, String>>> _lista = NegocioService.instancia.directorioPublico();

  /// Entrada escalonada de las tarjetas (una tras otra).
  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _animado = false;

  @override
  void dispose() {
    _entrada.dispose();
    super.dispose();
  }

  void _elegir(Map<String, String> r) {
    final codigo = r['codigo'] ?? '';
    final nombre = r['nombre'] ?? '';
    final mensajero = ScaffoldMessenger.of(context);
    if (codigo.isEmpty) {
      mensajero.showSnackBar(SnackBar(
        content: Text(tr('Inicia sesión o crea tu cuenta y elige {nombre} en la lista.', {'nombre': nombre})),
      ));
      return;
    }
    setState(() => CodigoNegocioService.codigoDelEnlace = codigo);
    widget.onElegido?.call();
    mensajero
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr('Elegiste {nombre} (código {codigo}). Inicia sesión o crea tu cuenta para entrar.',
            {'nombre': nombre, 'codigo': codigo})),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _lista,
      builder: (context, snap) {
        final lista = snap.data ?? const <Map<String, String>>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        if (!_animado) {
          _animado = true;
          if (MediaQuery.disableAnimationsOf(context)) {
            _entrada.value = 1;
          } else {
            _entrada.forward();
          }
        }
        final textos = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        final elegido = CodigoNegocioService.codigoDelEnlace;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Restaurantes donde puedes pedir'),
                textAlign: TextAlign.center,
                style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr('Toca un restaurante para usar su código, o inicia sesión y elígelo de la lista.'),
                textAlign: TextAlign.center,
                style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, restricciones) {
                  // Dos tarjetas por fila en el celular; más en pantallas
                  // anchas. Siempre llenan el ancho, sin huecos al costado.
                  final w = restricciones.maxWidth;
                  const separacion = AppSpacing.sm + 4;
                  final columnas = math.max(2, math.min(4, (w / 170).floor()));
                  final ancho = (w - separacion * (columnas - 1)) / columnas;
                  return Wrap(
                    spacing: separacion,
                    runSpacing: separacion,
                    children: [
                      for (var i = 0; i < lista.length; i++)
                        _Aparecer(
                          animacion: _entrada,
                          indice: i,
                          total: lista.length,
                          child: SizedBox(
                            width: ancho,
                            child: _Restaurante(
                              datos: lista[i],
                              elegido: elegido != null && elegido == lista[i]['codigo'],
                              onTap: () => _elegir(lista[i]),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Hace aparecer cada tarjeta un poco después que la anterior: sube,
/// crece y se aclara.
class _Aparecer extends StatelessWidget {
  final Animation<double> animacion;
  final int indice;
  final int total;
  final Widget child;

  const _Aparecer({required this.animacion, required this.indice, required this.total, required this.child});

  @override
  Widget build(BuildContext context) {
    final paso = total <= 1 ? 0.0 : 0.5 / (total - 1);
    final inicio = math.min(indice * paso, 0.5);
    final curva = CurvedAnimation(
      parent: animacion,
      curve: Interval(inicio, math.min(inicio + 0.5, 1), curve: Curves.easeOutBack),
    );
    return AnimatedBuilder(
      animation: curva,
      child: child,
      builder: (context, hijo) {
        final t = curva.value;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: Transform.scale(scale: 0.92 + 0.08 * t, child: hijo),
          ),
        );
      },
    );
  }
}

/// Tarjeta de un restaurante: logo con aro de su color, nombre, ciudad y
/// su código en una etiqueta. Al pasar el mouse se eleva un poco.
class _Restaurante extends StatefulWidget {
  final Map<String, String> datos;
  final bool elegido;
  final VoidCallback onTap;

  const _Restaurante({required this.datos, required this.elegido, required this.onTap});

  @override
  State<_Restaurante> createState() => _RestauranteState();
}

class _RestauranteState extends State<_Restaurante> {
  bool _encima = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final datos = widget.datos;
    final nombre = datos['nombre'] ?? '';
    final ciudad = datos['ciudad'] ?? '';
    final logo = datos['logoUrl'] ?? '';
    final codigo = datos['codigo'] ?? '';
    final color = colorDesdeHex(datos['colorPrimario'], scheme.primary);
    final sinAnimacion = MediaQuery.disableAnimationsOf(context);
    final brand = context.brand;
    final elegido = widget.elegido;

    final etiqueta = [
      nombre,
      if (ciudad.isNotEmpty) ciudad,
      if (codigo.isNotEmpty) tr('código {codigo}', {'codigo': codigo.split('').join(' ')}),
      if (elegido) tr('elegido'),
    ].join(', ');

    return Semantics(
      button: true,
      selected: elegido,
      label: etiqueta,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _encima = true),
        onExit: (_) => setState(() => _encima = false),
        child: AnimatedSlide(
          duration: sinAnimacion ? Duration.zero : const Duration(milliseconds: 160),
          offset: _encima ? const Offset(0, -0.03) : Offset.zero,
          child: AnimatedContainer(
            duration: sinAnimacion ? Duration.zero : const Duration(milliseconds: 200),
            decoration: brand.decoracionTarjeta(scheme).copyWith(
                  border: Border.all(
                    color: elegido ? color : (_encima ? color.withValues(alpha: 0.5) : scheme.outlineVariant),
                    width: elegido ? 2 : 1,
                  ),
                  boxShadow: [
                    if (_encima || elegido)
                      BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: brand.card,
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.sm, AppSpacing.sm + 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: ClipOval(
                              child: logo.isNotEmpty
                                  ? AppImagenRed(url: logo, icono: Icons.storefront_outlined)
                                  : Container(
                                      color: color,
                                      alignment: Alignment.center,
                                      child: Text(
                                        nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                                        style: textos.titleLarge?.copyWith(color: textoSobreColor(color)),
                                      ),
                                    ),
                            ),
                          ),
                          if (elegido)
                            Positioned(
                              right: -4,
                              bottom: -2,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: scheme.surface, width: 2),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Icon(Icons.check_rounded, size: 14, color: textoSobreColor(color)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        nombre,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (ciudad.isNotEmpty)
                        Text(
                          ciudad,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      if (codigo.isNotEmpty)
                        _EtiquetaCodigo(codigo: codigo, color: color)
                      else
                        // Sin código publicado: se elige al iniciar sesión.
                        // Misma altura que la etiqueta del código, así las
                        // tarjetas de una fila quedan parejas.
                        Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.login_rounded, size: 14, color: scheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  tr('Iniciar sesión'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textos.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El código del restaurante en una etiqueta, con letras separadas para
/// leerlo y copiarlo fácil. Tocar el ícono lo copia.
class _EtiquetaCodigo extends StatelessWidget {
  final String codigo;
  final Color color;

  const _EtiquetaCodigo({required this.codigo, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final tono = Color.lerp(color, scheme.onSurface, 0.25)!;
    return Container(
      height: 36,
      padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 4, 0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.vpn_key_outlined, size: 14, color: tono),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              codigo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.labelLarge?.copyWith(
                color: tono,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 14,
              tooltip: tr('Copiar código'),
              icon: Icon(Icons.copy_rounded, color: tono),
              onPressed: () async {
                final mensajero = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: codigo));
                mensajero.showSnackBar(SnackBar(content: Text(tr('Código copiado: {codigo}', {'codigo': codigo}))));
              },
            ),
          ),
        ],
      ),
    );
  }
}
