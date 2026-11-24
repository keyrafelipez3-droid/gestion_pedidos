import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import 'animaciones_marca.dart';

/// Pantalla de espera inicial (mientras se confirma la sesión): fondo
/// berenjena de la marca con tres puntitos de ají. Es el mismo fondo con
/// el que empieza la bienvenida del inicio de sesión, así el paso de una a
/// otra no se nota.
class PantallaCarga extends StatelessWidget {
  const PantallaCarga({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppBrand.berenjena,
      body: Center(child: PuntosCargando(color: AppBrand.aji, tamano: 10)),
    );
  }
}
