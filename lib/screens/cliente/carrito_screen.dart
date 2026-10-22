import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/carrito_models.dart';
import '../../models/negocio_model.dart';
import '../../services/carrito_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_imagen_red.dart';
import 'checkout_screen.dart';

/// HU-20/22/23: revisar el carrito, editar cantidades, quitar items y
/// ver el total antes de pasar al checkout.
class CarritoScreen extends StatelessWidget {
  final NegocioModel negocio;
  final String idSucursal;

  const CarritoScreen({super.key, required this.negocio, required this.idSucursal});

  String get _uid => SesionActual.instancia.actual!.idUsuario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Tu carrito'))),
      body: AppContenidoCentrado(child: StreamBuilder<List<CarritoItemModel>>(
        stream: CarritoService.instancia.streamCarrito(_uid, negocio.idNegocio),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.shopping_cart_outlined,
              title: tr('Tu carrito está vacío'),
              message: tr('Vuelve al menú y agrega algún producto.'),
            );
          }
          final total = CarritoService.instancia.calcularTotal(items);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _TarjetaItemCarrito(uid: _uid, item: items[i]),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr('Total'), style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            tr('Bs {total}', {'total': total.toStringAsFixed(2)}),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CheckoutScreen(
                                negocio: negocio,
                                idSucursal: idSucursal,
                                items: items,
                              ),
                            ),
                          ),
                          child: Text(tr('Continuar')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      )),
    );
  }
}

class _TarjetaItemCarrito extends StatelessWidget {
  final String uid;
  final CarritoItemModel item;

  const _TarjetaItemCarrito({required this.uid, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: AppImagenRed(url: item.imagenUrl, width: 64, height: 64),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nombreProducto,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (item.variantes.isNotEmpty || item.complementos.isNotEmpty)
                    Text(
                      [...item.variantes, ...item.complementos].map((o) => o.nombre).join(', '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (item.notas.isNotEmpty)
                    Text(tr('Nota: {notas}', {'notas': item.notas}), style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    tr('Bs {subtotal}', {'subtotal': item.subtotal.toStringAsFixed(2)}),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      item.cantidad <= 1 ? Icons.delete_outline : Icons.remove,
                    ),
                    onPressed: () => item.cantidad <= 1
                        ? CarritoService.instancia.eliminarItem(uid, item.id)
                        : CarritoService.instancia
                            .actualizarCantidad(uid, item.id, item.cantidad - 1),
                  ),
                  Text(
                    '${item.cantidad}',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.add),
                    onPressed: () => CarritoService.instancia
                        .actualizarCantidad(uid, item.id, item.cantidad + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
