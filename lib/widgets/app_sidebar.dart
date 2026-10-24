import 'package:flutter/material.dart';

import 'etiqueta_version.dart';
import 'logo_caro.dart';

/// Un ítem individual de navegación dentro del sidebar del panel de
/// administración.
class AppSidebarItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  const AppSidebarItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
}

/// Un grupo de ítems dentro del sidebar (ej. "Catálogo", "Configuración").
/// `title` es opcional — la primera sección (ej. "Inicio") no necesita
/// encabezado.
class AppSidebarSection {
  final String? title;
  final List<AppSidebarItem> items;

  const AppSidebarSection({this.title, required this.items});
}

/// Sidebar de navegación reutilizable para el panel de administración.
/// Se usa tanto como panel fijo en pantallas anchas (ver AdminHomeScreen)
/// como contenido de un `Drawer` en pantallas angostas — es el mismo
/// widget en los dos casos, solo cambia el contenedor que lo envuelve.
class AppSidebar extends StatelessWidget {
  final String tituloNegocio;
  /// Texto secundario bajo el título — ej. el nombre y rol de quien tiene
  /// la sesión abierta ("Hola, Ana · Administrador").
  final String? subtitulo;
  final List<AppSidebarSection> secciones;
  final VoidCallback? onCerrarSesion;

  const AppSidebar({
    super.key,
    required this.tituloNegocio,
    this.subtitulo,
    required this.secciones,
    this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const LogoCaro(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tituloNegocio,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitulo != null && subtitulo!.isNotEmpty)
                          Text(
                            subtitulo!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final seccion in secciones) ...[
                    if (seccion.title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                        child: Text(
                          seccion.title!.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    for (final item in seccion.items)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Material(
                          color: item.selected
                              ? scheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            leading: Icon(
                              item.icon,
                              color: item.selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: item.selected
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurface,
                                fontWeight:
                                    item.selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                            onTap: item.onTap,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (onCerrarSesion != null) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.logout),
                  title: const Text('Cerrar sesión'),
                  onTap: onCerrarSesion,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: EtiquetaVersion(),
            ),
          ],
        ),
      ),
    );
  }
}
