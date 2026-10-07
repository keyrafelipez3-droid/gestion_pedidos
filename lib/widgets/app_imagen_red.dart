import 'package:flutter/material.dart';

/// Imagen de red con fallback: si la URL está vacía o falla al cargar,
/// muestra un recuadro gris con un ícono en vez de dejar un hueco en
/// blanco. Se usa en tarjetas de negocios, productos y carrito.
class AppImagenRed extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final IconData icono;

  /// Foto local que se muestra cuando la URL está vacía o falla (ej. un
  /// banner de comida para negocios que todavía no subieron el suyo).
  final String? respaldoAsset;

  const AppImagenRed({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.icono = Icons.fastfood_outlined,
    this.respaldoAsset,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget vacio() => respaldoAsset != null
        ? Image.asset(
            respaldoAsset!,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (_, __, ___) => _recuadro(scheme),
          )
        : _recuadro(scheme);
    if (url.isEmpty) return vacio();
    return Image.network(
      url, webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => vacio(),
      loadingBuilder: (context, child, progreso) =>
          progreso == null ? child : _recuadro(scheme),
    );
  }

  Widget _recuadro(ColorScheme scheme) => Container(
          width: width,
          height: height,
          color: scheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Icon(icono, color: scheme.onSurfaceVariant),
      );
}

/// Avatar circular con foto de red. A diferencia de
/// `CircleAvatar(backgroundImage: NetworkImage(...))`, si la imagen no
/// carga (link roto, o un sitio que bloquea mostrarla en el navegador)
/// cae al ícono en vez de quedar en blanco, y usa el mismo método de
/// carga que el resto de la app para que los links pegados funcionen.
class AvatarImagen extends StatelessWidget {
  final String url;
  final IconData icono;
  final double radio;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AvatarImagen({
    super.key,
    required this.url,
    required this.icono,
    this.radio = 20,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final limpia = url.trim();
    return CircleAvatar(
      radius: radio,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      child: limpia.isEmpty
          ? Icon(icono)
          : ClipOval(
              child: AppImagenRed(
                url: limpia,
                width: radio * 2,
                height: radio * 2,
                icono: icono,
              ),
            ),
    );
  }
}
