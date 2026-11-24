import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/pedido_models.dart';
import '../screens/cliente/pedido_detalle_screen.dart';
import '../services/avisos_service.dart';
import '../theme/design_tokens.dart';
import '../utils/formato.dart';
import '../utils/navegacion.dart';
import 'panel_lateral.dart';

/// Escucha los cambios de estado de los pedidos del cliente mientras usa
/// la app y muestra un mensaje emergente con el botón "Ver".
class OyenteAvisos extends StatefulWidget {
  final String uid;
  final Widget child;
  const OyenteAvisos({super.key, required this.uid, required this.child});

  @override
  State<OyenteAvisos> createState() => _OyenteAvisosState();
}

class _OyenteAvisosState extends State<OyenteAvisos> {
  StreamSubscription<Aviso>? _sub;

  @override
  void initState() {
    super.initState();
    AvisosService.instancia.iniciar(widget.uid);
    _sub = AvisosService.instancia.nuevos.listen(_mostrar);
  }

  void _mostrar(Aviso a) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(iconoAviso(a.estado), color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(a.texto)),
          ],
        ),
        action: SnackBarAction(
          label: tr('VER'),
          onPressed: () => navigator.push(
            MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: a.idPedido)),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    AvisosService.instancia.detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

IconData iconoAviso(String estado) => switch (estado) {
      PedidoEstado.enPreparacion => Icons.soup_kitchen_outlined,
      PedidoEstado.listo => Icons.check_circle_outline,
      PedidoEstado.enCamino => Icons.delivery_dining_outlined,
      PedidoEstado.llego => Icons.location_on_outlined,
      PedidoEstado.entregado => Icons.celebration_outlined,
      PedidoEstado.cancelado => Icons.cancel_outlined,
      _ => Icons.notifications_outlined,
    };

/// Campanita con el número de avisos sin leer. Al tocarla abre la lista en
/// un panel a la derecha (ver abrirPanelLateral).
class CampanaAvisos extends StatefulWidget {
  final Color? color;
  const CampanaAvisos({super.key, this.color});

  @override
  State<CampanaAvisos> createState() => _CampanaAvisosState();
}

class _CampanaAvisosState extends State<CampanaAvisos> {
  static const _id = 'avisos-cliente';

  @override
  void dispose() {
    // Al salir (por ejemplo, al cerrar sesión) no queda el panel abierto.
    cerrarPanelLateral(id: _id);
    super.dispose();
  }

  void _abrir(BuildContext context) {
    final servicio = AvisosService.instancia;
    abrirPanelLateral(
      context,
      id: _id,
      alCerrar: servicio.marcarTodosLeidos,
      constructor: (ctx, cerrar) => ValueListenableBuilder<List<Aviso>>(
        valueListenable: servicio.avisos,
        builder: (ctx, avisos, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoPanelLateral(
              titulo: tr('Avisos'),
              icono: Icons.notifications_outlined,
              cerrar: cerrar,
              acciones: [
                if (avisos.isNotEmpty)
                  TextButton(onPressed: servicio.borrarTodos, child: Text(tr('Borrar todo'))),
              ],
            ),
            const Divider(height: 1),
            if (avisos.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: Theme.of(ctx).colorScheme.outline),
                        const SizedBox(height: AppSpacing.sm),
                        Text(tr('Aquí verás cuando tu pedido cambie de estado.'), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemCount: avisos.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final a = avisos[i];
                    final scheme = Theme.of(ctx).colorScheme;
                    return ListTile(
                      tileColor: a.leido ? null : scheme.primaryContainer.withValues(alpha: 0.35),
                      leading: CircleAvatar(
                        backgroundColor: a.estado == PedidoEstado.cancelado
                            ? scheme.errorContainer
                            : scheme.primaryContainer,
                        child: Icon(iconoAviso(a.estado), size: 20),
                      ),
                      title: Text(a.texto, style: TextStyle(fontWeight: a.leido ? FontWeight.w400 : FontWeight.w700)),
                      subtitle: Text(formatoFechaHora(a.fecha)),
                      onTap: () {
                        cerrar();
                        navigatorKey.currentState?.push(
                          MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: a.idPedido)),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Aviso>>(
      valueListenable: AvisosService.instancia.avisos,
      builder: (context, avisos, _) {
        final n = avisos.where((a) => !a.leido).length;
        return IconButton(
          tooltip: tr('Avisos'),
          onPressed: () => _abrir(context),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n > 9 ? '9+' : '$n'),
            child: Icon(n > 0 ? Icons.notifications_active : Icons.notifications_outlined, color: widget.color),
          ),
        );
      },
    );
  }
}
