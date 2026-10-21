import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

/// Piezas visuales compartidas por los paneles del Administrador y del
/// SuperAdmin: tarjeta de sección, gráfico de barras, barras de proporción
/// y una grilla que pasa de 1 a 2 columnas según el ancho.

/// Tarjeta de una sección del panel (título + contenido).
class PanelDashboard extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final String? subtitulo;
  final Widget child;
  final Widget? accion;

  const PanelDashboard({
    super.key,
    required this.titulo,
    required this.icono,
    required this.child,
    this.subtitulo,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
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
              Icon(icono, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  titulo,
                  style: texto.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (accion != null) accion!,
            ],
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitulo!,
              style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Grilla del panel: 1 columna en el celular, 2 en pantallas anchas.
class GrillaDashboard extends StatelessWidget {
  final List<Widget> children;
  const GrillaDashboard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < 860) {
        return Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              children[i],
            ],
          ],
        );
      }
      final filas = <Widget>[];
      for (var i = 0; i < children.length; i += 2) {
        if (i > 0) filas.add(const SizedBox(height: AppSpacing.md));
        filas.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
          ],
        ));
      }
      return Column(children: filas);
    });
  }
}

/// Gráfico de barras simple (sin librerías externas). Cada barra muestra
/// su valor arriba y su etiqueta abajo. La última barra (hoy) se resalta.
class GraficoBarras extends StatelessWidget {
  final List<double> valores;
  final List<String> etiquetas;
  final String Function(double) formato;
  final double alto;

  const GraficoBarras({
    super.key,
    required this.valores,
    required this.etiquetas,
    required this.formato,
    this.alto = 170,
  }) : assert(valores.length == etiquetas.length);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final maximo = valores.fold<double>(0, (a, b) => b > a ? b : a);
    const altoEtiqueta = 18.0;
    const altoValor = 16.0;
    final altoBarras = alto - altoEtiqueta - altoValor - AppSpacing.xs * 2;

    return SizedBox(
      height: alto,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < valores.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: altoValor,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          valores[i] > 0 ? formato(valores[i]) : '',
                          style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Tooltip(
                      message: '${etiquetas[i]}: ${formato(valores[i])}',
                      child: AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.curva,
                        height: maximo <= 0
                            ? 3
                            : (valores[i] / maximo * altoBarras).clamp(3, altoBarras).toDouble(),
                        decoration: BoxDecoration(
                          color: i == valores.length - 1
                              ? scheme.primary
                              : scheme.primary.withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      height: altoEtiqueta,
                      child: Text(
                        etiquetas[i],
                        style: texto.labelSmall?.copyWith(
                          fontWeight: i == valores.length - 1 ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lista de filas "etiqueta — valor" con una barra de proporción debajo,
/// ordenada de mayor a menor (ej. ventas por método de pago).
class ListaProporciones extends StatelessWidget {
  final Map<String, double> datos;
  final String Function(double) formato;
  final String vacio;
  final Map<String, Color>? colores;

  const ListaProporciones({
    super.key,
    required this.datos,
    required this.formato,
    this.vacio = 'Todavía no hay datos.',
    this.colores,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final entradas = datos.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entradas.isEmpty) return TextoVacio(vacio);
    final total = entradas.fold<double>(0, (a, e) => a + e.value);
    return Column(
      children: [
        for (final e in entradas)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(e.key, style: texto.bodyMedium)),
                    Text(
                      '${formato(e.value)} · ${(e.value / total * 100).round()}%',
                      style: texto.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value / total,
                    minHeight: 8,
                    color: colores?[e.key] ?? scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Texto gris para cuando todavía no hay datos.
class TextoVacio extends StatelessWidget {
  final String texto;
  const TextoVacio(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          texto,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
}

/// Mensaje de error de una sección (sin romper el resto del panel).
class TextoError extends StatelessWidget {
  final String texto;
  const TextoError(this.texto, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(texto, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}

/// Indicador de carga pequeño para dentro de una sección.
class CargandoSeccion extends StatelessWidget {
  const CargandoSeccion({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
}

/// Fila "indicador": ícono + texto + valor a la derecha (alertas y datos).
class FilaIndicador extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String texto;
  final String valor;

  const FilaIndicador({
    super.key,
    required this.icono,
    required this.color,
    required this.texto,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    final texto0 = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(icono, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto, style: texto0.bodyMedium)),
          Text(valor, style: texto0.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
