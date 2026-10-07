import 'package:flutter/material.dart';

/// Ícono según la modalidad del pedido (mesa, delivery o para recoger).
/// Se usa en las listas de pedidos de Cliente, Cajero y Cocina.
IconData iconoModalidad(String modalidad) {
  final m = modalidad.toLowerCase();
  if (m.contains('mesa')) return Icons.table_bar_outlined;
  if (m.contains('deliv') || m.contains('domic')) return Icons.delivery_dining_outlined;
  return Icons.shopping_bag_outlined;
}

/// Círculo con el ícono de la modalidad, en el color suave de la marca.
class AvatarModalidad extends StatelessWidget {
  final String modalidad;

  const AvatarModalidad({super.key, required this.modalidad});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Icon(iconoModalidad(modalidad)),
    );
  }
}
