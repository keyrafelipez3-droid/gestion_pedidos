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
    final sinAnimacion = medidas.disableAnimations;
    final duracion =
        sinAnimacion ? Duration.zero : const Duration(milliseconds: 220);
    final fondo = Theme.of(context).scaffoldBackgroundColor;

    // El mensaje NO flota encima de la pantalla: ocupa su propia franja
    // arriba y empuja el contenido hacia abajo mientras se ve, así nunca
    // tapa un texto, una tarjeta o un botón. Al cerrarse, la franja se
    // achica y todo vuelve a su lugar.
    //
    // El árbol es siempre el mismo (Column + MediaQuery) para que las
    // pantallas no se reconstruyan desde cero al aparecer un mensaje.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: actual == null ? Colors.transparent : fondo,
          child: AnimatedSize(
            duration: duracion,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: duracion,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (hijo, animacion) =>
                  FadeTransition(opacity: animacion, child: hijo),
              child: actual == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      key: actual.llave,
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md + medidas.padding.left,
                        medidas.padding.top + AppSpacing.sm,
                        AppSpacing.md + medidas.padding.right,
                        AppSpacing.sm,
                      ),
                      child: Align(
                        alignment: lateral
                            ? AlignmentDirectional.centerEnd
                            : Alignment.center,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: lateral ? 480 : double.infinity,
                          ),
                          child: _TarjetaMensaje(
                            snackBar: actual.original,
                            alCerrar: (motivo) =>
                                hideCurrentSnackBar(reason: motivo),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Expanded(
          child: MediaQuery(
            // La franja ya ocupa la barra de estado del celular.
            data: actual == null
                ? medidas
                : medidas.copyWith(
                    padding: medidas.padding.copyWith(top: 0),
                    viewPadding: medidas.viewPadding.copyWith(top: 0),
                  ),
            child: contenido,
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
    required this.snackBar,
    required this.alCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Siempre fondo blanco y letras negras: se lee bien en cualquier tema,
    // claro u oscuro. El color del aviso (error, éxito) va en la franja de
    // la izquierda y en el ícono, no en el fondo.
    const fondo = Colors.white;
    const texto = Color(0xFF111111);
    final colorPedido = snackBar.backgroundColor;
    final esError = colorPedido != null && colorPedido == scheme.error;
    // Rojo o verde oscuros: se distinguen bien sobre el blanco.
    final Color? acento = colorPedido == null
        ? null
        : esError
            ? const Color(0xFFC62828)
            : const Color(0xFF2E7D32);
    final accion = snackBar.action;
    final estiloTexto = (theme.textTheme.bodyMedium ?? const TextStyle())
        .copyWith(color: texto, fontWeight: FontWeight.w600, height: 1.3);

    return Semantics(
      container: true,
      liveRegion: true,
      child: Material(
        color: fondo,
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x33000000)),
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: acento == null
                ? null
                : BorderDirectional(
                    start: BorderSide(color: acento, width: 6),
                  ),
          ),
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
                if (acento != null) ...[
                  Icon(
                    esError ? Icons.error_outline : Icons.check_circle_outline,
                    color: acento,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
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
                      foregroundColor: texto,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
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
                    color: texto.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: () => alCerrar(SnackBarClosedReason.dismiss),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
