import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../utils/firma_trazos.dart';

/// Recuadro para firmar con el dedo (celular) o con el mouse (web).
/// Cada vez que cambia la firma llama a [alCambiar] con el texto de los
/// trazos, o con null si está vacía o es muy corta.
class PanelFirma extends StatefulWidget {
  final ValueChanged<String?> alCambiar;
  const PanelFirma({super.key, required this.alCambiar});

  @override
  State<PanelFirma> createState() => _PanelFirmaState();
}

class _PanelFirmaState extends State<PanelFirma> {
  final _trazos = <List<Offset>>[];
  double _escala = 1;

  // Pasa el punto de la pantalla al recuadro de 300 x 120.
  Offset _aRecuadro(Offset local) => Offset(local.dx * _escala, local.dy * _escala);

  void _avisar() {
    final texto = FirmaTrazos.aTexto(_trazos);
    widget.alCambiar(FirmaTrazos.esValida(texto) ? texto : null);
  }

  void _borrar() {
    setState(() => _trazos.clear());
    widget.alCambiar(null);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Firma aquí con el dedo o el mouse *',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            TextButton.icon(
              onPressed: _trazos.isEmpty ? null : _borrar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Borrar'),
            ),
          ],
        ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: AspectRatio(
              aspectRatio: FirmaTrazos.ancho / FirmaTrazos.alto,
              child: LayoutBuilder(
                builder: (context, medidas) {
                  _escala = FirmaTrazos.ancho / medidas.maxWidth;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: scheme.outline),
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: RawGestureDetector(
                      // Gana el gesto apenas se toca el recuadro, para que al
                      // firmar no se mueva la pantalla.
                      gestures: {
                        _ArrastreFirma: GestureRecognizerFactoryWithHandlers<_ArrastreFirma>(
                          () => _ArrastreFirma(),
                          (r) {
                            r.onStart = (d) {
                              setState(() => _trazos.add([_aRecuadro(d.localPosition)]));
                            };
                            r.onUpdate = (d) {
                              setState(() => _trazos.last.add(_aRecuadro(d.localPosition)));
                            };
                            r.onEnd = (_) => _avisar();
                          },
                        ),
                      },
                      child: CustomPaint(
                        painter: _PintorFirma(_trazos, Colors.black87),
                        size: Size.infinite,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Muestra una firma ya guardada.
class VistaFirma extends StatelessWidget {
  final String texto;
  final double ancho;
  const VistaFirma({super.key, required this.texto, this.ancho = 180});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ancho,
      height: ancho * FirmaTrazos.alto / FirmaTrazos.ancho,
      child: CustomPaint(
        painter: _PintorFirma(FirmaTrazos.desdeTexto(texto), Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}

/// Reconocedor de arrastre que gana enseguida (si no, al firmar hacia
/// arriba o abajo la pantalla se desplazaría en lugar de dibujar).
class _ArrastreFirma extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Dibuja los trazos (que vienen en el recuadro de 300 x 120) al tamaño real.
class _PintorFirma extends CustomPainter {
  final List<List<Offset>> trazos;
  final Color color;
  _PintorFirma(this.trazos, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.width / FirmaTrazos.ancho;
    final pincel = Paint()
      ..color = color
      ..strokeWidth = 2.5 * escala.clamp(0.6, 2)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final trazo in trazos) {
      if (trazo.isEmpty) continue;
      final camino = Path()..moveTo(trazo.first.dx * escala, trazo.first.dy * escala);
      for (final p in trazo.skip(1)) {
        camino.lineTo(p.dx * escala, p.dy * escala);
      }
      canvas.drawPath(camino, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
