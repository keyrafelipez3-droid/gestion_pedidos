import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../widgets/panel_personal.dart';
import 'cajero_caja_screen.dart';
import 'cajero_mesas_screen.dart';
import 'cajero_pedidos_screen.dart';
import 'cajero_rendicion_screen.dart';

/// Panel del Cajero: Pedidos, Mesas, Caja y Rendición en un solo lugar,
/// con la barra flotante abajo (celular) o la barra lateral (pantalla
/// ancha). Cambiar de sección no vuelve a cargar las otras.
class PanelCajero extends StatelessWidget {
  static const pedidos = 0;
  static const mesas = 1;
  static const caja = 2;
  static const rendicion = 3;

  final int seccion;

  const PanelCajero({super.key, this.seccion = pedidos});

  @override
  Widget build(BuildContext context) {
    return PanelConNavegacion(
      indiceInicial: seccion,
      destinos: [
        DestinoPanel(
          icono: Icons.receipt_long_outlined,
          iconoActivo: Icons.receipt_long,
          etiqueta: tr('Pedidos'),
          builder: (_) => const CajeroPedidosScreen(),
        ),
        DestinoPanel(
          icono: Icons.table_restaurant_outlined,
          iconoActivo: Icons.table_restaurant,
          etiqueta: tr('Mesas'),
          builder: (_) => const CajeroMesasScreen(),
        ),
        DestinoPanel(
          icono: Icons.point_of_sale_outlined,
          iconoActivo: Icons.point_of_sale,
          etiqueta: tr('Caja'),
          builder: (_) => const CajeroCajaScreen(),
        ),
        DestinoPanel(
          icono: Icons.two_wheeler_outlined,
          iconoActivo: Icons.two_wheeler,
          etiqueta: tr('Rendición'),
          builder: (_) => const CajeroRendicionScreen(),
        ),
      ],
    );
  }
}
