import 'package:flutter/material.dart';

/// Limita el ancho del contenido y lo centra. En pantallas anchas
/// (navegador, tablet) evita que listas, tarjetas e imágenes se estiren
/// de borde a borde y se vean desproporcionadas; en celular no cambia
/// nada porque el ancho disponible ya es menor al máximo.
class AppContenidoCentrado extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppContenidoCentrado({super.key, required this.child, this.maxWidth = 720});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
