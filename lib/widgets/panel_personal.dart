import 'package:flutter/material.dart';

import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';

/// Piezas de diseño compartidas por los paneles del personal (Cajero,
/// Cocina, Repartidor): resumen del turno, filtros en forma de píldora,
/// tarjetas con franja de color y la barra de navegación flotante.

// ------------------------------------------------------------- resumen

/// Un número del resumen del turno ("7 · pedidos pendientes").
class DatoTurno {
  final String valor;
  final String etiqueta;
  final IconData? icono;

  /// Color del número. Si es null se usa el color de la marca.
  final Color? color;

  const DatoTurno(this.valor, this.etiqueta, {this.icono, this.color});
}

/// Fila de números grandes arriba de cada panel. En pantallas anchas van
/// en una sola fila; en el celular, de a dos.
class ResumenTurno extends StatelessWidget {
  final List<DatoTurno> datos;

  const ResumenTurno({super.key, required this.datos});

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        const gap = AppSpacing.sm + 4;
        final porFila = c.maxWidth >= 700 ? datos.length : 2;
        final ancho = (c.maxWidth - gap * (porFila - 1)) / porFila;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final d in datos)
              SizedBox(width: ancho, child: _TarjetaDato(dato: d, compacta: c.maxWidth < 700)),
          ],
        );
      },
    );
  }
}

class _TarjetaDato extends StatelessWidget {
  final DatoTurno dato;
  final bool compacta;

  const _TarjetaDato({required this.dato, required this.compacta});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compacta ? AppSpacing.md - 4 : AppSpacing.md + 2,
        vertical: compacta ? AppSpacing.sm + 2 : AppSpacing.md - 2,
      ),
      decoration: context.brand.decoracionTarjeta(scheme),
      child: Row(
        children: [
          if (dato.icono != null) ...[
            Icon(dato.icono, size: compacta ? 20 : 24, color: dato.color ?? scheme.primary),
            const SizedBox(width: AppSpacing.sm + 2),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dato.valor,
                    maxLines: 1,
                    style: (compacta ? textos.titleLarge : textos.headlineSmall)?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: dato.color ?? scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  dato.etiqueta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- píldoras

/// Una opción de [PildorasFiltro].
class OpcionPildora<T> {
  final T valor;
  final String etiqueta;
  final int? contador;
  final IconData? icono;

  const OpcionPildora(this.valor, this.etiqueta, {this.contador, this.icono});
}

/// Filtros en forma de píldora con contador ("Nuevos 3"), con
/// desplazamiento horizontal si no entran.
class PildorasFiltro<T> extends StatelessWidget {
  final List<OpcionPildora<T>> opciones;
  final T seleccion;
  final ValueChanged<T> onChanged;
  final EdgeInsetsGeometry padding;

  const PildorasFiltro({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onChanged,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final o in opciones) ...[
            Pildora(
              etiqueta: o.contador == null ? o.etiqueta : '${o.etiqueta}  ${o.contador}',
              icono: o.icono,
              seleccionada: o.valor == seleccion,
              onTap: () => onChanged(o.valor),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
        ],
      ),
    );
  }
}

/// Botón en forma de píldora: relleno con el color de la marca si está
/// seleccionado.
class Pildora extends StatelessWidget {
  final String etiqueta;
  final IconData? icono;
  final bool seleccionada;
  final VoidCallback? onTap;

  const Pildora({
    super.key,
    required this.etiqueta,
    this.icono,
    this.seleccionada = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fondo = seleccionada ? scheme.primary : scheme.surfaceContainerHigh;
    final texto = seleccionada ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: fondo,
        shape: StadiumBorder(
          side: BorderSide(color: seleccionada ? fondo : scheme.outlineVariant),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2, vertical: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 16, color: texto),
                  const SizedBox(width: 6),
                ],
                Text(
                  etiqueta,
                  style: TextStyle(
                    color: texto,
                    fontWeight: seleccionada ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- etiquetas

/// Etiqueta pequeña de color (estado, modalidad, forma de pago).
class EtiquetaPanel extends StatelessWidget {
  final String texto;
  final IconData? icono;

  /// Color del texto. El fondo es el mismo color, transparente.
  final Color? color;

  const EtiquetaPanel(this.texto, {super.key, this.icono, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color == null ? scheme.surfaceContainerHighest : c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto con un ícono delante, en el color secundario ("hace 5 min").
class DatoConIcono extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color? color;
  final bool negrita;

  const DatoConIcono(this.icono, this.texto, {super.key, this.color, this.negrita = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: c),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: c,
              fontSize: 13,
              fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- tarjeta

/// Tarjeta del panel: usa el estilo de tarjeta de la marca y, si se pide,
/// una franja de color a la izquierda (por ejemplo, roja si hay alergias).
class TarjetaPanel extends StatelessWidget {
  final Widget child;
  final Color? franja;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const TarjetaPanel({
    super.key,
    required this.child,
    this.franja,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md - 2),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brand = context.brand;
    final decoracion = brand.decoracionTarjeta(scheme);
    return Container(
      decoration: decoracion,
      child: ClipRRect(
        borderRadius: brand.card,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: franja == null
                  ? null
                  : BoxDecoration(border: Border(left: BorderSide(color: franja!, width: 5))),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de una sección o columna con su contador ("NUEVOS  3").
class TituloColumna extends StatelessWidget {
  final String titulo;
  final int? contador;
  final Color? color;
  final Widget? accion;

  const TituloColumna(this.titulo, {super.key, this.contador, this.color, this.accion});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.xs, AppSpacing.xs, AppSpacing.sm + 2),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              titulo.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 13),
            ),
          ),
          if (contador != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$contador', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
          const Spacer(),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}

// ------------------------------------------------- navegación del panel

/// Una sección del panel de un rol (Pedidos, Mesas, Caja...).
class DestinoPanel {
  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
  final WidgetBuilder builder;

  const DestinoPanel({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    required this.builder,
  });
}

/// Panel de un rol con varias secciones: en el celular, una barra
/// flotante en forma de píldora abajo; en pantallas anchas, una barra
/// lateral. Cada sección se construye recién la primera vez que se abre
/// y después se mantiene (no vuelve a cargar al cambiar de sección).
class PanelConNavegacion extends StatefulWidget {
  final List<DestinoPanel> destinos;
  final int indiceInicial;

  const PanelConNavegacion({super.key, required this.destinos, this.indiceInicial = 0});

  /// Cambia de sección desde una pantalla que está dentro del panel (por
  /// ejemplo, ir a "En camino" después de tomar una entrega).
  static void irA(BuildContext context, int indice) =>
      context.findAncestorStateOfType<_PanelConNavegacionState>()?._ir(indice);

  @override
  State<PanelConNavegacion> createState() => _PanelConNavegacionState();
}

class _PanelConNavegacionState extends State<PanelConNavegacion> {
  late int _indice = widget.indiceInicial < 0 || widget.indiceInicial >= widget.destinos.length
      ? 0
      : widget.indiceInicial;
  late final Set<int> _visitados = {_indice};

  void _ir(int i) {
    if (i < 0 || i >= widget.destinos.length) return;
    setState(() {
      _indice = i;
      _visitados.add(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final contenido = IndexedStack(
      index: _indice,
      children: [
        for (var i = 0; i < widget.destinos.length; i++)
          _visitados.contains(i) ? widget.destinos[i].builder(context) : const SizedBox.shrink(),
      ],
    );
    if (ancho >= AppBreakpoints.expanded) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _indice,
              onDestinationSelected: _ir,
              labelType: NavigationRailLabelType.all,
              backgroundColor: scheme.surfaceContainerLow,
              destinations: [
                for (final d in widget.destinos)
                  NavigationRailDestination(
                    icon: Icon(d.icono),
                    selectedIcon: Icon(d.iconoActivo),
                    label: Text(d.etiqueta),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(child: contenido),
          ],
        ),
      );
    }
    return Scaffold(
      body: contenido,
      bottomNavigationBar: BarraPildora(
        destinos: widget.destinos,
        indice: _indice,
        onChanged: _ir,
      ),
    );
  }
}

/// Barra de navegación flotante en forma de píldora (celular).
class BarraPildora extends StatelessWidget {
  final List<DestinoPanel> destinos;
  final int indice;
  final ValueChanged<int> onChanged;

  const BarraPildora({super.key, required this.destinos, required this.indice, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm + 2),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs + 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinos.length; i++)
                Expanded(
                  child: _ItemPildora(
                    destino: destinos[i],
                    activo: i == indice,
                    onTap: () => onChanged(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemPildora extends StatelessWidget {
  final DestinoPanel destino;
  final bool activo;
  final VoidCallback onTap;

  const _ItemPildora({required this.destino, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = activo ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: activo,
      label: destino.etiqueta,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.normal,
          curve: AppMotion.curva,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: activo ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(activo ? destino.iconoActivo : destino.icono, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                destino.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: activo ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
