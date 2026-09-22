import 'package:flutter/material.dart';

import 'catalogo_screen.dart';
import 'clientes_screen.dart';
import 'empleados_screen.dart';
import 'negocio_screen.dart';
import 'roles_permisos_screen.dart';
import 'sucursales_screen.dart';

/// Panel de administración: punto de entrada a las pantallas exclusivas
/// del rol Administrador (HU-03 a HU-15).
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panel de administración')),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: [
          _TarjetaAdmin(
            icono: Icons.shield_outlined,
            titulo: 'Roles y permisos',
            subtitulo: 'HU-03',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RolesPermisosScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.badge_outlined,
            titulo: 'Empleados',
            subtitulo: 'HU-05',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EmpleadosScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.people_outline,
            titulo: 'Clientes',
            subtitulo: 'HU-04',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ClientesScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.storefront_outlined,
            titulo: 'Datos del negocio',
            subtitulo: 'HU-07',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NegocioScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.location_city_outlined,
            titulo: 'Sucursales',
            subtitulo: 'HU-08',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SucursalesScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.schedule_outlined,
            titulo: 'Horarios',
            subtitulo: 'HU-09',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SucursalesScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.palette_outlined,
            titulo: 'Personalización',
            subtitulo: 'HU-10',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NegocioScreen()),
            ),
          ),
          _TarjetaAdmin(
            icono: Icons.inventory_2_outlined,
            titulo: 'Catálogo',
            subtitulo: 'HU-11 a HU-15',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CatalogoScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAdmin extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback? onTap;

  const _TarjetaAdmin({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    this.onTap,
  });

  bool get _habilitada => onTap != null;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: _habilitada ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icono, size: 36, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
