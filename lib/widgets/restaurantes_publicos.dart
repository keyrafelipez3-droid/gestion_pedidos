import 'dart:async';
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

class _RestaurantesPublicosState extends State<RestaurantesPublicos>
    with SingleTickerProviderStateMixin {
  late final Future<List<Map<String, String>>> _lista = NegocioService.instancia
      .directorioPublico();

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
    if (elegirRestaurante(context, r)) {
      setState(() {});
      widget.onElegido?.call();
    }
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
                style: textos.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr(
                  'Toca un restaurante para usar su código, o inicia sesión y elígelo de la lista.',
                ),
                textAlign: TextAlign.center,
                style: textos.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, restricciones) {
                  // Dos tarjetas por fila en el celular; más en pantallas
                  // anchas. Siempre llenan el ancho, sin huecos al costado.
                  final w = restricciones.maxWidth;
                  const separacion = AppSpacing.sm + 4;
                  final columnas = math.max(2, math.min(4, (w / 170).floor()));
                  // La última fila, si queda incompleta, se reparte todo el
                  // ancho (sin huecos al costado).
                  final enUltima = lista.length % columnas;
                  final inicioUltima = lista.length - enUltima;
                  double anchoDe(int i) {
                    final n = (enUltima != 0 && i >= inicioUltima)
                        ? enUltima
                        : columnas;
                    return (w - separacion * (n - 1)) / n;
                  }

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
                            width: anchoDe(i),
                            child: _Restaurante(
                              datos: lista[i],
                              elegido:
                                  elegido != null &&
                                  elegido == lista[i]['codigo'],
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

/// Deja elegido el código del restaurante [r] (para entrar a él al iniciar
/// sesión o crear la cuenta) y avisa con un mensaje. Devuelve true si se
/// eligió (false si el restaurante no tiene código publicado).
bool elegirRestaurante(BuildContext context, Map<String, String> r) {
  final codigo = r['codigo'] ?? '';
  final nombre = r['nombre'] ?? '';
  final mensajero = ScaffoldMessenger.of(context);
  if (codigo.isEmpty) {
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          tr('Inicia sesión o crea tu cuenta y elige {nombre} en la lista.', {
            'nombre': nombre,
          }),
        ),
      ),
    );
    return false;
  }
  CodigoNegocioService.codigoDelEnlace = codigo;
  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          tr(
            'Elegiste {nombre} (código {codigo}). Inicia sesión o crea tu cuenta para entrar.',
            {'nombre': nombre, 'codigo': codigo},
          ),
        ),
      ),
    );
  return true;
}

/// Carrusel de restaurantes para el panel oscuro del login en la
/// computadora: las mismas tarjetas que se dan vuelta, en una fila que
/// avanza sola cada pocos segundos (se detiene con el mouse encima y no se
/// mueve sola con "reducir animaciones"). Tiene flechas para moverla a mano.
class CarruselRestaurantes extends StatefulWidget {
  /// Se llama cuando el cliente elige un restaurante con código.
  final VoidCallback? onElegido;

  const CarruselRestaurantes({super.key, this.onElegido});

  @override
  State<CarruselRestaurantes> createState() => _CarruselRestaurantesState();
}

class _CarruselRestaurantesState extends State<CarruselRestaurantes> {
  static const double _anchoTarjeta = 176;
  static const double _separacion = 12;

  late final Future<List<Map<String, String>>> _lista = NegocioService.instancia
      .directorioPublico();
  final ScrollController _scroll = ScrollController();
  Timer? _reloj;
  bool _encima = false;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(
      const Duration(milliseconds: 3200),
      (_) => _avanzar(auto: true),
    );
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _avanzar({bool auto = false, int paso = 1}) {
    if (!mounted || !_scroll.hasClients) return;
    if (auto && (_encima || MediaQuery.disableAnimationsOf(context))) return;
    final pos = _scroll.position;
    var destino = pos.pixels + paso * (_anchoTarjeta + _separacion);
    // Al llegar al final vuelve al inicio (y al revés).
    if (destino > pos.maxScrollExtent + 1) destino = 0;
    if (destino < -1) destino = pos.maxScrollExtent;
    if (MediaQuery.disableAnimationsOf(context)) {
      _scroll.jumpTo(destino.clamp(0, pos.maxScrollExtent));
    } else {
      _scroll.animateTo(
        destino.clamp(0, pos.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return FutureBuilder<List<Map<String, String>>>(
      future: _lista,
      builder: (context, snap) {
        final lista = snap.data ?? const <Map<String, String>>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        final elegido = CodigoNegocioService.codigoDelEnlace;
        Widget flecha(IconData icono, int paso, String etiqueta) => Semantics(
          button: true,
          label: etiqueta,
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              foregroundColor: Colors.white,
            ),
            onPressed: () => _avanzar(paso: paso),
            icon: Icon(icono),
          ),
        );
        return MouseRegion(
          onEnter: (_) => _encima = true,
          onExit: (_) => _encima = false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Restaurantes donde puedes pedir'),
                          style: textos.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(
                            'Toca un restaurante para usar su código, o inicia sesión y elígelo de la lista.',
                          ),
                          style: textos.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (lista.length > 1) ...[
                    const SizedBox(width: AppSpacing.sm),
                    flecha(Icons.chevron_left_rounded, -1, tr('Anterior')),
                    const SizedBox(width: AppSpacing.xs),
                    flecha(Icons.chevron_right_rounded, 1, tr('Siguiente')),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 216,
                child: ListView.separated(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  // Un poco de margen para que se vea la sombra.
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: lista.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _separacion),
                  itemBuilder: (context, i) => SizedBox(
                    width: _anchoTarjeta,
                    child: Align(
                      alignment: Alignment.topCenter,
                      widthFactor: 1,
                      child: SizedBox(
                        width: _anchoTarjeta,
                        child: _Restaurante(
                          datos: lista[i],
                          elegido:
                              elegido != null && elegido == lista[i]['codigo'],
                          onTap: () {
                            if (elegirRestaurante(context, lista[i])) {
                              setState(() {});
                              widget.onElegido?.call();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pantalla con todos los restaurantes (en el celular se abre desde el
/// login con "Ver restaurantes", para no alargar el formulario). Al elegir
/// uno con código vuelve al login, que muestra "Vas a pedir en …".
class RestaurantesScreen extends StatelessWidget {
  const RestaurantesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Restaurantes'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: RestaurantesPublicos(
                onElegido: () => Navigator.of(context).maybePop(true),
              ),
            ),
          ),
        ),
      ),
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

  const _Aparecer({
    required this.animacion,
    required this.indice,
    required this.total,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final paso = total <= 1 ? 0.0 : 0.5 / (total - 1);
    final inicio = math.min(indice * paso, 0.5);
    final curva = CurvedAnimation(
      parent: animacion,
      curve: Interval(
        inicio,
        math.min(inicio + 0.5, 1),
        curve: Curves.easeOutBack,
      ),
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

/// Tarjeta de un restaurante que SE DA VUELTA: adelante el logo, el
/// nombre y la ciudad; atrás el CÓDIGO para entrar, con un botón para
/// elegirlo. En la computadora se voltea al pasar el mouse; en el celular,
/// al tocarla. Con "reducir animaciones" cambia de cara sin girar.
class _Restaurante extends StatefulWidget {
  final Map<String, String> datos;
  final bool elegido;
  final VoidCallback onTap;

  const _Restaurante({
    required this.datos,
    required this.elegido,
    required this.onTap,
  });

  @override
  State<_Restaurante> createState() => _RestauranteState();
}

class _RestauranteState extends State<_Restaurante>
    with SingleTickerProviderStateMixin {
  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _giro.dispose();
    super.dispose();
  }

  void _voltear(bool atras) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _giro.value = atras ? 1 : 0;
    } else if (atras) {
      _giro.forward();
    } else {
      _giro.reverse();
    }
  }

  bool get _atras => _giro.value >= 0.5;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final datos = widget.datos;
    final nombre = datos['nombre'] ?? '';
    final ciudad = datos['ciudad'] ?? '';
    final codigo = datos['codigo'] ?? '';
    final color = colorDesdeHex(datos['colorPrimario'], scheme.primary);
    final brand = context.brand;
    final elegido = widget.elegido;

    final etiqueta = [
      nombre,
      if (ciudad.isNotEmpty) ciudad,
      if (codigo.isNotEmpty)
        tr('código {codigo}', {'codigo': codigo.split('').join(' ')}),
      if (elegido) tr('elegido'),
    ].join(', ');

    Widget marco(Widget hijo, {required bool trasera}) => Container(
      decoration: brand
          .decoracionTarjeta(scheme)
          .copyWith(
            color: trasera
                ? Color.alphaBlend(
                    color.withValues(alpha: 0.08),
                    scheme.surface,
                  )
                : null,
            border: Border.all(
              color: elegido
                  ? color
                  : (trasera
                        ? color.withValues(alpha: 0.5)
                        : scheme.outlineVariant),
              width: elegido ? 2 : 1,
            ),
            boxShadow: [
              if (elegido || trasera)
                BoxShadow(
                  color: color.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
            ],
          ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: brand.card,
          // Tocar la tarjeta la da vuelta (en el celular no hay mouse).
          onTap: () => _voltear(!_atras),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm + 2,
            ),
            child: hijo,
          ),
        ),
      ),
    );

    final frente = marco(
      _Frente(datos: datos, color: color, elegido: elegido),
      trasera: false,
    );
    final reverso = marco(
      _Reverso(
        datos: datos,
        color: color,
        elegido: elegido,
        onElegir: widget.onTap,
      ),
      trasera: true,
    );

    return Semantics(
      button: true,
      selected: elegido,
      label: etiqueta,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => _voltear(true),
        onExit: (_) => _voltear(false),
        child: AnimatedBuilder(
          animation: _giro,
          builder: (context, _) {
            final t = Curves.easeInOutCubic.transform(_giro.value);
            final atras = t >= 0.5;
            final angulo = math.pi * t;
            // Las dos caras están siempre (así la tarjeta mide lo que la
            // más alta) y solo se ve la que corresponde.
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angulo),
              child: Stack(
                // Las caras usan todo el ancho que le da la grilla.
                fit: StackFit.passthrough,
                children: [
                  Visibility(
                    visible: !atras,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: frente,
                  ),
                  Positioned.fill(
                    child: Visibility(
                      visible: atras,
                      maintainState: true,
                      maintainAnimation: true,
                      // La cara de atrás se dibuja girada para que no se
                      // lea al revés.
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: reverso,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cara de adelante: logo, nombre, ciudad y una pista "Ver código".
class _Frente extends StatelessWidget {
  final Map<String, String> datos;
  final Color color;
  final bool elegido;
  const _Frente({
    required this.datos,
    required this.color,
    required this.elegido,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final nombre = datos['nombre'] ?? '';
    final ciudad = datos['ciudad'] ?? '';
    final logo = datos['logoUrl'] ?? '';
    final codigo = datos['codigo'] ?? '';
    return Column(
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
                          style: textos.titleLarge?.copyWith(
                            color: textoSobreColor(color),
                          ),
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
                  child: Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: textoSobreColor(color),
                  ),
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
        Text(
          ciudad.isEmpty ? ' ' : ciudad,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 36,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                codigo.isEmpty ? Icons.login_rounded : Icons.flip_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  codigo.isEmpty ? tr('Iniciar sesión') : tr('Ver código'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textos.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cara de atrás: el código grande, para copiarlo, y el botón para entrar
/// con él.
class _Reverso extends StatelessWidget {
  final Map<String, String> datos;
  final Color color;
  final bool elegido;
  final VoidCallback onElegir;
  const _Reverso({
    required this.datos,
    required this.color,
    required this.elegido,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final nombre = datos['nombre'] ?? '';
    final codigo = datos['codigo'] ?? '';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          nombre,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textos.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (codigo.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              tr(
                'Inicia sesión o crea tu cuenta y elige {nombre} en la lista.',
                {'nombre': nombre},
              ),
              textAlign: TextAlign.center,
              style: textos.bodySmall,
            ),
          )
        else ...[
          Text(
            tr('Código').toUpperCase(),
            style: textos.labelSmall?.copyWith(
              color: color,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w800,
            ),
          ),
          _EtiquetaCodigo(codigo: codigo, color: color),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: textoSobreColor(color),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onElegir,
            icon: Icon(
              elegido ? Icons.check_rounded : Icons.login_rounded,
              size: 16,
            ),
            label: Text(elegido ? tr('Elegido') : tr('Entrar')),
          ),
        ],
      ],
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
                mensajero.showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('Código copiado: {codigo}', {'codigo': codigo}),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
