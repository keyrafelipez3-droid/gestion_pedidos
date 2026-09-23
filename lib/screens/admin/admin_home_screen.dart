import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../models/usuario_model.dart';
import '../../services/admin_service.dart';
import '../../services/app_theme_controller.dart';
import '../../services/auth_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/app_stat_card.dart';
import '../cuenta/mi_cuenta_screen.dart';
import 'catalogo_screen.dart';
import 'clientes_screen.dart';
import 'empleados_screen.dart';
import 'negocio_screen.dart';
import 'personalizacion_screen.dart';
import 'roles_permisos_screen.dart';
import 'sucursales_screen.dart';

/// Identifica qué sección del panel está activa. Varios ítems del sidebar
/// apuntan a la misma pantalla subyacente (ej. "Horarios" y "Sucursales",
/// o "Disponibilidad" y "Productos" — ver los comentarios en
/// `_construirContenido`), así que este enum tiene un valor por ÍTEM del
/// menú, no uno por pantalla, para que el resaltado del sidebar refleje lo
/// que la persona tocó.
enum _SeccionAdmin {
  inicio,
  sucursales,
  horarios,
  categorias,
  productos,
  complementos,
  variantes,
  disponibilidad,
  rolesPermisos,
  personalizacion,
  datosNegocio,
  empleados,
  clientes,
  miCuenta,
}

/// Panel de administración: dashboard de inicio + navegación a las
/// pantallas exclusivas del rol Administrador (HU-03 a HU-15).
///
/// En pantallas anchas (escritorio/tablet grande) el sidebar se ve
/// SIEMPRE en el mismo lugar — elegir una sección reemplaza la pantalla
/// actual por una instancia nueva de este mismo widget ya posicionada en
/// esa sección (`seccionInicial`), con una transición sin animación para
/// que visualmente se vea igual que si el contenido hubiera cambiado en
/// el mismo lugar (igual que el diseño de referencia). Se navega en vez
/// de mutar el contenido in situ con `setState` porque eso último
/// disparaba un bug conocido de Flutter (falla en `mouse_tracker.dart`,
/// "Cannot hit test a render box that has never been laid out") cuando
/// el mouse quedaba encima del panel justo al cambiar de sección, y
/// dejaba el panel congelado sin responder a ningún clic. En móvil se
/// mantiene el comportamiento de siempre: el sidebar vive en un Drawer y
/// cada sección se abre en pantalla completa con su propia flecha de
/// regreso. Ninguna pantalla ni su lógica se modificó por esto — cada una
/// solo recibió un parámetro `incrustada` para no dibujar su propia
/// flecha de "atrás" cuando vive dentro de este panel.
class AdminHomeScreen extends StatefulWidget {
  /// Sección con la que arranca el panel — se usa al navegar entre
  /// secciones en pantallas anchas (ver `ir()` más abajo). Por defecto
  /// arranca en el dashboard de inicio.
  final _SeccionAdmin seccionInicial;

  const AdminHomeScreen({super.key, this.seccionInicial = _SeccionAdmin.inicio});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late _SeccionAdmin _seccion;

  @override
  void initState() {
    super.initState();
    _seccion = widget.seccionInicial;
  }

  List<AppSidebarSection> _secciones(BuildContext context, {required bool esAmplio}) {
    void ir(_SeccionAdmin destino, Widget Function() pantallaCompleta) {
      if (esAmplio) {
        // Se navega a una instancia nueva de este panel ya posicionada en
        // `destino` (con transición instantánea, sin animación) en vez de
        // hacer setState() para mutar el contenido en el mismo lugar —
        // ver la explicación completa en el comentario de la clase.
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => AdminHomeScreen(seccionInicial: destino),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        );
      } else {
        // En móvil el sidebar vive dentro de un Drawer: hay que cerrarlo
        // antes de navegar a la pantalla completa. Cerrar el Drawer
        // (pop) e inmediatamente empujar (push) la pantalla nueva EN EL
        // MISMO frame hace que sus animaciones se solapen y Flutter
        // intente hacer hit-test sobre un RenderBox que todavía no
        // terminó de acomodarse ("Cannot hit test a render box that
        // has never been laid out") — eso dejaba el panel en blanco y
        // sin responder a los toques. Por eso el push se agenda para
        // después de que termine el frame actual (una vez el Drawer ya
        // se cerró del todo), con addPostFrameCallback.
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => pantallaCompleta()),
          );
        });
      }
    }

    return [
      AppSidebarSection(items: [
        AppSidebarItem(
          icon: Icons.home_outlined,
          label: 'Inicio',
          selected: _seccion == _SeccionAdmin.inicio,
          onTap: () {
            if (esAmplio) {
              if (_seccion != _SeccionAdmin.inicio) {
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const AdminHomeScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              }
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ]),
      AppSidebarSection(title: 'Operación', items: [
        AppSidebarItem(
          icon: Icons.location_city_outlined,
          label: 'Sucursales',
          selected: _seccion == _SeccionAdmin.sucursales,
          onTap: () => ir(_SeccionAdmin.sucursales, () => const SucursalesScreen()),
        ),
        AppSidebarItem(
          // Los horarios se editan por sucursal (icono de reloj dentro de
          // cada tarjeta), no hay una pantalla de horarios "global" propia
          // todavía, así que este acceso lleva al mismo lugar que
          // "Sucursales" — es intencional, no un enlace roto.
          icon: Icons.schedule_outlined,
          label: 'Horarios',
          selected: _seccion == _SeccionAdmin.horarios,
          onTap: () => ir(_SeccionAdmin.horarios, () => const SucursalesScreen()),
        ),
      ]),
      AppSidebarSection(title: 'Catálogo', items: [
        AppSidebarItem(
          icon: Icons.category_outlined,
          label: 'Categorías',
          selected: _seccion == _SeccionAdmin.categorias,
          onTap: () =>
              ir(_SeccionAdmin.categorias, () => const CatalogoScreen(indiceInicial: 0)),
        ),
        AppSidebarItem(
          icon: Icons.fastfood_outlined,
          label: 'Productos',
          selected: _seccion == _SeccionAdmin.productos,
          onTap: () =>
              ir(_SeccionAdmin.productos, () => const CatalogoScreen(indiceInicial: 1)),
        ),
        AppSidebarItem(
          icon: Icons.add_circle_outline,
          label: 'Complementos',
          selected: _seccion == _SeccionAdmin.complementos,
          onTap: () =>
              ir(_SeccionAdmin.complementos, () => const CatalogoScreen(indiceInicial: 2)),
        ),
        AppSidebarItem(
          icon: Icons.tune,
          label: 'Variantes',
          selected: _seccion == _SeccionAdmin.variantes,
          onTap: () =>
              ir(_SeccionAdmin.variantes, () => const CatalogoScreen(indiceInicial: 3)),
        ),
        AppSidebarItem(
          // La disponibilidad se activa/desactiva con el switch de cada
          // producto — misma pantalla que "Productos", con el filtro
          // "Disponibles/No disponibles" ya integrado ahí.
          icon: Icons.toggle_on_outlined,
          label: 'Disponibilidad',
          selected: _seccion == _SeccionAdmin.disponibilidad,
          onTap: () =>
              ir(_SeccionAdmin.disponibilidad, () => const CatalogoScreen(indiceInicial: 1)),
        ),
      ]),
      AppSidebarSection(title: 'Configuración', items: [
        AppSidebarItem(
          icon: Icons.shield_outlined,
          label: 'Roles y permisos',
          selected: _seccion == _SeccionAdmin.rolesPermisos,
          onTap: () => ir(_SeccionAdmin.rolesPermisos, () => const RolesPermisosScreen()),
        ),
        AppSidebarItem(
          icon: Icons.palette_outlined,
          label: 'Personalización',
          selected: _seccion == _SeccionAdmin.personalizacion,
          onTap: () =>
              ir(_SeccionAdmin.personalizacion, () => const PersonalizacionScreen()),
        ),
        AppSidebarItem(
          icon: Icons.storefront_outlined,
          label: 'Datos del negocio',
          selected: _seccion == _SeccionAdmin.datosNegocio,
          onTap: () => ir(_SeccionAdmin.datosNegocio, () => const NegocioScreen()),
        ),
        AppSidebarItem(
          icon: Icons.badge_outlined,
          label: 'Empleados',
          selected: _seccion == _SeccionAdmin.empleados,
          onTap: () => ir(_SeccionAdmin.empleados, () => const EmpleadosScreen()),
        ),
      ]),
      AppSidebarSection(title: 'Usuarios', items: [
        AppSidebarItem(
          icon: Icons.people_outline,
          label: 'Clientes',
          selected: _seccion == _SeccionAdmin.clientes,
          onTap: () => ir(_SeccionAdmin.clientes, () => const ClientesScreen()),
        ),
        AppSidebarItem(
          icon: Icons.manage_accounts_outlined,
          label: 'Mi cuenta',
          selected: _seccion == _SeccionAdmin.miCuenta,
          onTap: () => ir(_SeccionAdmin.miCuenta, () => const MiCuentaScreen()),
        ),
      ]),
    ];
  }

  /// Construye el contenido incrustado (escritorio) para la sección activa
  /// — mismas pantallas que móvil abre con Navigator.push, solo que aquí
  /// se pasan con `incrustada: true` para que no dibujen su propia flecha
  /// de regreso (el sidebar ya cumple ese rol).
  Widget _construirContenido(_SeccionAdmin seccion) {
    switch (seccion) {
      case _SeccionAdmin.inicio:
        return _ContenidoDashboard(
          onAbrirPersonalizacion: () => Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  const AdminHomeScreen(seccionInicial: _SeccionAdmin.personalizacion),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          ),
        );
      case _SeccionAdmin.sucursales:
      case _SeccionAdmin.horarios:
        return const SucursalesScreen(incrustada: true);
      case _SeccionAdmin.categorias:
        return const CatalogoScreen(indiceInicial: 0, incrustada: true);
      case _SeccionAdmin.productos:
      case _SeccionAdmin.disponibilidad:
        return const CatalogoScreen(indiceInicial: 1, incrustada: true);
      case _SeccionAdmin.complementos:
        return const CatalogoScreen(indiceInicial: 2, incrustada: true);
      case _SeccionAdmin.variantes:
        return const CatalogoScreen(indiceInicial: 3, incrustada: true);
      case _SeccionAdmin.rolesPermisos:
        return const RolesPermisosScreen(incrustada: true);
      case _SeccionAdmin.personalizacion:
        return const PersonalizacionScreen(incrustada: true);
      case _SeccionAdmin.datosNegocio:
        return const NegocioScreen(incrustada: true);
      case _SeccionAdmin.empleados:
        return const EmpleadosScreen(incrustada: true);
      case _SeccionAdmin.clientes:
        return const ClientesScreen(incrustada: true);
      case _SeccionAdmin.miCuenta:
        return const MiCuentaScreen(incrustada: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esAmplio = AppBreakpoints.isExpanded(ancho);

    return FutureBuilder<UsuarioModel?>(
      future: AuthService.instancia.obtenerUsuarioActual(),
      builder: (context, snapshot) {
        final usuario = snapshot.data;
        final sidebar = AppSidebar(
          tituloNegocio: usuario?.nombre.isNotEmpty == true
              ? 'Hola, ${usuario!.nombre}'
              : 'Panel de administración',
          subtitulo: usuario?.rol,
          secciones: _secciones(context, esAmplio: esAmplio),
          onCerrarSesion: () => AuthService.instancia.cerrarSesion(),
        );

        if (esAmplio) {
          return Scaffold(
            body: Row(
              children: [
                SizedBox(width: 280, child: sidebar),
                const VerticalDivider(width: 1),
                Expanded(child: _construirContenido(_seccion)),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Panel de administración')),
          drawer: Drawer(width: 280, child: sidebar),
          body: _ContenidoDashboard(
            onAbrirPersonalizacion: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PersonalizacionScreen()),
            ),
          ),
        );
      },
    );
  }
}

class _ContenidoDashboard extends StatelessWidget {
  /// Qué hacer al tocar el engranaje de personalización: en escritorio
  /// cambia la sección activa del sidebar (sin navegar); en móvil abre la
  /// pantalla completa de siempre.
  final VoidCallback onAbrirPersonalizacion;

  const _ContenidoDashboard({required this.onAbrirPersonalizacion});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UsuarioModel?>(
      future: AuthService.instancia.obtenerUsuarioActual(),
      builder: (context, snapshot) {
        final nombre = snapshot.data?.nombre ?? '';
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Panel de administración',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Personalización',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: onAbrirPersonalizacion,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ValueListenableBuilder<NegocioModel?>(
                valueListenable: AppThemeController.instancia.negocio,
                builder: (context, negocio, _) => _BannerBienvenida(
                  nombre: nombre,
                  bannerUrl: negocio?.bannerUrl ?? '',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Resumen del negocio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              const _FilaEstadisticas(),
            ],
          ),
        );
      },
    );
  }
}

/// Banner de bienvenida del dashboard. Si el negocio subió una imagen de
/// banner (HU-10, Personalización) se usa como fondo con un degradé oscuro
/// encima para que el texto se lea bien; si no, se usa el degradé de color
/// de marca de siempre — nunca se inventa ninguna foto.
class _BannerBienvenida extends StatelessWidget {
  final String nombre;
  final String bannerUrl;
  const _BannerBienvenida({required this.nombre, required this.bannerUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tieneImagen = bannerUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: AppRadius.lgAll,
      child: Container(
        width: double.infinity,
        // Antes esto era `constraints: BoxConstraints(minHeight: 156)`
        // (solo un mínimo, sin máximo). Este banner vive dentro de una
        // lista con scroll (`_ContenidoDashboard`), que le da altura
        // "infinita" a sus hijos — y el `Stack(fit: StackFit.expand)` de
        // más abajo necesita una altura máxima concreta para poder
        // expandirse dentro de ella. Con solo un mínimo y sin máximo,
        // Flutter tiraba "BoxConstraints forces an infinite height" al
        // dibujar el banner, y ese error dejaba rota toda la pantalla de
        // Inicio del panel de administración (de ahí el panel en blanco
        // que no respondía a ningún clic). Una altura fija resuelve esto
        // de raíz.
        height: 156,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (tieneImagen)
              Image.network(
                bannerUrl.trim(),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const SizedBox.shrink(),
              ),
            if (tieneImagen)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.25),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre.isEmpty ? 'Buenos días 👋' : 'Buenos días, $nombre 👋',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Gestiona todo tu negocio desde un solo lugar.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (!tieneImagen)
                    Icon(
                      Icons.storefront,
                      size: 48,
                      color: scheme.onPrimary.withValues(alpha: 0.85),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjetas de estadísticas del dashboard. Cada una viene de un stream de
/// Firestore que YA existe (mismo servicio que usa la pantalla completa de
/// esa sección) — no se inventa ningún dato: si algo no existe todavía en
/// el proyecto (por ejemplo "pedidos", que es de un sprint futuro), no se
/// muestra ninguna tarjeta para eso, y no se calculan porcentajes de
/// tendencia que requerirían un histórico que tampoco existe todavía.
class _FilaEstadisticas extends StatelessWidget {
  const _FilaEstadisticas();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        AppStatCard(
          icon: Icons.fastfood_outlined,
          color: scheme.primary,
          etiqueta: 'Productos',
          stream: CatalogoService.instancia.streamProductos().map((l) => l.length),
        ),
        AppStatCard(
          icon: Icons.category_outlined,
          color: scheme.tertiary,
          etiqueta: 'Categorías',
          stream: CatalogoService.instancia.streamCategorias().map((l) => l.length),
        ),
        AppStatCard(
          icon: Icons.people_outline,
          color: semantic.info,
          etiqueta: 'Clientes',
          stream: AdminService.instancia.streamClientes().map((l) => l.length),
        ),
        AppStatCard(
          icon: Icons.badge_outlined,
          color: semantic.warning,
          etiqueta: 'Empleados',
          stream: AdminService.instancia.streamEmpleados().map((l) => l.length),
        ),
        AppStatCard(
          icon: Icons.location_city_outlined,
          color: semantic.success,
          etiqueta: 'Sucursales',
          stream: SucursalService.instancia.streamSucursales().map((l) => l.length),
        ),
      ],
    );
  }
}
