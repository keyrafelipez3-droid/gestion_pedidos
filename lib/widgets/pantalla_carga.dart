import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'logo_caro.dart';

/// Pantalla de espera inicial (mientras se confirma la sesión): fondo
/// negro de la marca, logo y un indicador discreto.
class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppBrand.negro,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoCaro(size: 160),
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
    );
  }
}
