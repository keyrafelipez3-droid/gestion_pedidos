import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contacto.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';

/// Panel del Repartidor: pedidos de delivery listos para llevar y las
/// entregas que ya tiene en curso. Desde acá toma un pedido, avisa "ya
/// llegué" y lo marca como entregado; también puede llamar al cliente.
class RepartidorEntregasScreen extends StatelessWidget {
  const RepartidorEntregasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = SesionActual.instancia;
    final idNegocio = sesion.idNegocio;
    final usuario = sesion.actual;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis entregas'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Disponibles'),
              Tab(text: 'En curso'),
            ],
          ),
        ),
        body: (idNegocio == null || usuario == null)
            ? const Center(child: Text('No se pudo identificar tu negocio.'))
            : TabBarView(
                children: [
                  _ListaEntregas(
                    stream: PedidoService.instancia.streamEntregasDisponibles(
                      idNegocio,
                      idSucursal: usuario.idSucursal,
                    ),
                    vacioTitulo: 'No hay pedidos para repartir',
                    vacioMensaje:
                        'Cuando la cocina deje un pedido de delivery listo, va a aparecer acá.',
                    disponible: true,
                  ),
                  _ListaEntregas(
                    stream: PedidoService.instancia
                        .streamMisEntregas(idNegocio, usuario.idUsuario),
                    vacioTitulo: 'No tienes entregas en curso',
                    vacioMensaje: 'Toma un pedido de la pestaña "Disponibles" para empezar.',
                    disponible: false,
                  ),
                ],
              ),
      ),
    );
  }
}

class _ListaEntregas extends StatelessWidget {
  final Stream<List<PedidoModel>> stream;
  final String vacioTitulo;
  final String vacioMensaje;
  final bool disponible;

  const _ListaEntregas({
    required this.stream,
    required this.vacioTitulo,
    required this.vacioMensaje,
    required this.disponible,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('No se pudieron cargar los pedidos: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pedidos = snapshot.data!;
        if (pedidos.isEmpty) {
          return AppEmptyState(
            icon: Icons.delivery_dining_outlined,
            title: vacioTitulo,
            message: vacioMensaje,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: pedidos.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, i) => _TarjetaEntrega(
            key: ValueKey(pedidos[i].id),
            pedido: pedidos[i],
            disponible: disponible,
          ),
        );
      },
    );
  }
}

class _TarjetaEntrega extends StatefulWidget {
  final PedidoModel pedido;
  final bool disponible;

  const _TarjetaEntrega({super.key, required this.pedido, required this.disponible});

  @override
  State<_TarjetaEntrega> createState() => _TarjetaEntregaState();
}

class _TarjetaEntregaState extends State<_TarjetaEntrega> {
  bool _ocupado = false;

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    setState(() => _ocupado = true);
    try {
      await accion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      if (!mounted) return;
      final texto = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar: $texto')),
      );
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final usuario = SesionActual.instancia.actual;
    final textos = Theme.of(context).textTheme;
    final direccion = (p.direccionEntrega?['direccion'] as String?) ?? '';
    final referencia = (p.direccionEntrega?['referencia'] as String?) ?? '';
    final etiqueta = (p.direccionEntrega?['etiqueta'] as String?) ?? '';
    final cobraEnPuerta = p.metodoPago == MetodoPago.efectivo;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${p.id.substring(0, 6)}',
                  style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                AppStatusBadge(
                  label: p.estado,
                  tone: p.estado == PedidoEstado.listo
                      ? AppStatusTone.neutral
                      : AppStatusTone.warning,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Linea(
              icono: Icons.place_outlined,
              texto: direccion.isEmpty
                  ? 'Sin dirección registrada'
                  : (etiqueta.isEmpty ? direccion : '$etiqueta · $direccion'),
            ),
            if (referencia.isNotEmpty)
              _Linea(icono: Icons.info_outline, texto: 'Referencia: $referencia'),
            if ((p.nombreCliente ?? '').isNotEmpty)
              _Linea(icono: Icons.person_outline, texto: p.nombreCliente!),
            if (p.notas.isNotEmpty)
              _Linea(icono: Icons.sticky_note_2_outlined, texto: 'Nota: ${p.notas}'),
            _Linea(
              icono: Icons.payments_outlined,
              texto: cobraEnPuerta
                  ? 'Cobrar en efectivo: Bs ${p.total.toStringAsFixed(2)}'
                  : 'Pago: ${p.metodoPago} · Total Bs ${p.total.toStringAsFixed(2)}',
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.disponible)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_ocupado || usuario == null)
                      ? null
                      : () => _ejecutar(
                            () => PedidoService.instancia.tomarEntrega(
                              idPedido: p.id,
                              idRepartidor: usuario.idUsuario,
                              nombreRepartidor: usuario.nombre,
                              telefonoRepartidor: usuario.telefono,
                            ),
                            'Tomaste el pedido. ¡Buen viaje!',
                          ),
                  icon: const Icon(Icons.two_wheeler_outlined),
                  label: const Text('Tomar entrega'),
                ),
              )
            else ...[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => llamarPorTelefono(context, p.telefonoCliente),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Llamar al cliente'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => abrirEnMapas(
                      context,
                      direccion,
                      latitud: (p.direccionEntrega?['latitud'] as num?)?.toDouble(),
                      longitud: (p.direccionEntrega?['longitud'] as num?)?.toDouble(),
                    ),
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Ver en el mapa'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: p.estado == PedidoEstado.enCamino
                    ? FilledButton.icon(
                        onPressed: (_ocupado || usuario == null)
                            ? null
                            : () => _ejecutar(
                                  () => PedidoService.instancia.avisarLlegada(
                                    idPedido: p.id,
                                    idRepartidor: usuario.idUsuario,
                                  ),
                                  'Le avisamos al cliente que ya llegaste.',
                                ),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Ya llegué'),
                      )
                    : FilledButton.icon(
                        onPressed: (_ocupado || usuario == null)
                            ? null
                            : () => _ejecutar(
                                  () => PedidoService.instancia.entregarPedido(
                                    idPedido: p.id,
                                    idRepartidor: usuario.idUsuario,
                                  ),
                                  'Pedido entregado.',
                                ),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Marcar como entregado'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Linea({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
