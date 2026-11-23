import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Pantalla de acceso (login / registro) para celular: una foto de comida
/// a pantalla completa de fondo y el formulario en una tarjeta que sube
/// desde abajo, como en las apps de delivery. Si el archivo de la foto
/// faltara, queda el color de marca de fondo.
class AppPantallaFoto extends StatelessWidget {
  final String asset;
  final Widget formulario;

  /// true si la pantalla tiene una AppBar transparente encima de la foto
  /// (deja espacio arriba para que no se tape).
  final bool conAppBar;

  const AppPantallaFoto({
    super.key,
    required this.asset,
    required this.formulario,
    this.conAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: scheme.primary),
        Image.asset(
          asset,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
        // Oscurece la foto hacia abajo con el berenjena de la marca (no
        // con negro puro), para que la tarjeta resalte y la foto se vea
        // cálida.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
              colors: [Color(0x1A2A1730), Color(0x592A1730), Color(0xE62A1730)],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.md * 2,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (conAppBar) const SizedBox(height: kToolbarHeight),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Material(
                          color: scheme.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppRadius.xl + 4),
                          elevation: 6,
                          shadowColor: const Color(0x662A1730),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: formulario,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
