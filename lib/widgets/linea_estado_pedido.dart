import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/pedido_models.dart';
import '../theme/design_tokens.dart';

/// Línea de progreso del pedido (Recibido → Preparando → Listo → [En
/// camino] → Entregado). Se calcula solo con el estado real del pedido.
class LineaEstadoPedido extends StatelessWidget {
  final PedidoModel pedido;
  const LineaEstadoPedido({super.key, required this.pedido});

  List<String> get _pasos => pedido.esDelivery
      ? [tr('Recibido'), tr('Preparando'), tr('Listo'), tr('En camino'), tr('Entregado')]
      : [tr('Recibido'), tr('Preparando'), tr('Listo'), tr('Entregado')];

  int get _actual {
    final ultimo = _pasos.length - 1;
    switch (pedido.estado) {
      case PedidoEstado.pendiente:
        return 0;
      case PedidoEstado.enPreparacion:
        return 1;
      case PedidoEstado.listo:
        return 2;
      case PedidoEstado.enCamino:
      case PedidoEstado.llego:
        return pedido.esDelivery ? 3 : 2;
      case PedidoEstado.entregado:
        return ultimo;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pasos = _pasos;
    final actual = _actual;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < pasos.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= actual ? scheme.primary : scheme.outlineVariant),
                      ),
                    ),
                    AnimatedContainer(
                      duration: AppMotion.normal,
                      curve: AppMotion.curva,
                      width: i == actual ? 30 : 24,
                      height: i == actual ? 30 : 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= actual ? scheme.primary : scheme.surfaceContainerHigh,
                        border: Border.all(
                          color: i <= actual ? scheme.primary : scheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: i < actual || (i == actual && i == pasos.length - 1)
                          ? Icon(Icons.check, size: 14, color: scheme.onPrimary)
                          : null,
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == pasos.length - 1
                            ? Colors.transparent
                            : (i < actual ? scheme.primary : scheme.outlineVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pasos[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: i == actual ? FontWeight.w700 : FontWeight.w500,
                        color: i <= actual ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
