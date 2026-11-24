import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Igual que un `ListTile`, pero en pantallas angostas (celular) el bloque
/// de la derecha (estado, interruptor, botones) baja a su propia línea,
/// debajo del título.
///
/// Con un `ListTile` normal, ese bloque se queda con casi todo el ancho y
/// el título (nombre, teléfono) se partía letra por letra.
class ListTileAdaptable extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final GestureTapCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;
  final bool isThreeLine;

  /// Por debajo de este ancho, el bloque de la derecha va abajo.
  final double anchoMinimoEnFila;

  const ListTileAdaptable({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.contentPadding,
    this.isThreeLine = false,
    this.anchoMinimoEnFila = 560,
  });

  @override
  Widget build(BuildContext context) {
    final derecha = trailing;
    return LayoutBuilder(
      builder: (context, restricciones) {
        if (derecha == null || restricciones.maxWidth >= anchoMinimoEnFila) {
          return ListTile(
            leading: leading,
            title: title,
            subtitle: subtitle,
            trailing: derecha,
            onTap: onTap,
            contentPadding: contentPadding,
            isThreeLine: isThreeLine,
          );
        }
        // El bloque de abajo se alinea con el texto del título: después
        // del ícono o avatar (56 px + el margen del ListTile).
        final relleno = contentPadding?.resolve(Directionality.of(context)) ??
            const EdgeInsets.symmetric(horizontal: AppSpacing.md);
        final inicio = relleno.left + (leading != null ? 56 : 0);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: leading,
              title: title,
              subtitle: subtitle,
              onTap: onTap,
              contentPadding: contentPadding,
              isThreeLine: isThreeLine,
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(
                start: inicio,
                end: relleno.right,
                bottom: AppSpacing.sm,
              ),
              child: Align(alignment: AlignmentDirectional.centerStart, child: derecha),
            ),
          ],
        );
      },
    );
  }
}
