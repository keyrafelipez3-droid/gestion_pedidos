import 'package:flutter/material.dart';

/// Botón que ejecuta una acción asíncrona y se bloquea mientras corre,
/// para evitar toques dobles (que duplicarían cobros o cambios de estado).
class BotonAccion extends StatefulWidget {
  final String texto;
  final Future<void> Function() onPressed;
  final bool expandido;

  const BotonAccion({
    super.key,
    required this.texto,
    required this.onPressed,
    this.expandido = false,
  });

  @override
  State<BotonAccion> createState() => _BotonAccionState();
}

class _BotonAccionState extends State<BotonAccion> {
  bool _ocupado = false;

  Future<void> _ejecutar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final boton = FilledButton(
      onPressed: _ocupado ? null : _ejecutar,
      child: _ocupado
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(widget.texto),
    );
    return widget.expandido ? SizedBox(width: double.infinity, child: boton) : boton;
  }
}
