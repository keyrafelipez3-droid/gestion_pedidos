import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../models/usuario_model.dart';
import '../../services/admin_service.dart';
import '../../services/app_theme_controller.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_status_badge.dart';
import '../admin/crear_empleado_screen.dart';
import '../admin/negocio_screen.dart';
import '../admin/personalizacion_screen.dart';

/// Detalle de UN negocio, visto por el SuperAdmin: activar/desactivar,
/// entrar a personalizarlo o editar sus datos, y designar/gestionar sus
/// Administradores. Corrección pedida por el docente.
class SuperAdminNegocioDetalleScreen extends StatefulWidget {
  final NegocioModel negocio;
  const SuperAdminNegocioDetalleScreen({super.key, required this.negocio});

  @override
  State<SuperAdminNegocioDetalleScreen> createState() =>
      _SuperAdminNegocioDetalleScreenState();
}

class _SuperAdminNegocioDetalleScreenState
    extends State<SuperAdminNegocioDetalleScreen> {
  late bool _activo = widget.negocio.estado;

  /// Las pantallas de Personalización/Datos del negocio actualizan el
  /// tema global en vivo (para que el SuperAdmin vea el efecto mientras
  /// edita) — al volver, se limpia para no dejar la app del SuperAdmin
  /// "pintada" con los colores del negocio que acaba de visitar.
  Future<void> _abrir(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    AppThemeController.instancia.limpiar();
  }

  @override
  Widget build(BuildContext context) {
    final negocio = widget.negocio;
    return Scaffold(
      appBar: AppBar(title: Text(negocio.nombre.isEmpty ? 'Negocio' : negocio.nombre)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Negocio activo'),
              subtitle: const Text('Si lo desactivas, deja de operar en la app'),
              value: _activo,
              onChanged: (v) {
                setState(() => _activo = v);
                NegocioService.instancia.cambiarEstadoNegocio(negocio.idNegocio, v);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Personalización'),
                  subtitle: const Text('Logo, colores, banner, modo claro/oscuro'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrir(PersonalizacionScreen(idNegocio: negocio.idNegocio)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storefront_outlined),
                  title: const Text('Datos del negocio'),
                  subtitle: const Text('Nombre, descripción, teléfono'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrir(NegocioScreen(idNegocio: negocio.idNegocio)),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Administradores asignados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Asignar'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CrearEmpleadoScreen(
                      rolFijo: Rol.administrador,
                      idNegocioFijo: negocio.idNegocio,
                    ),
                  ),
                ),
              ),
            ],
          ),
          StreamBuilder<List<UsuarioModel>>(
            stream: AdminService.instancia.streamAdministradoresDeNegocio(negocio.idNegocio),
            builder: (context, snapshot) {
              final admins = snapshot.data ?? [];
              if (admins.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text('Todavía no hay un Administrador asignado a este negocio.'),
                );
              }
              return Column(
                children: admins.map((a) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(a.nombre.isNotEmpty ? a.nombre[0].toUpperCase() : '?'),
                      ),
                      title: Text(a.nombre),
                      subtitle: Text(a.email),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppStatusBadge(
                            label: a.estado ? 'Activo' : 'Inactivo',
                            tone: a.estado ? AppStatusTone.success : AppStatusTone.neutral,
                          ),
                          Switch(
                            value: a.estado,
                            onChanged: (v) =>
                                AdminService.instancia.cambiarEstado(a.idUsuario, v),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
