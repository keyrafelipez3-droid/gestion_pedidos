import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/negocio_model.dart';
import '../../services/codigo_negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/descarga.dart';
import '../../utils/colores.dart';
import '../../widgets/app_imagen_red.dart';

/// Escapa texto para ponerlo dentro de HTML.
String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/// Página para imprimir el QR del restaurante (por ejemplo, para pegarlo
/// en las mesas o en la puerta): logo, nombre, el QR y el código.
String htmlQrRestaurante({
  required String nombre,
  required String codigo,
  required String enlace,
  required String qrPngBase64,
  required String colorHex,
  String logoUrl = '',
}) {
  final logo = logoUrl.trim().isEmpty
      ? ''
      : '<img class="logo" src="${_esc(logoUrl.trim())}" alt="Logo de ${_esc(nombre)}">';
  final tarjeta = '<div class="tarjeta">$logo'
      '<h1>${_esc(nombre)}</h1><p class="pide">Escanea para ver el menú y pedir</p>'
      '<img class="qr" src="data:image/png;base64,$qrPngBase64" alt="Código QR de ${_esc(nombre)}">'
      '<p class="codigo">${_esc(codigo)}</p><p class="enlace">${_esc(enlace)}</p></div>';
  return '''<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>QR de ${_esc(nombre)}</title>
<style>
  @page{size:A4;margin:14mm}
  body{font-family:Arial,Helvetica,sans-serif;margin:0;display:flex;flex-wrap:wrap;gap:10mm;justify-content:center;padding:10mm}
  .tarjeta{width:85mm;border:2px solid $colorHex;border-radius:6mm;padding:6mm;text-align:center;break-inside:avoid}
  .logo{width:18mm;height:18mm;border-radius:50%;object-fit:cover;border:1.5px solid $colorHex}
  h1{font-size:16pt;margin:3mm 0 1mm}
  .pide{font-size:11pt;color:#333;margin:0 0 3mm}
  .qr{width:60mm;height:60mm}
  .codigo{font-size:18pt;font-weight:800;letter-spacing:3px;color:$colorHex;margin:2mm 0 0}
  .enlace{font-size:7.5pt;color:#666;word-break:break-all}
  .acciones{width:100%;text-align:center} .acciones button{font:700 14px Arial;padding:10px 22px;border:0;border-radius:8px;background:#111;color:#fff;cursor:pointer}
  @media print{.acciones{display:none}}
</style></head><body onload="window.print()">
${List.filled(4, tarjeta).join('\n')}
<div class="acciones"><button onclick="window.print()">Imprimir o guardar como PDF</button></div>
</body></html>''';
}

/// QR del restaurante con sus colores y su logo. Al escanearlo, el cliente
/// entra directo al restaurante (el enlace lleva su código de acceso).
/// Se puede imprimir en una hoja con cuatro tarjetas para las mesas.
class QrRestauranteScreen extends StatefulWidget {
  final NegocioModel negocio;
  final String codigo;

  const QrRestauranteScreen({super.key, required this.negocio, required this.codigo});

  @override
  State<QrRestauranteScreen> createState() => _QrRestauranteScreenState();
}

class _QrRestauranteScreenState extends State<QrRestauranteScreen> {
  bool _imprimiendo = false;

  String get _enlace => CodigoNegocioService.enlace(widget.codigo);

  /// Color de la marca, oscurecido si hace falta para que el QR se pueda
  /// leer bien (los lectores necesitan buen contraste sobre blanco).
  Color _colorQr(BuildContext context) {
    final marca = colorDesdeHex(widget.negocio.colorPrimario, Theme.of(context).colorScheme.primary);
    final hsl = HSLColor.fromColor(marca);
    return hsl.lightness > 0.4 ? hsl.withLightness(0.32).toColor() : marca;
  }

  static String _hex(Color c) {
    int canal(double v) => (v * 255).round().clamp(0, 255).toInt();
    final r = canal(c.r).toRadixString(16).padLeft(2, '0');
    final g = canal(c.g).toRadixString(16).padLeft(2, '0');
    final b = canal(c.b).toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
  }

  Future<void> _imprimir(Color color) async {
    setState(() => _imprimiendo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final painter = QrPainter(
        data: _enlace,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        gapless: true,
        eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF111111),
        ),
      );
      final datos = await painter.toImageData(900, format: ui.ImageByteFormat.png);
      if (datos == null) throw Exception('sin imagen');
      final png = base64Encode(datos.buffer.asUint8List());
      final ok = await imprimirHtml(htmlQrRestaurante(
        nombre: widget.negocio.nombre,
        codigo: widget.codigo,
        enlace: _enlace,
        qrPngBase64: png,
        colorHex: _hex(color),
        logoUrl: widget.negocio.logoUrl,
      ));
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Para imprimir el QR, abre el panel en el navegador de una computadora.'),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo preparar el QR para imprimir.')));
    } finally {
      if (mounted) setState(() => _imprimiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.negocio;
    final color = _colorQr(context);
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('QR del restaurante')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // La tarjeta siempre es blanca: así se imprime y se escanea bien.
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.xlAll,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Column(
                    children: [
                      if (n.logoUrl.trim().isNotEmpty)
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: ClipOval(
                            child: AppImagenRed(url: n.logoUrl, icono: Icons.restaurant, descripcion: 'Logo de ${n.nombre}'),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        n.nombre,
                        textAlign: TextAlign.center,
                        style: textos.headlineSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Escanea para ver el menú y pedir',
                        style: textos.bodyMedium?.copyWith(color: Colors.black87),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        image: true,
                        label: 'Código QR para entrar a ${n.nombre}',
                        child: QrImageView(
                          data: _enlace,
                          size: 240,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: color),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widget.codigo,
                        style: textos.headlineSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      SelectableText(
                        _enlace,
                        textAlign: TextAlign.center,
                        style: textos.bodySmall?.copyWith(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                  onPressed: _imprimiendo ? null : () => _imprimir(color),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir 4 tarjetas para las mesas'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pégalo en las mesas, la puerta o el mostrador. Al escanearlo, el cliente entra '
                  'directo a tu restaurante.',
                  textAlign: TextAlign.center,
                  style: textos.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
