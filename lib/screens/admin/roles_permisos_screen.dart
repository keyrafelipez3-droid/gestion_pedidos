import 'package:flutter/material.dart';

import '../../models/usuario_model.dart';
import '../../theme/design_tokens.dart';

/// HU-03 — "Definir roles y permisos".
///
/// Los 5 roles del sistema (Cliente, Administrador, Cajero, Cocina,
/// Repartidor) son fijos por diseño y sus permisos ya están aplicados en el
/// servidor mediante las reglas de seguridad de Firestore (no en la app, que
/// se podría manipular). Esta pantalla es la referencia visual para que el
/// Administrador vea, en un solo lugar, qué puede hacer cada rol — no tiene
/// botón de "guardar" porque no se edita nada: cambiar un permiso real
/// implica editar `firestore.rules` en el proyecto de Firebase.
class RolesPermisosScreen extends StatelessWidget {
  final bool incrustada;
  const RolesPermisosScreen({super.key, this.incrustada = false});

  static const List<_RolInfo> _roles = [
    _RolInfo(
      rol: Rol.superAdmin,
      icono: Icons.workspace_premium_outlined,
      color: Colors.indigo,
      descripcion: 'Gestiona TODOS los negocios del sistema (multi-tenant).',
      permisos: [
        'Crea negocios nuevos y personaliza cada uno (logo, colores, banner)',
        'Edita los datos generales de cualquier negocio',
        'Designa al Administrador de cada negocio',
        'No gestiona la operación diaria de ningún negocio en particular',
      ],
    ),
    _RolInfo(
      rol: Rol.administrador,
      icono: Icons.admin_panel_settings,
      color: Colors.deepPurple,
      descripcion: 'Control total de SU negocio (asignado por el SuperAdmin).',
      permisos: [
        'Gestiona empleados de su negocio: crea cuentas y asigna sus roles (HU-05)',
        'Gestiona clientes registrados (HU-04)',
        'Configura sucursales y horarios de su negocio (HU-08, HU-09)',
        'Administra el catálogo de su negocio: categorías, productos, extras, variantes',
        'Crea promociones, cupones y combos',
        'Ve el historial completo de pedidos y puede eliminarlos',
        'Consulta ventas, caja y reportes',
      ],
    ),
    _RolInfo(
      rol: Rol.cajero,
      icono: Icons.point_of_sale,
      color: Colors.teal,
      descripcion: 'Atención en caja y mesas de la sucursal.',
      permisos: [
        'Gestiona mesas y pedidos tomados en mesa',
        'Abre, mueve y cierra la caja de su turno',
        'Ve y actualiza el estado de los pedidos',
      ],
    ),
    _RolInfo(
      rol: Rol.cocina,
      icono: Icons.soup_kitchen,
      color: Colors.orange,
      descripcion: 'Preparación de pedidos.',
      permisos: [
        'Consulta los pedidos pendientes de preparar',
        'Actualiza el estado de preparación del pedido',
      ],
    ),
    _RolInfo(
      rol: Rol.repartidor,
      icono: Icons.delivery_dining,
      color: Colors.blueGrey,
      descripcion: 'Entrega de pedidos a domicilio.',
      permisos: [
        'Consulta los pedidos de delivery que le fueron asignados',
        'Actualiza el estado básico de la entrega',
      ],
    ),
    _RolInfo(
      rol: Rol.cliente,
      icono: Icons.person,
      color: Colors.deepOrange,
      descripcion: 'Cualquier persona que se registra desde la app.',
      permisos: [
        'Gestiona su propio perfil, direcciones y favoritos',
        'Arma su carrito y confirma pedidos',
        'Consulta el estado y el historial de sus propios pedidos',
        'Ve el catálogo público del negocio',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Roles y permisos'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primary.withValues(alpha: 0.15),
                    foregroundColor: scheme.primary,
                    child: const Icon(Icons.info_outline),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Expanded(
                    child: Text(
                      'Los permisos de cada rol se aplican automáticamente '
                      'en Firestore (reglas de seguridad); esta pantalla es '
                      'de referencia, no editable.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final r in _roles) _TarjetaRol(info: r),
        ],
      ),
    );
  }
}

class _RolInfo {
  final String rol;
  final IconData icono;
  final Color color;
  final String descripcion;
  final List<String> permisos;

  const _RolInfo({
    required this.rol,
    required this.icono,
    required this.color,
    required this.descripcion,
    required this.permisos,
  });
}

class _TarjetaRol extends StatelessWidget {
  final _RolInfo info;

  const _TarjetaRol({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: info.color.withValues(alpha: 0.15),
                  foregroundColor: info.color,
                  child: Icon(info.icono),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.rol,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        info.descripcion,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final permiso in info.permisos)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 16, color: info.color),
                    const SizedBox(width: AppSpacing.xs + 4),
                    Expanded(child: Text(permiso)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
