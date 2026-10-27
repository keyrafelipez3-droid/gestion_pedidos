import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'logo_caro.dart';

/// Pantalla de espera inicial (mientras se confirma la sesión): fondo
/// negro de la marca y el logo, que aparece con una animación corta
/// (crece y se aclara en menos de un segundo). Si el dispositivo tiene
/// activado "reducir movimiento", se muestra sin animación.
class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    final sinAnimacion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: AppBrand.negro,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: sinAnimacion ? 1.0 : 0.0, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0).toDouble(),
            child: Transform.scale(scale: 0.8 + 0.2 * t, child: child),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoCaro(size: 160),
              SizedBox(height: AppSpacing.md),
              Text(
                AppBrand.nombre,
                style: TextStyle(
                  color: AppBrand.dorado,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppBrand.dorado,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
