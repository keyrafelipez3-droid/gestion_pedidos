import 'package:flutter/material.dart';

import '../models/negocio_model.dart';
import '../services/app_theme_controller.dart';

/// Pinta [child] con el tema (colores, tipografía, forma de botones) del
/// [negocio] indicado. El Cliente no pertenece a ningún negocio, así que su
/// sesión usa el tema por defecto; al entrar al menú de un negocio, esas
/// pantallas se envuelven en este widget para que se vean con la marca de
/// ESE negocio.
class TemaNegocio extends StatelessWidget {
  final NegocioModel negocio;
  final Widget child;

  const TemaNegocio({super.key, required this.negocio, required this.child});

  @override
  Widget build(BuildContext context) {
    final tema = AppThemeController.instancia.buildThemeFor(
      negocio,
      negocio.modoOscuro ? Brightness.dark : Brightness.light,
    );
    return Theme(data: tema, child: child);
  }
}
