import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre el marcador del teléfono con el número indicado. Si el dispositivo
/// no puede hacer llamadas (por ejemplo, una computadora), muestra el número
/// para que se pueda marcar a mano.
Future<void> llamarPorTelefono(BuildContext context, String? telefono) async {
  final numero = (telefono ?? '').trim();
  final mensajes = ScaffoldMessenger.of(context);
  if (numero.isEmpty) {
    mensajes.showSnackBar(
      const SnackBar(content: Text('No hay un teléfono registrado para llamar.')),
    );
    return;
  }
  var abierto = false;
  try {
    abierto = await launchUrl(Uri(scheme: 'tel', path: numero));
  } catch (_) {
    abierto = false;
  }
  if (!abierto) {
    mensajes.showSnackBar(
      SnackBar(content: Text('No se pudo abrir el teléfono. Número: $numero')),
    );
  }
}

/// Abre la dirección en la aplicación de mapas del dispositivo (o en el
/// navegador). No requiere ninguna clave.
Future<void> abrirEnMapas(
  BuildContext context,
  String direccion, {
  double? latitud,
  double? longitud,
}) async {
  final tieneCoordenadas = latitud != null && longitud != null;
  final texto = tieneCoordenadas ? '$latitud,$longitud' : direccion.trim();
  final mensajes = ScaffoldMessenger.of(context);
  if (texto.isEmpty) {
    mensajes.showSnackBar(
      const SnackBar(content: Text('El pedido no tiene dirección de entrega.')),
    );
    return;
  }
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': texto,
  });
  var abierto = false;
  try {
    abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    abierto = false;
  }
  if (!abierto) {
    mensajes.showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el mapa.')),
    );
  }
}
