import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../theme/design_tokens.dart';
import 'logo_caro.dart';

/// Piezas de animación de la marca (estilo "Slate"): la entrada del
/// inicio de sesión, los puntitos del botón y la pantalla de carga.
/// Todas usan solo lo que trae Flutter, sin paquetes extra.

/// Muestra a su hijo cuando la animación llega a su tramo [inicio]–[fin]
/// (valores de 0 a 1): aparece con un desvanecido y sube unos píxeles.
/// Sirve para que los elementos de una pantalla entren uno tras otro.
class EntradaEscalonada extends StatelessWidget {
  final Animation<double> animacion;
  final double inicio;
  final double fin;
  final double desplazamiento;
  final Widget child;

  const EntradaEscalonada({
    super.key,
    required this.animacion,
    required this.inicio,
    required this.fin,
    required this.child,
    this.desplazamiento = 18,
  });

  @override
  Widget build(BuildContext context) {
    final tramo = CurvedAnimation(
      parent: animacion,
      curve: Interval(inicio, fin, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: tramo,
      child: child,
      builder: (context, hijo) => Opacity(
        opacity: tramo.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - tramo.value) * desplazamiento),
          child: hijo,
        ),
      ),
    );
  }
}

/// Escribe [texto] letra por letra según [progreso] (0 a 1), con un
/// cursor que se ve mientras escribe.
class TextoEscrito extends StatelessWidget {
  final String texto;
  final double progreso;
  final TextStyle? estilo;

  const TextoEscrito({super.key, required this.texto, required this.progreso, this.estilo});

  @override
  Widget build(BuildContext context) {
    final letras = (texto.length * progreso.clamp(0.0, 1.0)).ceil();
    final escribiendo = progreso > 0 && progreso < 1;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: texto.substring(0, letras)),
          // El cursor y las letras que faltan ocupan su lugar (invisibles)
          // para que el texto no se mueva mientras se escribe.
          TextSpan(
            text: escribiendo ? '|' : '',
            style: const TextStyle(color: AppBrand.dorado, fontWeight: FontWeight.w300),
          ),
          TextSpan(
            text: texto.substring(letras),
            style: const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
      style: estilo,
      textAlign: TextAlign.center,
      semanticsLabel: texto,
    );
  }
}

/// Recorta el borde de abajo con una curva suave (más baja a la
/// izquierda y más alta a la derecha), como en el diseño de referencia.
class CurvaInferior extends CustomClipper<Path> {
  final double alturaCurva;
  const CurvaInferior({this.alturaCurva = 64});

  @override
  Path getClip(Size size) {
    final h = size.height;
    final w = size.width;
    final c = math.min(alturaCurva, h * 0.4);
    return Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h - c)
      ..quadraticBezierTo(w * 0.42, h - c * 0.55, 0, h)
      ..close();
  }

  @override
  bool shouldReclip(CurvaInferior oldClipper) => oldClipper.alturaCurva != alturaCurva;
}

/// Tres puntitos que saltan uno tras otro. Se usa en el botón
/// "Iniciar sesión" mientras se comprueba la cuenta.
class PuntosCargando extends StatefulWidget {
  final Color color;
  final double tamano;
  const PuntosCargando({super.key, required this.color, this.tamano = 8});

  @override
  State<PuntosCargando> createState() => _PuntosCargandoState();
}

class _PuntosCargandoState extends State<PuntosCargando> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('Cargando'),
      child: SizedBox(
        height: widget.tamano * 3,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: widget.tamano * 0.7),
                Transform.translate(
                  offset: Offset(0, -_salto(i) * widget.tamano),
                  child: Opacity(
                    opacity: 0.45 + 0.55 * _salto(i),
                    child: Container(
                      width: widget.tamano,
                      height: widget.tamano,
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Altura del salto del puntito [i] (0 a 1), desfasada para cada uno.
  double _salto(int i) {
    final t = (_ctrl.value - i * 0.18) % 1.0;
    return t < 0.5 ? math.sin(t * 2 * math.pi) : 0;
  }
}

/// Pantalla de carga con la marca: el logo late suavemente y una barra
/// dorada avanza. Se muestra mientras se prepara la pantalla de cada rol.
class CargandoMarca extends StatefulWidget {
  const CargandoMarca({super.key});

  @override
  State<CargandoMarca> createState() => _CargandoMarcaState();
}

class _CargandoMarcaState extends State<CargandoMarca> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latido = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.06).animate(latido),
            child: const LogoCaro(size: 88),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                color: AppBrand.dorado,
                backgroundColor: AppBrand.dorado.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr('Preparando tu espacio…'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
