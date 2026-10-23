import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/actividad_model.dart';
import '../../models/usuario_model.dart';
import '../../utils/formato.dart';
import '../../services/actividad_service.dart';
import '../../services/admin_service.dart';
import '../../services/sesion_actual.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/confirmar_identidad.dart';
import '../../widgets/app_status_badge.dart';
import 'crear_empleado_screen.dart';
import 'roles_permisos_screen.dart';
import '../../widgets/app_cargando.dart';

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
        children: Rol.staffOperativo
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
      if (!context.mounted) return;
      if (!await confirmarIdentidad(context, accion: 'cambiar el rol de ${empleado.nombre}')) return;
      await AdminService.instancia.cambiarRol(empleado.idUsuario, nuevoRol);
      ActividadService.instancia.registrar(
        ActividadTipo.empleado,
        'Cambió el rol de ${empleado.nombre} de ${empleado.rol} a $nuevoRol',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol actualizado a $nuevoRol')),
        );
      }
    }
  }

  /// Activar o desactivar a un empleado (pide confirmar identidad).
  Future<void> _cambiarEstado(BuildContext context, UsuarioModel e, bool activo) async {
    final accion = activo ? 'activar a ${e.nombre}' : 'desactivar a ${e.nombre}';
    if (!await confirmarIdentidad(context, accion: accion)) return;
    await AdminService.instancia.cambiarEstado(e.idUsuario, activo);
    ActividadService.instancia.registrar(
      ActividadTipo.empleado,
      '${activo ? 'Activó' : 'Desactivó'} la cuenta de ${e.nombre} (${e.rol})',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Empleados'),
        actions: [
          // La referencia de permisos por rol vive acá, donde se asignan
          // los roles, en vez de ocupar un ítem propio en el menú.
          IconButton(
            tooltip: 'Ver permisos de cada rol',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RolesPermisosScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<UsuarioModel>>(
        stream: AdminService.instancia.streamEmpleados(SesionActual.instancia.idNegocio!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppCargando();
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
              // No se permite que un Administrador se desactive o se
              // cambie el rol a sí mismo: si lo hiciera quedaría fuera
              // del panel de inmediato (y, en el caso del rol, sin forma
              // de revertirlo él mismo — solo un SuperAdmin podría). Para
              // eso tiene que pedírselo a otro Administrador o al
              // SuperAdmin.
              final esUnoMismo = e.idUsuario == SesionActual.instancia.actual?.idUsuario;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      e.nombre.isNotEmpty ? e.nombre[0].toUpperCase() : '?',
                    ),
                  ),
                  title: Text(esUnoMismo ? '${e.nombre} (Tú)' : e.nombre),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(e.email),
                        AppStatusBadge(label: e.rol, tone: AppStatusTone.neutral),
                        if (e.rol != Rol.superAdmin)
                          Tooltip(
                            message: e.acuerdo == null
                                ? 'Todavía no firmó el acuerdo del personal. Se le pedirá al entrar.'
                                : 'Firmado por ${e.acuerdo!.nombre} (CI ${e.acuerdo!.ci})'
                                    '${e.acuerdo!.fecha == null ? '' : ' el ${formatoFechaHora(e.acuerdo!.fecha!)}'}'
                                    ' · versión ${e.acuerdo!.version}',
                            child: AppStatusBadge(
                              label: e.acuerdo == null
                                  ? 'Acuerdo pendiente'
                                  : e.acuerdo!.version == AppConfig.versionAcuerdoPersonal
                                      ? 'Acuerdo firmado'
                                      : 'Acuerdo desactualizado',
                              tone: e.acuerdo?.version == AppConfig.versionAcuerdoPersonal
                                  ? AppStatusTone.success
                                  : AppStatusTone.warning,
                            ),
                          ),
                      ],
                    ),
                  ),
                  onTap: () {
                    if (esUnoMismo) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No puedes cambiar tu propio rol. Pídele a otro '
                            'Administrador o al SuperAdmin que lo haga.',
                          ),
                        ),
                      );
                      return;
                    }
                    _cambiarRol(context, e);
                  },
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
                        onChanged: (v) {
                          if (esUnoMismo) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No puedes desactivar tu propia cuenta. '
                                  'Pídele a otro Administrador o al SuperAdmin '
                                  'que lo haga.',
                                ),
                              ),
                            );
                            return;
                          }
                          _cambiarEstado(context, e, v);
                        },
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
