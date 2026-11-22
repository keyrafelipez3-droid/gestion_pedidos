import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Logo de la marca Nami, con las esquinas redondeadas. Cambia según la
/// hora: de día el plato y de noche la cuchara (ver AppBrand.logoAsset).
/// Si el archivo faltara, muestra un ícono de comida para que la pantalla
/// no quede rota.
class LogoCaro extends StatelessWidget {
  final double size;
  const LogoCaro({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.225),
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
