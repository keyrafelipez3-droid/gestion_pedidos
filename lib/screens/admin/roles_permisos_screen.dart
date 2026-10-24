import 'package:flutter/material.dart';

import '../../models/actividad_model.dart';
import '../../models/permisos_negocio.dart';
import '../../models/usuario_model.dart';
import '../../services/actividad_service.dart';
import '../../services/permisos_service.dart';
import '../../services/sesion_actual.dart';
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
        'Ve los pedidos de delivery Listos de su negocio y toma el que va a entregar',
        'Comparte su ubicación en vivo con el cliente mientras va en camino',
        'Llama al cliente, avisa "Ya llegué" y marca el pedido como entregado',
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
          if (SesionActual.instancia.esAdministrador && SesionActual.instancia.idNegocio != null) ...[
            _PermisosAjustables(idNegocio: SesionActual.instancia.idNegocio!),
            const SizedBox(height: AppSpacing.md),
          ],
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

/// Interruptores para ajustar lo que pueden hacer el Cajero y la Cocina de
/// este negocio. Las reglas de Firestore los hacen cumplir en el servidor.
class _PermisosAjustables extends StatelessWidget {
  final String idNegocio;
  const _PermisosAjustables({required this.idNegocio});

  Future<void> _cambiar(BuildContext context, PermisosNegocio actual, String clave, bool valor) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final nuevos = actual.con(clave, valor);
      await PermisosService.instancia.guardar(idNegocio, nuevos);
      final titulo = PermisosNegocio.descripciones.firstWhere((d) => d.$1 == clave).$2;
      ActividadService.instancia.registrar(
        ActividadTipo.empleado,
        '${valor ? 'Activó' : 'Desactivó'} el permiso "$titulo"',
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se pudo guardar el permiso.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: StreamBuilder<PermisosNegocio>(
          stream: PermisosService.instancia.stream(idNegocio),
          builder: (context, snap) {
            final permisos = snap.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Permisos ajustables de tu negocio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Se aplican en el servidor al instante; en las pantallas del personal, '
                  'la próxima vez que inicien sesión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (permisos == null)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  for (final d in PermisosNegocio.descripciones)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(d.$2),
                      subtitle: Text(d.$3),
                      value: permisos.valor(d.$1),
                      onChanged: (v) => _cambiar(context, permisos, d.$1, v),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}
