import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pedido_models.dart';
import '../screens/cliente/pedido_detalle_screen.dart';
import '../services/pedido_service.dart';
import '../utils/sonido.dart';

/// Envuelve una pantalla del personal (Cocina, Cajero) y avisa cuando
/// entra un pedido nuevo: suena un aviso corto y aparece un mensaje con el
/// pedido y un botón para verlo.
///
/// Los pedidos que ya existían al abrir la pantalla no avisan; solo los
/// que llegan después. Se puede silenciar con el botón de la campana.
class AvisoPedidosNuevos extends StatefulWidget {
  final String idNegocio;
  final Widget child;

  const AvisoPedidosNuevos({super.key, required this.idNegocio, required this.child});

  @override
  State<AvisoPedidosNuevos> createState() => _AvisoPedidosNuevosState();
}

class _AvisoPedidosNuevosState extends State<AvisoPedidosNuevos> {
  StreamSubscription<List<PedidoModel>>? _sub;
  Set<String>? _conocidos;
  bool _silencio = false;
  int _nuevos = 0;

  @override
  void initState() {
    super.initState();
    _escuchar();
  }

  @override
  void didUpdateWidget(covariant AvisoPedidosNuevos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idNegocio != widget.idNegocio) {
      _sub?.cancel();
      _conocidos = null;
      _escuchar();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _escuchar() {
    _sub = PedidoService.instancia.streamPendientes(widget.idNegocio).listen((lista) {
      final ids = lista.map((p) => p.id).toSet();
      final conocidos = _conocidos;
      _conocidos = {...?conocidos, ...ids};
      if (conocidos == null) return; // primera carga: no avisar
      final nuevos = lista.where((p) => !conocidos.contains(p.id)).toList();
      if (nuevos.isEmpty || !mounted) return;
      setState(() => _nuevos += nuevos.length);
      if (!_silencio) sonarAvisoPedido();
      _mostrar(nuevos);
    }, onError: (_) {});
  }

  void _mostrar(List<PedidoModel> nuevos) {
    final p = nuevos.last;
    final texto = nuevos.length == 1
        ? 'Nuevo pedido #${p.id.substring(0, 6)} · ${p.etiquetaModalidad} · Bs ${p.total.toStringAsFixed(2)}'
        : '${nuevos.length} pedidos nuevos';
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(texto)),
          ],
        ),
        action: SnackBarAction(
          label: 'VER',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: 12,
          bottom: 12,
          child: Material(
            color: scheme.surfaceContainerHigh,
            shape: const StadiumBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => setState(() {
                _silencio = !_silencio;
                _nuevos = 0;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _silencio ? Icons.notifications_off_outlined : Icons.notifications_active_outlined,
                      size: 18,
                      color: _silencio ? scheme.onSurfaceVariant : scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _silencio
                          ? 'Sonido apagado'
                          : (_nuevos > 0 ? '$_nuevos nuevos' : 'Avisos activados'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
