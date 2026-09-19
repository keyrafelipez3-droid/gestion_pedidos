import 'package:flutter/material.dart';

import 'roles_permisos_screen.dart';

/// Panel de administración: punto de entrada a las pantallas exclusivas
/// del rol Administrador (HU-03, HU-04, HU-05, HU-07...).
/// Las tarjetas sin pantalla todavía implementada quedan deshabilitadas
/// ("Próximamente") y se activan a medida que se construye cada historia.
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
          const _TarjetaAdmin(
            icono: Icons.badge_outlined,
            titulo: 'Empleados',
            subtitulo: 'HU-05 · próximamente',
          ),
          const _TarjetaAdmin(
            icono: Icons.people_outline,
            titulo: 'Clientes',
            subtitulo: 'HU-04 · próximamente',
          ),
          const _TarjetaAdmin(
            icono: Icons.storefront_outlined,
            titulo: 'Datos del negocio',
            subtitulo: 'HU-07 · próximamente',
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
