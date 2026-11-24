import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Construye el contenido de un panel lateral. [cerrar] lo cierra (sirve
/// igual en pantalla ancha y en el celular).
typedef ConstructorPanel = Widget Function(BuildContext context, VoidCallback cerrar);

/// Ancho del panel lateral (los avisos).
const double anchoPanelLateral = 380;

class _Panel {
  final Object id;
  final ConstructorPanel constructor;
  final VoidCallback? alCerrar;
  const _Panel(this.id, this.constructor, this.alCerrar);
}

final ValueNotifier<_Panel?> _panelAbierto = ValueNotifier<_Panel?>(null);

/// Abre un panel a la DERECHA de la pantalla (por ejemplo, los avisos de la
/// campanita):
/// - en pantallas anchas (computadora) el panel queda fijo a la derecha y
///   el resto de la pantalla se corre hacia la izquierda, sin taparse;
/// - en el celular o una ventana chica, el panel se desliza desde la
///   derecha por encima, y se cierra tocando afuera o con "atrás".
///
/// Si ya hay un panel abierto con el mismo [id], lo cierra (la campanita
/// funciona como interruptor). [alCerrar] se llama una vez al cerrarse.
void abrirPanelLateral(
  BuildContext context, {
  required Object id,
  required ConstructorPanel constructor,
  VoidCallback? alCerrar,
}) {
  final actual = _panelAbierto.value;
  if (actual != null) {
    cerrarPanelLateral();
    if (actual.id == id) return;
  }
  final ancho = MediaQuery.sizeOf(context).width;
  if (ancho >= AppBreakpoints.expanded && AnfitrionPanelLateral._montados > 0) {
    _panelAbierto.value = _Panel(id, constructor, alCerrar);
    return;
  }
  final etiqueta = MaterialLocalizations.of(context).modalBarrierDismissLabel;
  final sinAnimacion = MediaQuery.disableAnimationsOf(context);
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: etiqueta,
    barrierColor: Colors.black38,
    transitionDuration: sinAnimacion ? Duration.zero : const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, __) {
      final w = MediaQuery.sizeOf(ctx).width;
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: SizedBox(
          // Deja una franja a la izquierda para tocar afuera y cerrar.
          width: math.min(anchoPanelLateral + 40, w - 48),
          height: double.infinity,
          child: _MarcoPanel(child: constructor(ctx, () => Navigator.of(ctx).pop())),
        ),
      );
    },
    transitionBuilder: (ctx, animacion, _, hijo) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animacion, curve: Curves.easeOutCubic)),
      child: hijo,
    ),
  ).whenComplete(() => alCerrar?.call());
}

/// Cierra el panel fijo de la derecha, si hay uno abierto. Si se pasa [id],
/// solo lo cierra cuando es ese panel.
void cerrarPanelLateral({Object? id}) {
  final actual = _panelAbierto.value;
  if (actual == null || (id != null && actual.id != id)) return;
  _panelAbierto.value = null;
  actual.alCerrar?.call();
}

/// Si hay un panel fijo abierto con ese [id].
bool panelLateralAbierto(Object id) => _panelAbierto.value?.id == id;

/// Va en el `builder` de MaterialApp, alrededor del Navigator. Reserva a la
/// derecha el espacio del panel fijo cuando hay uno abierto; el resto de la
/// app se dibuja en el espacio que queda (y recibe ese ancho en MediaQuery,
/// así sus diseños responsivos se acomodan solos).
class AnfitrionPanelLateral extends StatefulWidget {
  final Widget child;
  const AnfitrionPanelLateral({super.key, required this.child});

  static int _montados = 0;

  @override
  State<AnfitrionPanelLateral> createState() => _AnfitrionPanelLateralState();
}

class _AnfitrionPanelLateralState extends State<AnfitrionPanelLateral> {
  _Panel? _ultimo;

  @override
  void initState() {
    super.initState();
    AnfitrionPanelLateral._montados++;
    _panelAbierto.addListener(_alCambiar);
  }

  @override
  void dispose() {
    AnfitrionPanelLateral._montados--;
    _panelAbierto.removeListener(_alCambiar);
    super.dispose();
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {
      if (_panelAbierto.value != null) _ultimo = _panelAbierto.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    final abierto = _panelAbierto.value != null;
    // Si la ventana se achica con el panel abierto, se cierra.
    if (abierto && medidas.size.width < AppBreakpoints.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => cerrarPanelLateral());
    }
    final ultimo = _ultimo;
    final sinAnimacion = medidas.disableAnimations;

    // La estructura (Row > Expanded > ...) es siempre la misma, abierto o
    // cerrado, para que el Navigator no pierda sus pantallas al abrir.
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, restricciones) => MediaQuery(
              data: medidas.copyWith(
                size: restricciones.biggest,
                padding: abierto ? medidas.padding.copyWith(right: 0) : medidas.padding,
                viewPadding: abierto ? medidas.viewPadding.copyWith(right: 0) : medidas.viewPadding,
              ),
              child: widget.child,
            ),
          ),
        ),
        AnimatedContainer(
          duration: sinAnimacion ? Duration.zero : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: abierto ? anchoPanelLateral : 0,
          onEnd: () {
            if (!abierto && mounted) setState(() => _ultimo = null);
          },
          child: ultimo == null
              ? const SizedBox.shrink()
              : ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: anchoPanelLateral,
                    maxWidth: anchoPanelLateral,
                    child: _MarcoPanel(
                      fijo: true,
                      child: Builder(builder: (ctx) => ultimo.constructor(ctx, cerrarPanelLateral)),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Fondo y borde del panel: una hoja clara pegada al borde derecho.
class _MarcoPanel extends StatelessWidget {
  final Widget child;
  final bool fijo;
  const _MarcoPanel({required this.child, this.fijo = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      elevation: fijo ? 0 : 8,
      shape: fijo
          ? Border(left: BorderSide(color: scheme.outlineVariant))
          : const RoundedRectangleBorder(
              borderRadius: BorderRadiusDirectional.horizontal(start: Radius.circular(20)),
            ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(left: false, child: child),
    );
  }
}

/// Encabezado común de un panel lateral: título, acciones y botón cerrar.
class EncabezadoPanelLateral extends StatelessWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> acciones;
  final VoidCallback cerrar;

  const EncabezadoPanelLateral({
    super.key,
    required this.titulo,
    required this.icono,
    required this.cerrar,
    this.acciones = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.lg, AppSpacing.md, AppSpacing.xs, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, size: 20, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              titulo,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ...acciones,
          // Sin tooltip: en pantalla ancha el panel está fuera del Navigator
          // (no hay Overlay donde mostrarlo).
          Semantics(
            button: true,
            label: MaterialLocalizations.of(context).closeButtonLabel,
            child: IconButton(
              onPressed: cerrar,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
