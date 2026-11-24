import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/admin/reclamos_screen.dart';
import '../screens/admin/resenas_screen.dart';
import '../screens/cliente/pedido_detalle_screen.dart';
import '../screens/superadmin/superadmin_solicitudes_screen.dart';
import '../services/avisos_personal_service.dart';
import '../theme/design_tokens.dart';
import '../utils/formato.dart';
import '../models/usuario_model.dart';
import 'aviso_pedidos_nuevos.dart';

IconData iconoAvisoPersonal(String tipo) => switch (tipo) {
      TipoAvisoPersonal.pedidoNuevo => Icons.receipt_long_outlined,
      TipoAvisoPersonal.pedidoListo => Icons.check_circle_outline,
      TipoAvisoPersonal.pedidoCancelado => Icons.cancel_outlined,
      TipoAvisoPersonal.entregaDisponible => Icons.delivery_dining_outlined,
      TipoAvisoPersonal.entregaAsignada => Icons.two_wheeler_outlined,
      TipoAvisoPersonal.resenaNueva => Icons.star_outline,
      TipoAvisoPersonal.reclamoNuevo => Icons.report_problem_outlined,
      TipoAvisoPersonal.solicitudNueva => Icons.storefront_outlined,
      _ => Icons.notifications_outlined,
    };

/// Abre lo que corresponde a un aviso (el pedido, las reseñas...).
void abrirAvisoPersonal(NavigatorState navigator, AvisoPersonal a) {
  final Widget pantalla = switch (a.tipo) {
    TipoAvisoPersonal.resenaNueva => const ResenasScreen(),
    TipoAvisoPersonal.reclamoNuevo => const ReclamosScreen(),
    TipoAvisoPersonal.solicitudNueva => const SuperAdminSolicitudesScreen(),
    _ => PedidoDetalleScreen(idPedido: a.idRef, esPersonal: true),
  };
  navigator.push(MaterialPageRoute(builder: (_) => pantalla));
}

/// Mientras el personal tiene la sesión abierta, junta los avisos de su
/// rol en la campanita y muestra un mensaje emergente con sonido.
class OyenteAvisosPersonal extends StatefulWidget {
  final UsuarioModel usuario;
  final Widget child;
  const OyenteAvisosPersonal({super.key, required this.usuario, required this.child});

  @override
  State<OyenteAvisosPersonal> createState() => _OyenteAvisosPersonalState();
}

class _OyenteAvisosPersonalState extends State<OyenteAvisosPersonal> {
  StreamSubscription<AvisoPersonal>? _sub;

  @override
  void initState() {
    super.initState();
    AvisosPersonalService.instancia.iniciar(widget.usuario);
    _sub = AvisosPersonalService.instancia.nuevos.listen(_mostrar);
  }

  void _mostrar(AvisoPersonal a) {
    if (!mounted) return;
    // Con la pantalla de pedidos abierta, el pedido nuevo ya lo avisa
    // ella (con su propio sonido): no se repite.
    if (a.tipo == TipoAvisoPersonal.pedidoNuevo && AvisoPedidosNuevos.abiertos > 0) return;
    AvisosPersonalService.instancia.sonar();
    final navigator = Navigator.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(iconoAvisoPersonal(a.tipo), color: Colors.white),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(a.texto)),
          ],
        ),
        action: SnackBarAction(label: 'VER', onPressed: () => abrirAvisoPersonal(navigator, a)),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    AvisosPersonalService.instancia.detener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Campanita del personal, a la derecha de la barra superior, con el
/// número de avisos sin leer. Al tocarla muestra la lista.
class CampanaAvisosPersonal extends StatelessWidget {
  final Color? color;
  const CampanaAvisosPersonal({super.key, this.color});

  void _abrir(BuildContext context) {
    final servicio = AvisosPersonalService.instancia;
    final navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      // En pantallas anchas la hoja no ocupa todo el ancho.
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.75),
        child: ValueListenableBuilder<List<AvisoPersonal>>(
          valueListenable: servicio.avisos,
          builder: (ctx, avisos, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.sm, AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Avisos',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    if (avisos.isNotEmpty)
                      TextButton(onPressed: servicio.borrarTodos, child: const Text('Borrar todo')),
                  ],
                ),
              ),
              if (avisos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 48, color: Theme.of(ctx).colorScheme.outline),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Aquí verás los avisos de tu trabajo: pedidos nuevos, cancelaciones y más.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: avisos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final a = avisos[i];
                      final scheme = Theme.of(ctx).colorScheme;
                      return ListTile(
                        tileColor: a.leido ? null : scheme.primaryContainer.withValues(alpha: 0.35),
                        leading: CircleAvatar(
                          backgroundColor: a.tipo == TipoAvisoPersonal.pedidoCancelado
                              ? scheme.errorContainer
                              : scheme.primaryContainer,
                          child: Icon(iconoAvisoPersonal(a.tipo), size: 20),
                        ),
                        title: Text(a.texto,
                            style: TextStyle(fontWeight: a.leido ? FontWeight.w400 : FontWeight.w700)),
                        subtitle: Text(formatoFechaHora(a.fecha)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          abrirAvisoPersonal(navigator, a);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    ).whenComplete(servicio.marcarTodosLeidos);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<AvisoPersonal>>(
      valueListenable: AvisosPersonalService.instancia.avisos,
      builder: (context, avisos, _) {
        final n = avisos.where((a) => !a.leido).length;
        return IconButton(
          tooltip: 'Avisos',
          onPressed: () => _abrir(context),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(n > 9 ? '9+' : '$n'),
            child: Icon(n > 0 ? Icons.notifications_active : Icons.notifications_outlined, color: color),
          ),
        );
      },
    );
  }
}
