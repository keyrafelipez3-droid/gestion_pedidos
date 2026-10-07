import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/app_cargando.dart';

/// HU-04 — "Gestionar clientes registrados".
/// Los clientes se registran solos desde la app (HU-01); aquí el
/// Administrador solo puede CONSULTARLOS y activar/desactivar su cuenta
/// (por ejemplo, ante un caso de abuso) — no crea ni edita sus datos.
class ClientesScreen extends StatelessWidget {
  final bool incrustada;
  const ClientesScreen({super.key, this.incrustada = false});

  void _verDetalle(BuildContext context, UsuarioModel cliente) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cliente.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FilaDetalle(icono: Icons.email_outlined, texto: cliente.email),
            _FilaDetalle(icono: Icons.phone_outlined, texto: cliente.telefono),
            _FilaDetalle(
              icono: Icons.calendar_today_outlined,
              texto: cliente.fechaRegistro != null
                  ? 'Registrado el ${_formatearFecha(cliente.fechaRegistro!)}'
                  : 'Fecha de registro no disponible',
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

  String _formatearFecha(DateTime f) {
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Clientes'),
      ),
      body: StreamBuilder<List<UsuarioModel>>(
        stream: AdminService.instancia.streamClientes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppCargando();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar clientes: ${snapshot.error}'),
              ),
            );
          }

          final clientes = snapshot.data ?? [];
          if (clientes.isEmpty) {
            return const AppEmptyState(
              icon: Icons.people_outline,
              title: 'Todavía no hay clientes registrados',
              message: 'Aparecerán aquí en cuanto alguien se registre desde la app.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: clientes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = clientes[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      c.nombre.isNotEmpty ? c.nombre[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(c.nombre),
                  subtitle: Text(c.email),
                  onTap: () => _verDetalle(context, c),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(
                        label: c.estado ? 'Activo' : 'Inactivo',
                        tone: c.estado ? AppStatusTone.success : AppStatusTone.neutral,
                      ),
                      Switch(
                        value: c.estado,
                        onChanged: (v) =>
                            AdminService.instancia.cambiarEstado(c.idUsuario, v),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icono, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
