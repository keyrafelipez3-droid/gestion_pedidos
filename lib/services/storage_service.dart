import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Sprint 2 (pedido del docente): subir el archivo de la imagen en vez de
/// solo pegar un link.
///
/// Firebase Storage necesita el plan de pago Blaze (pide tarjeta, aunque
/// el uso real sea gratis), así que se usa Cloudinary en su lugar: tiene
/// un plan gratuito sin tarjeta y un "unsigned upload" pensado
/// exactamente para esto — subir archivos directo desde la app cliente
/// sin necesitar una clave secreta ni un backend propio.
///
/// IMPORTANTE: reemplaza los dos valores de abajo por los de tu cuenta
/// gratuita de Cloudinary (Dashboard → "Cloud name"; Settings → Upload →
/// Upload presets → tu preset en modo "Unsigned"). No son datos
/// secretos — un "unsigned preset" está hecho justamente para ir
/// embebido en apps cliente, a diferencia de la API key/secret normal.
class StorageService {
  StorageService._();
  static final instancia = StorageService._();

  static const String _cloudName = 'swyberc0';
  static const String _uploadPreset = 'gestion_pedidos_unsigned';

  /// [ruta] se manda como "folder" en Cloudinary, solo para organizar el
  /// Media Library (ej. `negocios/{idNegocio}/productos/{idProducto}`) —
  /// no afecta la URL final que se guarda en Firestore, esa la entrega
  /// Cloudinary (`secure_url`).
  Future<String> subirImagen({
    required String ruta,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (_cloudName == 'TU_CLOUD_NAME_AQUI' || _uploadPreset == 'TU_UPLOAD_PRESET_AQUI') {
      throw Exception(
        'Falta configurar Cloudinary: completa _cloudName y _uploadPreset '
        'en lib/services/storage_service.dart',
      );
    }

    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = ruta
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: 'imagen.${_extensionDesdeContentType(contentType)}',
      ));

    final streamed = await request.send();
    final respuesta = await http.Response.fromStream(streamed);

    if (respuesta.statusCode != 200) {
      throw Exception('Cloudinary respondió ${respuesta.statusCode}: ${respuesta.body}');
    }

    final data = jsonDecode(respuesta.body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  String _extensionDesdeContentType(String contentType) {
    switch (contentType) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      default:
        return 'jpg';
    }
  }
}
