import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Reemplaza al ScaffoldMessenger de la app para que los mensajes cortos
/// (SnackBar) aparezcan ARRIBA y no tapen botones ni texto de la parte de
/// abajo de la pantalla:
/// - en el celular, arriba y a lo ancho (con un margen),
/// - en pantallas anchas, arriba a la derecha, debajo de la barra superior.
///
/// Todo el código existente sigue igual: `ScaffoldMessenger.of(context)
/// .showSnackBar(...)`, `mensajesKey.currentState?.showSnackBar(...)`,
/// `hideCurrentSnackBar()`, etc. La cola, el tiempo en pantalla y el cierre
/// los sigue manejando Flutter; aquí solo se cambia DÓNDE se dibuja.
class MensajeroNami extends ScaffoldMessenger {
  const MensajeroNami({super.key, required super.child});

  @override
  ScaffoldMessengerState createState() => MensajeroNamiState();
}

class _Mensaje {
  final SnackBar original;
  final Key llave = UniqueKey();
  bool avisado = false;
  _Mensaje(this.original);
}

class MensajeroNamiState extends ScaffoldMessengerState {
  /// Mensajes en el mismo orden que la cola de Flutter: el primero es el
  /// que se ve.
  final List<_Mensaje> _cola = [];

  /// Ancho desde el que el mensaje va a la derecha en vez de a lo ancho.
  static const double _anchoLateral = 720;

  @override
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
    SnackBar snackBar, {
    AnimationStyle? snackBarAnimationStyle,
  }) {
    final mensaje = _Mensaje(snackBar);
    // A Flutter se le pasa un SnackBar invisible del mismo tiempo: así la
    // cola, el temporizador y `closed` funcionan como siempre, pero abajo no
    // se dibuja nada.
    final controlador = super.showSnackBar(
      SnackBar(
        content: const SizedBox.shrink(),
        duration: snackBar.duration,
        behavior: SnackBarBehavior.floating,
        width: 1,
        padding: EdgeInsets.zero,
        elevation: 0,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
        dismissDirection: DismissDirection.none,
      ),
      snackBarAnimationStyle: snackBarAnimationStyle,
    );
    setState(() => _cola.add(mensaje));
    _avisarPrimero();
    controlador.closed.whenComplete(() {
      if (!mounted) return;
      if (_cola.remove(mensaje)) setState(() {});
      _avisarPrimero();
    });
    return controlador;
  }

  /// Llama a `onVisible` del mensaje que se está viendo (una sola vez).
  void _avisarPrimero() {
    if (_cola.isEmpty || _cola.first.avisado) return;
    final m = _cola.first..avisado = true;
    final alVerse = m.original.onVisible;
    if (alVerse == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) alVerse();
    });
  }

  @override
  void clearSnackBars() {
    // Flutter descarta los que estaban en espera sin avisar por `closed`.
    if (_cola.length > 1) setState(() => _cola.removeRange(1, _cola.length));
    super.clearSnackBars();
  }

  @override
  Widget build(BuildContext context) {
    final contenido = super.build(context);
    final actual = _cola.isEmpty ? null : _cola.first;
    final medidas = MediaQuery.of(context);
    final ancho = medidas.size.width;
    final lateral = ancho >= _anchoLateral;
    final arriba =
        medidas.padding.top +
        (lateral ? kToolbarHeight + AppSpacing.sm : AppSpacing.sm);
    final sinAnimacion = medidas.disableAnimations;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        contenido,
        Positioned(
          top: arriba,
          right: AppSpacing.md + medidas.padding.right,
          left: lateral ? null : AppSpacing.md + medidas.padding.left,
          width: lateral ? 400 : null,
          child: AnimatedSwitcher(
            duration: sinAnimacion
                ? Duration.zero
                : const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: lateral
                      ? const Offset(0.15, 0)
                      : const Offset(0, -0.4),
                  end: Offset.zero,
                ).animate(animacion),
                child: hijo,
              ),
            ),
            child: actual == null
                ? const SizedBox.shrink()
                : _TarjetaMensaje(
                    key: actual.llave,
                    snackBar: actual.original,
                    alCerrar: (motivo) => hideCurrentSnackBar(reason: motivo),
                  ),
          ),
        ),
      ],
    );
  }
}

/// El mensaje en sí: una tarjeta flotante con el texto, la acción (si la
/// hay) y una X para cerrarlo.
class _TarjetaMensaje extends StatelessWidget {
  final SnackBar snackBar;
  final void Function(SnackBarClosedReason motivo) alCerrar;

  const _TarjetaMensaje({
    super.key,
    required this.snackBar,
    required this.alCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fondo = snackBar.backgroundColor ?? scheme.inverseSurface;
    final texto = ThemeData.estimateBrightnessForColor(fondo) == Brightness.dark
        ? Colors.white
        : scheme.onSurface;
    final accion = snackBar.action;
    final estiloTexto = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: texto);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: fondo,
        elevation: 6,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: DefaultTextStyle(
                      style: estiloTexto,
                      child: IconTheme(
                        data: IconThemeData(color: texto, size: 20),
                        child: snackBar.content,
                      ),
                    ),
                  ),
                ),
                if (accion != null)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor:
                          accion.textColor ?? scheme.inversePrimary,
                    ),
                    onPressed: () {
                      accion.onPressed();
                      alCerrar(SnackBarClosedReason.action);
                    },
                    child: Text(accion.label),
                  ),
                // Sin tooltip: este mensaje se dibuja encima del Navigator,
                // donde no hay Overlay para mostrarlo.
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: texto.withValues(alpha: 0.8),
                    size: 20,
                  ),
                  onPressed: () => alCerrar(SnackBarClosedReason.dismiss),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
