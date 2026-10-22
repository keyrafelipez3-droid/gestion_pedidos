import 'package:flutter/material.dart';

/// Calificación de 1 a 5 estrellas, solo para mostrar.
class Estrellas extends StatelessWidget {
  final double valor;
  final double tamano;

  const Estrellas({super.key, required this.valor, this.tamano = 18});

  @override
  Widget build(BuildContext context) {
    final color = Colors.amber.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            valor >= i
                ? Icons.star_rounded
                : (valor >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
            size: tamano,
            color: color,
          ),
      ],
    );
  }
}

/// Selector táctil de estrellas (1 a 5).
class SelectorEstrellas extends StatelessWidget {
  final int valor;
  final ValueChanged<int> onChanged;

  const SelectorEstrellas({super.key, required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final color = Colors.amber.shade700;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
            iconSize: 36,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: Icon(
              valor >= i ? Icons.star_rounded : Icons.star_outline_rounded,
              color: color,
            ),
            onPressed: () => onChanged(i),
          ),
      ],
    );
  }
}
