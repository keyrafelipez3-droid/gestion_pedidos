import 'package:flutter/material.dart';

import 'etiqueta_version.dart';
import 'logo_nami.dart';

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

  /// Botón a la derecha del título (por ejemplo, la campanita de avisos).
  final Widget? accion;

  const AppSidebar({
    super.key,
    required this.tituloNegocio,
    this.subtitulo,
    required this.secciones,
    this.onCerrarSesion,
    this.accion,
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
                  const LogoNami(size: 40),
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
                  if (accion != null) accion!,
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
                          seccion.title!,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    for (final item in seccion.items)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        // Ítem activo: fondo del color de marca suave y
                        // una barrita del color de marca a la izquierda.
                        child: Material(
                          color: item.selected
                              ? scheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                leading: Icon(
                                  item.icon,
                                  color: item.selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                ),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: item.selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                    fontWeight: item.selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                                onTap: item.onTap,
                              ),
                              if (item.selected)
                                Positioned(
                                  left: 0,
                                  top: 10,
                                  bottom: 10,
                                  child: Container(
                                    width: 4,
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      borderRadius: const BorderRadius.horizontal(
                                        right: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
