import 'package:flutter/material.dart';

import '../../models/cliente_negocio_model.dart';
import '../../services/admin_service.dart';
import '../../services/sesion_actual.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/consulta_paginada.dart';

/// HU-04 — "Gestionar clientes".
/// Muestra a los clientes que ya hicieron pedidos en el negocio del
/// Administrador (nombre y teléfono; nunca su correo ni sus direcciones).
/// Desde aquí puede BLOQUEAR a un cliente de su negocio (por ejemplo,
/// por comentarios ofensivos o pedidos falsos) y desbloquearlo después.
/// El bloqueo vale solo en este negocio, no borra nada y es reversible.
class ClientesScreen extends StatelessWidget {
  final bool incrustada;
  const ClientesScreen({super.key, this.incrustada = false});

  static String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  void _verDetalle(BuildContext context, ClienteNegocioModel cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cliente.nombre.isEmpty ? 'Cliente' : cliente.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilaDetalle(
              icono: Icons.phone_outlined,
              texto: cliente.telefono.isEmpty ? 'Sin teléfono' : cliente.telefono,
            ),
            if (cliente.fechaPrimerPedido != null)
              _FilaDetalle(
                icono: Icons.calendar_today_outlined,
                texto: 'Primer pedido: ${_fecha(cliente.fechaPrimerPedido!)}',
              ),
            if (cliente.ultimoPedido != null)
              _FilaDetalle(
                icono: Icons.history,
                texto: 'Último pedido: ${_fecha(cliente.ultimoPedido!)}',
              ),
            if (cliente.bloqueado)
              _FilaDetalle(
                icono: Icons.block,
                texto: (cliente.motivoBloqueo ?? '').isEmpty
                    ? 'Bloqueado'
                    : 'Bloqueado: ${cliente.motivoBloqueo}',
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cambiarBloqueo(
    BuildContext context,
    String idNegocio,
    ClienteNegocioModel cliente,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final idAdmin = SesionActual.instancia.actual?.idUsuario ?? '';

    if (cliente.bloqueado) {
      await _guardar(
        messenger,
        () => AdminService.instancia.cambiarBloqueoCliente(
          idNegocio: idNegocio,
          idCliente: cliente.idUsuario,
          bloqueado: false,
          idAdmin: idAdmin,
        ),
        'Cliente desbloqueado.',
      );
      return;
    }

    final motivoCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Bloquear a ${cliente.nombre}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No podrá hacer pedidos en tu negocio hasta que lo desbloquees. '
              'En los demás negocios no se ve afectado.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: motivoCtrl,
              maxLength: 140,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    final motivo = motivoCtrl.text.trim();
    motivoCtrl.dispose();
    if (confirmado != true) return;

    await _guardar(
      messenger,
      () => AdminService.instancia.cambiarBloqueoCliente(
        idNegocio: idNegocio,
        idCliente: cliente.idUsuario,
        bloqueado: true,
        motivo: motivo,
        idAdmin: idAdmin,
      ),
      'Cliente bloqueado.',
    );
  }

  Future<void> _guardar(
    ScaffoldMessengerState messenger,
    Future<void> Function() accion,
    String mensajeOk,
  ) async {
    try {
      await accion();
      messenger.showSnackBar(SnackBar(content: Text(mensajeOk)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo guardar el cambio. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Clientes'),
      ),
      body: idNegocio == null
          ? const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Sin negocio asignado',
              message: 'Tu cuenta no está asignada a ningún negocio.',
            )
          : ConsultaPaginada<ClienteNegocioModel>(
              consulta: (n) => AdminService.instancia.streamClientesPaginado(idNegocio, n),
              builder: (context, snapshot, verMas) {
                if (!snapshot.hasData && !snapshot.hasError) {
                  return const AppCargando();
                }
                if (snapshot.hasError && !snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No se pudieron cargar los clientes. Intenta de nuevo.'),
                    ),
                  );
                }

                final clientes = snapshot.data ?? [];
                if (clientes.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'Todavía no hay clientes',
                    message: 'Aparecerán aquí cuando hagan su primer pedido en tu negocio.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: clientes.length + (verMas == null ? 0 : 1),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    if (i == clientes.length) return verMas!;
                    final c = clientes[i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(c.nombre.isEmpty ? 'Cliente' : c.nombre),
                        subtitle: Text(c.telefono.isEmpty ? 'Sin teléfono' : c.telefono),
                        onTap: () => _verDetalle(context, c),
                        trailing: Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppStatusBadge(
                              label: c.bloqueado ? 'Bloqueado' : 'Activo',
                              tone: c.bloqueado
                                  ? AppStatusTone.danger
                                  : AppStatusTone.success,
                            ),
                            TextButton(
                              onPressed: () => _cambiarBloqueo(context, idNegocio, c),
                              child: Text(c.bloqueado ? 'Desbloquear' : 'Bloquear'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _FilaDetalle extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _FilaDetalle({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icono, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
