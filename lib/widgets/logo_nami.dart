import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/app_theme_controller.dart';
import '../theme/design_tokens.dart';

/// Logo de la marca Nami: un plato hondo color locoto con tres hilos de
/// vapor en ají amarillo, dibujado en vector (así se ve nítido en cualquier
/// tamaño). Es el mismo logo a cualquier hora del día.
class LogoNami extends StatelessWidget {
  final double size;

  /// false = solo el plato y el vapor, sin el círculo berenjena de fondo
  /// (para ponerlo sobre un fondo que ya es oscuro).
  final bool conFondo;

  const LogoNami({super.key, this.size = 96, this.conFondo = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo de ${AppBrand.nombre}',
      image: true,
      child: _plato(),
    );
  }

  Widget _plato() => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoNamiPainter(conFondo: conFondo)),
      );
}

class _LogoNamiPainter extends CustomPainter {
  final bool conFondo;
  const _LogoNamiPainter({required this.conFondo});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    Offset p(double x, double y) => Offset(s * x, s * y);

    if (conFondo) {
      canvas.drawCircle(p(0.5, 0.5), s / 2, Paint()..color = AppBrand.berenjena);
    }

    // Plato: medio círculo hacia abajo y un borde redondeado arriba.
    final plato = Paint()
      ..color = AppBrand.locoto
      ..isAntiAlias = true;
    canvas.drawArc(
      Rect.fromCircle(center: p(0.5, 0.55), radius: s * 0.32),
      0,
      math.pi,
      true,
      plato,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromPoints(p(0.14, 0.515), p(0.86, 0.585)),
        Radius.circular(s * 0.035),
      ),
      plato,
    );

    // Vapor: tres curvas en "S", la del medio más alta.
    final vapor = Paint()
      ..color = AppBrand.aji
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (final (x, arriba) in const [(0.36, 0.26), (0.50, 0.18), (0.64, 0.26)]) {
      final camino = Path()
        ..moveTo(s * x, s * 0.45)
        ..cubicTo(
          s * (x + 0.07), s * 0.39,
          s * (x - 0.07), s * (arriba + 0.07),
          s * x, s * arriba,
        );
      canvas.drawPath(camino, vapor);
    }
  }

  @override
  bool shouldRepaint(covariant _LogoNamiPainter old) => old.conFondo != conFondo;
}

/// Nombre de la marca escrito como logotipo: "nami" en minúsculas, grueso
/// y apretado, con el punto de la "i" reemplazado por una gota de ají.
/// Es el elemento más reconocible de la marca; se usa en el login, la
/// pantalla de carga y el panel lateral.
class WordmarkNami extends StatelessWidget {
  final double alto;
  final Color? color;

  const WordmarkNami({super.key, this.alto = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final tinta = color ?? Theme.of(context).colorScheme.onSurface;
    // Siempre con la letra de la marca (aunque el restaurante haya elegido
    // otra tipografía): es un logotipo, no un título más.
    var estilo = TextStyle(
      fontSize: alto,
      height: 1.0,
      fontWeight: FontWeight.w800,
      letterSpacing: -alto * 0.045,
      color: tinta,
    );
    if (AppThemeController.usarFuentesDeGoogle) {
      try {
        estilo = GoogleFonts.getFont(AppBrand.fuenteTitulos, textStyle: estilo);
      } catch (_) {
        // Sin la fuente de Google se usa la del sistema.
      }
    }
    return Semantics(
      label: AppBrand.nombre,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('nam', style: estilo),
          // "ı" sin punto + gota de ají encima, en lugar del punto.
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Text('ı', style: estilo),
              Positioned(
                top: alto * 0.06,
                child: Container(
                  width: alto * 0.2,
                  height: alto * 0.2,
                  decoration: const BoxDecoration(
                    color: AppBrand.aji,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
