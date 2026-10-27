import 'package:flutter/material.dart';

import 'cocina_tablero_screen.dart';

/// HU-30/31: Cocina consulta los pedidos pendientes/en preparación y
/// actualiza el estado conforme va cocinando. Usa el tablero de comandas,
/// que se adapta al celular, la tablet y el monitor de la cocina.
class CocinaPedidosScreen extends StatelessWidget {
  const CocinaPedidosScreen({super.key});

  @override
  Widget build(BuildContext context) => const CocinaTableroScreen();
}
