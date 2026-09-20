import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../services/admin_service.dart';
import 'crear_empleado_screen.dart';

/// HU-05 — "Gestionar empleados y asignar roles".
/// Lista en tiempo real de todo el personal (no Clientes), con acciones
/// para activar/desactivar la cuenta y cambiar el rol asignado.
class EmpleadosScreen extends StatelessWidget {
  const EmpleadosScreen({super.key});

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
              (r) => RadioListTile<String>(
                title: Text(r),
                value: r,
                // ignore: deprecated_member_use
                groupValue: empleado.rol,
                onChanged: (v) => Navigator.of(context).pop(v),
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
      appBar: AppBar(title: const Text('Empleados')),
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Todavía no hay empleados registrados.\n'
                  'Toca "+" para crear el primero.',
                  textAlign: TextAlign.center,
                ),
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
                  subtitle: Text('${e.email}\n${e.rol}'),
                  isThreeLine: true,
                  onTap: () => _cambiarRol(context, e),
                  trailing: Switch(
                    value: e.estado,
                    onChanged: (v) =>
                        AdminService.instancia.cambiarEstado(e.idUsuario, v),
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
