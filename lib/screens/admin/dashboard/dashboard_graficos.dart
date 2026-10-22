import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

// ---------------------------------------------------------------------------
// Periodo del panel
// ---------------------------------------------------------------------------

/// Periodo que muestra el panel. Todas las métricas se comparan con el
/// periodo anterior de la misma duración (hoy vs ayer, 7 días vs los 7
/// anteriores, 30 días vs los 30 anteriores).
enum PeriodoDashboard {
  hoy('Hoy', 1, 'ayer'),
  semana('7 días', 7, 'los 7 días anteriores'),
  mes('30 días', 30, 'los 30 días anteriores');

  const PeriodoDashboard(this.etiqueta, this.dias, this.comparacion);
  final String etiqueta;
  final int dias;

  /// Texto para "frente a ...".
  final String comparacion;

  /// [inicio, fin) del periodo actual, donde [hoy] es el inicio del día.
  (DateTime, DateTime) rango(DateTime hoy) =>
      (hoy.subtract(Duration(days: dias - 1)), hoy.add(const Duration(days: 1)));

  /// [inicio, fin) del periodo anterior.
  (DateTime, DateTime) rangoAnterior(DateTime hoy) {
    final (inicio, _) = rango(hoy);
    return (inicio.subtract(Duration(days: dias)), inicio);
  }
}

/// Botones Hoy / 7 días / 30 días.
class SelectorPeriodo extends StatelessWidget {
  final PeriodoDashboard valor;
  final ValueChanged<PeriodoDashboard> onChanged;
  const SelectorPeriodo({super.key, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PeriodoDashboard>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      segments: [
        for (final p in PeriodoDashboard.values) ButtonSegment(value: p, label: Text(p.etiqueta)),
      ],
      selected: {valor},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ---------------------------------------------------------------------------
// Tarjeta KPI con tendencia y minigráfico
// ---------------------------------------------------------------------------

/// Indicador principal: valor grande, variación frente al periodo anterior
/// (▲ verde / ▼ rojo) y un minigráfico de la evolución.
class KpiCard extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String etiqueta;
  final String? valor;

  /// Variación porcentual frente al periodo anterior (null = sin comparación).
  final double? variacion;

  /// Si es true, subir es malo (ej. cancelaciones): ▲ en rojo.
  final bool subirEsMalo;
  final String? detalle;
  final List<double>? serie;
  final double ancho;

  const KpiCard({
    super.key,
    required this.icono,
    required this.color,
    required this.etiqueta,
    required this.valor,
    this.variacion,
    this.subirEsMalo = false,
    this.detalle,
    this.serie,
    this.ancho = 228,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;
    final v = variacion;
    Color? colorVariacion;
    if (v != null && v.abs() >= 0.5) {
      final bueno = subirEsMalo ? v < 0 : v > 0;
      colorVariacion = bueno ? semantic.success : scheme.error;
    }

    return Container(
      width: ancho,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icono, color: color, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  etiqueta,
                  style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (v != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (colorVariacion ?? scheme.onSurfaceVariant).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    v.abs() < 0.5 ? '= 0%' : '${v > 0 ? '▲' : '▼'} ${v.abs().toStringAsFixed(0)}%',
                    style: texto.labelSmall?.copyWith(
                      color: colorVariacion ?? scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedSwitcher(
            duration: AppMotion.normal,
            child: Text(
              valor ?? '—',
              key: ValueKey(valor),
              style: texto.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (detalle != null)
            Text(
              detalle!,
              style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (serie != null && serie!.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 32,
              width: double.infinity,
              child: CustomPaint(painter: _SparklinePainter(serie!, color)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> valores;
  final Color color;
  _SparklinePainter(this.valores, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final maximo = valores.fold<double>(0, math.max);
    final puntos = <Offset>[
      for (var i = 0; i < valores.length; i++)
        Offset(
          size.width * i / (valores.length - 1),
          maximo <= 0 ? size.height - 1 : size.height - (valores[i] / maximo) * (size.height - 2) - 1,
        ),
    ];
    final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      linea.lineTo(p.dx, p.dy);
    }
    final area = Path.from(linea)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(puntos.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.valores != valores || old.color != color;
}

// ---------------------------------------------------------------------------
// Gráfico de área (evolución de ventas)
// ---------------------------------------------------------------------------

/// Gráfico de área con línea suave, cuadrícula, eje de valores y etiquetas.
/// Al pasar el mouse (o tocar) muestra el valor de cada punto.
class GraficoArea extends StatefulWidget {
  final List<double> valores;
  final List<String> etiquetas;
  final String Function(double) formato;

  /// Cada cuántos puntos se muestra una etiqueta del eje X.
  final int cadaEtiqueta;
  final double alto;

  const GraficoArea({
    super.key,
    required this.valores,
    required this.etiquetas,
    required this.formato,
    this.cadaEtiqueta = 1,
    this.alto = 220,
  }) : assert(valores.length == etiquetas.length);

  @override
  State<GraficoArea> createState() => _GraficoAreaState();
}

class _GraficoAreaState extends State<GraficoArea> {
  int? _seleccion;

  int? _indiceEn(double x, double anchoUtil, double izquierda) {
    final n = widget.valores.length;
    if (n == 0) return null;
    if (n == 1) return 0;
    final rel = ((x - izquierda) / anchoUtil).clamp(0.0, 1.0).toDouble();
    return (rel * (n - 1)).round();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    const izquierda = 52.0;
    return SizedBox(
      height: widget.alto,
      child: LayoutBuilder(builder: (context, c) {
        final anchoUtil = c.maxWidth - izquierda - 8;
        return MouseRegion(
          onHover: (e) => setState(() => _seleccion = _indiceEn(e.localPosition.dx, anchoUtil, izquierda)),
          onExit: (_) => setState(() => _seleccion = null),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => setState(() => _seleccion = _indiceEn(d.localPosition.dx, anchoUtil, izquierda)),
            onHorizontalDragUpdate: (d) =>
                setState(() => _seleccion = _indiceEn(d.localPosition.dx, anchoUtil, izquierda)),
            child: CustomPaint(
              size: Size(c.maxWidth, widget.alto),
              painter: _AreaPainter(
                valores: widget.valores,
                etiquetas: widget.etiquetas,
                formato: widget.formato,
                cadaEtiqueta: widget.cadaEtiqueta,
                color: scheme.primary,
                colorTexto: scheme.onSurfaceVariant,
                colorRejilla: scheme.outlineVariant,
                colorFondoTooltip: scheme.inverseSurface,
                colorTextoTooltip: scheme.onInverseSurface,
                estiloTexto: texto.labelSmall ?? const TextStyle(fontSize: 11),
                seleccion: _seleccion,
                izquierda: izquierda,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _AreaPainter extends CustomPainter {
  final List<double> valores;
  final List<String> etiquetas;
  final String Function(double) formato;
  final int cadaEtiqueta;
  final Color color;
  final Color colorTexto;
  final Color colorRejilla;
  final Color colorFondoTooltip;
  final Color colorTextoTooltip;
  final TextStyle estiloTexto;
  final int? seleccion;
  final double izquierda;

  _AreaPainter({
    required this.valores,
    required this.etiquetas,
    required this.formato,
    required this.cadaEtiqueta,
    required this.color,
    required this.colorTexto,
    required this.colorRejilla,
    required this.colorFondoTooltip,
    required this.colorTextoTooltip,
    required this.estiloTexto,
    required this.seleccion,
    required this.izquierda,
  });

  /// Redondea el máximo hacia arriba a un número "lindo" (1, 2, 5 × 10^n).
  double _techo(double v) {
    if (v <= 0) return 1;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (m * exp >= v) return m * exp;
    }
    return 10 * exp;
  }

  void _texto(Canvas canvas, String s, Offset pos, {TextAlign align = TextAlign.left, Color? color, double? maxW}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: estiloTexto.copyWith(color: color ?? colorTexto)),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxW ?? 200);
    var dx = pos.dx;
    if (align == TextAlign.center) dx -= tp.width / 2;
    if (align == TextAlign.right) dx -= tp.width;
    tp.paint(canvas, Offset(dx, pos.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    const abajo = 22.0;
    const arriba = 10.0;
    final derecha = size.width - 8;
    final alto = size.height - abajo - arriba;
    final techo = _techo(valores.fold<double>(0, math.max));

    // Cuadrícula y eje Y (4 líneas).
    final rejilla = Paint()
      ..color = colorRejilla
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = arriba + alto - alto * i / 4;
      canvas.drawLine(Offset(izquierda, y), Offset(derecha, y), rejilla);
      _texto(canvas, formato(techo * i / 4), Offset(izquierda - 6, y), align: TextAlign.right);
    }

    final n = valores.length;
    double x(int i) => n == 1 ? (izquierda + derecha) / 2 : izquierda + (derecha - izquierda) * i / (n - 1);
    double y(double v) => arriba + alto - (v / techo) * alto;
    final puntos = [for (var i = 0; i < n; i++) Offset(x(i), y(valores[i]))];

    // Línea suave (curva) y área con degradé.
    final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (var i = 1; i < puntos.length; i++) {
      final p0 = puntos[i - 1];
      final p1 = puntos[i];
      final cx = (p0.dx + p1.dx) / 2;
      linea.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    final area = Path.from(linea)
      ..lineTo(puntos.last.dx, arriba + alto)
      ..lineTo(puntos.first.dx, arriba + alto)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTWH(0, arriba, size.width, alto)),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Puntos (solo si son pocos) y etiquetas del eje X.
    for (var i = 0; i < n; i++) {
      if (n <= 31) {
        canvas.drawCircle(puntos[i], 3, Paint()..color = color);
        canvas.drawCircle(puntos[i], 1.6, Paint()..color = Colors.white);
      }
      if (i % cadaEtiqueta == 0 || i == n - 1) {
        _texto(canvas, etiquetas[i], Offset(puntos[i].dx, size.height - abajo / 2), align: TextAlign.center);
      }
    }

    // Tooltip del punto seleccionado.
    final s = seleccion;
    if (s != null && s >= 0 && s < n) {
      final p = puntos[s];
      canvas.drawLine(
        Offset(p.dx, arriba),
        Offset(p.dx, arriba + alto),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(p, 6, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(p, 4, Paint()..color = color);
      final etiqueta = '${etiquetas[s]}: ${formato(valores[s])}';
      final tp = TextPainter(
        text: TextSpan(
          text: etiqueta,
          style: estiloTexto.copyWith(color: colorTextoTooltip, fontWeight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final ancho = tp.width + 16;
      final caja = Rect.fromLTWH(
        (p.dx - ancho / 2).clamp(izquierda, math.max(izquierda, derecha - ancho)).toDouble(),
        math.max(0.0, p.dy - 34),
        ancho,
        tp.height + 10,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(caja, const Radius.circular(8)), Paint()..color = colorFondoTooltip);
      tp.paint(canvas, Offset(caja.left + 8, caja.top + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.valores != valores || old.seleccion != seleccion || old.color != color || old.etiquetas != etiquetas;
}
