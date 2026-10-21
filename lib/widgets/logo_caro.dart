import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Logo de la marca Caro, recortado en círculo (el archivo del logo es un
/// cuadrado negro con el círculo dorado). Si el archivo faltara, muestra
/// un ícono de comida para que la pantalla no quede rota.
class LogoCaro extends StatelessWidget {
  final double size;
  const LogoCaro({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        AppBrand.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Logo de ${AppBrand.nombre}',
        errorBuilder: (context, error, stack) => Container(
          width: size,
          height: size,
          color: AppBrand.negro,
          alignment: Alignment.center,
          child: Icon(Icons.restaurant_menu, size: size * 0.5, color: AppBrand.dorado),
        ),
      ),
    );
  }
}
