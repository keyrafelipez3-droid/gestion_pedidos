import 'package:flutter/material.dart';

/// Indicador de carga que NO aparece de inmediato: espera unos instantes
/// antes de mostrarse. Así, cuando los datos llegan casi al instante (lo
/// normal al cambiar entre secciones) no se ve un parpadeo de spinner;
/// solo se muestra si la carga realmente tarda.
class AppCargando extends StatelessWidget {
  const AppCargando({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
        builder: (context, opacidad, hijo) =>
            Opacity(opacity: opacidad, child: hijo),
        child: const CircularProgressIndicator(),
      ),
    );
  }
}
