import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'animaciones_marca.dart';

/// Pantalla de espera inicial (mientras se confirma la sesión): fondo
/// negro de la marca con tres puntitos dorados. Es el mismo negro con el
/// que empieza la bienvenida del inicio de sesión, así el paso de una a
/// otra no se nota.
class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppBrand.negro,
      body: Center(child: PuntosCargando(color: AppBrand.dorado, tamano: 10)),
    );
  }
}
