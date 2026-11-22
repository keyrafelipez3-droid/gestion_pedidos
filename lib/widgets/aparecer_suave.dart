import 'package:flutter/material.dart';

/// Hace aparecer a su hijo con un desvanecido, subiendo un poco y/o
/// agrandándose, una sola vez cuando se muestra por primera vez.
/// Se usa en la pantalla de inicio de sesión.
///
/// Si el usuario pidió reducir las animaciones en su teléfono o
/// computadora, el hijo se muestra directo, sin animación.
class AparecerSuave extends StatelessWidget {
  final Widget child;

  /// Cuánto esperar antes de empezar.
  final Duration retraso;

  /// Cuánto dura la animación (sin contar el retraso).
  final Duration duracion;

  /// Cuántos píxeles sube desde abajo (0 = no se mueve).
  final double desplazamiento;

  /// Tamaño inicial (1 = no cambia de tamaño; 0.7 = empieza al 70 %).
  final double escalaInicial;

  const AparecerSuave({
    super.key,
    required this.child,
    this.retraso = Duration.zero,
    this.duracion = const Duration(milliseconds: 600),
    this.desplazamiento = 24,
    this.escalaInicial = 1,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final total = retraso + duracion;
    final inicio = retraso.inMilliseconds / total.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(inicio, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, valor, hijo) {
        final escala = escalaInicial + (1 - escalaInicial) * valor;
        return Opacity(
          opacity: valor.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - valor) * desplazamiento),
            child: Transform.scale(scale: escala, child: hijo),
          ),
        );
      },
    );
  }
}
