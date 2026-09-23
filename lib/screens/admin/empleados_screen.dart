import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import 'crear_empleado_screen.dart';

/// HU-05 — "Gestionar empleados y asignar roles".
/// Lista en tiempo real de todo el personal (no Clientes), con acciones
/// para activar/desactivar la cuenta y cambiar el rol asignado.
class EmpleadosScreen extends StatelessWidget {
  final bool incrustada;
  const EmpleadosScreen({super.key, this.incrustada = false});

  Future<void> _cambiarRol(
    BuildContext context,
    UsuarioModel empleado,
  ) async {
    final nuevoRol = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Rol de ${empleado.nombre}'),
        children: Rol.staff
            .map(
              (r) => ListTile(
                leading: Icon(
                  r == empleado.rol
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(r),
                trailing: r == empleado.rol ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(r),
              ),
            )
            .toList(),
      ),
    );

    if (nuevoRol != null && nuevoRol != empleado.rol) {
      await AdminService.instancia.cambiarRol(empleado.idUsuario, nuevoRol);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol actualizado a $nuevoRol')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Empleados'),
      ),
      body: StreamBuilder<List<UsuarioModel>>(
        stream: AdminService.instancia.streamEmpleados(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error al cargar empleados: ${snapshot.error}'),
              ),
            );
          }

          final empleados = snapshot.data ?? [];
          if (empleados.isEmpty) {
            return AppEmptyState(
              icon: Icons.badge_outlined,
              title: 'Todavía no hay empleados registrados',
              message: 'Crea el primero para asignarle un rol dentro del negocio.',
              actionLabel: 'Nuevo empleado',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CrearEmpleadoScreen()),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: empleados.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final e = empleados[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      e.nombre.isNotEmpty ? e.nombre[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(e.nombre),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(e.email),
                        AppStatusBadge(label: e.rol, tone: AppStatusTone.neutral),
                      ],
                    ),
                  ),
                  onTap: () => _cambiarRol(context, e),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(
                        label: e.estado ? 'Activo' : 'Inactivo',
                        tone: e.estado ? AppStatusTone.success : AppStatusTone.neutral,
                      ),
                      Switch(
                        value: e.estado,
                        onChanged: (v) =>
                            AdminService.instancia.cambiarEstado(e.idUsuario, v),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CrearEmpleadoScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo empleado'),
      ),
    );
  }
}
