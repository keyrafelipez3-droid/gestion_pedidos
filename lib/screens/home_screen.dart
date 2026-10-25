import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../l10n/tamano_texto.dart';
import '../models/usuario_model.dart';
import '../services/actividad_service.dart';
import '../services/sesion_actual.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_status_badge.dart';
import '../widgets/avisos_cliente.dart';
import '../widgets/logo_caro.dart';
import 'admin/admin_home_screen.dart';
import 'cajero/cajero_caja_screen.dart';
import 'cajero/cajero_mesas_screen.dart';
import 'cajero/cajero_pedidos_screen.dart';
import 'cajero/cajero_rendicion_screen.dart';
import 'cliente/cliente_negocios_screen.dart';
import 'cliente/mis_pedidos_screen.dart';
import 'cocina/cocina_pedidos_screen.dart';
import 'cuenta/dos_pasos_screen.dart';
import 'cuenta/mi_cuenta_screen.dart';
import 'cuenta/puerta_acuerdos.dart';
import 'repartidor/repartidor_entregas_screen.dart';

/// Pantalla mostrada justo después de iniciar sesión / registrarse.
/// Si el usuario es Administrador, muestra además un acceso al panel de
/// administración (HU-03/04/05/07). El acceso a "Mi cuenta" (HU-06) está
/// disponible para cualquier usuario logueado, sin importar el rol.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<UsuarioModel?> _usuarioFuture;

  @override
  void initState() {
    super.initState();
    // SesionActual.obtener() hace lo mismo que antes (trae el documento
    // usuarios/{uid}) y además deja el usuario en memoria para el resto
    // de pantallas (ej. Sucursales/Catálogo necesitan su idNegocio) y
    // carga el tema del negocio correspondiente.
    _usuarioFuture = SesionActual.instancia.obtener();
    // Registro de actividad: inicio de sesión del personal.
    _usuarioFuture.then((_) => ActividadService.instancia.registrarInicioSesion());
  }

  void _reintentar() {
    setState(() {
      _usuarioFuture = SesionActual.instancia.obtener();
    });
  }

  Future<void> _abrirMiCuenta() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MiCuentaScreen()),
    );
    // Si el usuario cambió su nombre en "Mi cuenta", refresca esta pantalla
    // para mostrarlo actualizado.
    _reintentar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LogoCaro(size: 34),
            SizedBox(width: AppSpacing.sm),
            Text(AppBrand.nombre),
          ],
        ),
        actions: [
          // El idioma solo se puede cambiar en la parte del cliente; el
          // panel del personal se muestra siempre en español.
          ValueListenableBuilder<UsuarioModel?>(
            valueListenable: SesionActual.instancia.usuario,
            builder: (context, u, _) => u == null || u.esCliente
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (u != null) const CampanaAvisos(),
                      const BotonIdioma(),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          // Tamaño de letra: para todos (clientes y personal).
          const BotonTamanoTexto(),
          IconButton(
            tooltip: tr('Mi cuenta'),
            icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: _abrirMiCuenta,
          ),
          IconButton(
            tooltip: tr('Cerrar sesión'),
            icon: const Icon(Icons.logout),
            onPressed: () {
              ActividadService.instancia.cerrarSesion();
            },
          ),
        ],
      ),
      body: FutureBuilder<UsuarioModel?>(
        future: _usuarioFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final usuario = snapshot.data;
          if (usuario == null) {
            // Puede pasar justo después de registrarse, mientras el
            // documento de Firestore todavía se está escribiendo.
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('No se pudo cargar tu perfil todavía.')),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton(
                    onPressed: _reintentar,
                    child: Text(tr('Reintentar')),
                  ),
                ],
              ),
            );
          }

          final ancho = MediaQuery.sizeOf(context).width;
          final esAmplio = AppBreakpoints.isExpanded(ancho);
          final scheme = Theme.of(context).colorScheme;

          final acciones = <_AccionHome>[
            if (usuario.esCliente) ...[
              _AccionHome(
                icono: Icons.restaurant_menu_outlined,
                titulo: tr('Pedir ahora'),
                destacada: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClienteNegociosScreen()),
                ),
              ),
              _AccionHome(
                icono: Icons.receipt_long_outlined,
                titulo: tr('Mis pedidos'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MisPedidosScreen()),
                ),
              ),
            ],
            if (usuario.rol == Rol.cajero) ...[
              _AccionHome(
                icono: Icons.point_of_sale_outlined,
                titulo: tr('Pedidos recibidos'),
                destacada: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CajeroPedidosScreen()),
                ),
              ),
              _AccionHome(
                icono: Icons.table_bar_outlined,
                titulo: tr('Mesas'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CajeroMesasScreen()),
                ),
              ),
              _AccionHome(
                icono: Icons.point_of_sale,
                titulo: tr('Caja'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CajeroCajaScreen()),
                ),
              ),
              _AccionHome(
                icono: Icons.two_wheeler_outlined,
                titulo: tr('Rendición de repartidores'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CajeroRendicionScreen()),
                ),
              ),
            ],
            if (usuario.rol == Rol.cocina)
              _AccionHome(
                icono: Icons.soup_kitchen_outlined,
                titulo: tr('Pedidos pendientes'),
                destacada: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CocinaPedidosScreen()),
                ),
              ),
            if (usuario.rol == Rol.repartidor)
              _AccionHome(
                icono: Icons.delivery_dining_outlined,
                titulo: tr('Mis entregas'),
                destacada: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RepartidorEntregasScreen()),
                ),
              ),
            if (usuario.esAdministrador || usuario.esSuperAdmin)
              _AccionHome(
                icono: Icons.admin_panel_settings_outlined,
                titulo: tr('Panel de administración'),
                destacada: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
                ),
              ),
            _AccionHome(
              icono: Icons.manage_accounts_outlined,
              titulo: tr('Mi cuenta'),
              onTap: _abrirMiCuenta,
            ),
          ];

          // El personal debe tener activa la verificación en dos pasos.
          final contenido = PuertaDosPasos(
            usuario: usuario,
            // Después de los dos pasos: el personal firma su acuerdo y el
            // cliente acepta los términos vigentes.
            child: PuertaAcuerdos(
            usuario: usuario,
            child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: esAmplio ? 480 : 440),
                  child: Column(
                    children: [
                      _TarjetaBienvenida(usuario: usuario, scheme: scheme),
                      const SizedBox(height: AppSpacing.lg),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.15,
                        children: acciones,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
            ),
          );
          // El cliente recibe avisos cuando sus pedidos cambian de estado.
          return usuario.esCliente
              ? OyenteAvisos(uid: usuario.idUsuario, child: contenido)
              : contenido;
        },
      ),
    );
  }
}

/// Acceso rápido de la pantalla principal: tarjeta grande con ícono. La
/// acción principal del rol va rellena con el color de marca.
class _AccionHome extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;
  final bool destacada;

  const _AccionHome({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.destacada = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fondo = destacada ? scheme.primary : scheme.surfaceContainerLow;
    final texto = destacada ? scheme.onPrimary : scheme.onSurface;
    final brand = context.brand;
    final oscuro = scheme.brightness == Brightness.dark;
    return Material(
      color: destacada
          ? fondo
          : (oscuro ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest),
      elevation: brand.tarjeta == 'sombra' && !oscuro ? (destacada ? 4 : 2) : 0,
      shadowColor: destacada ? brand.colorSombra.withValues(alpha: 0.35) : brand.colorSombra,
      shape: RoundedRectangleBorder(
        borderRadius: brand.card,
        side: (!destacada && (brand.tarjeta == 'borde' || oscuro))
            ? BorderSide(color: scheme.outlineVariant, width: brand.grosorBorde)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          // La acción principal lleva un degradado suave del color de marca.
          decoration: destacada
              ? BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(fondo, Colors.white, 0.12)!,
                      Color.lerp(fondo, Colors.black, 0.12)!,
                    ],
                  ),
                )
              : null,
          child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: destacada
                      ? texto.withValues(alpha: 0.18)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    brand.radioPequeno > 14 ? 999 : brand.radioPequeno + 4,
                  ),
                ),
                child: Icon(
                  icono,
                  size: 30,
                  color: destacada ? texto : scheme.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                brand.titulo(titulo),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: texto,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _TarjetaBienvenida extends StatelessWidget {
  final UsuarioModel usuario;
  final ColorScheme scheme;

  const _TarjetaBienvenida({required this.usuario, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final textos = Theme.of(context).textTheme;
    final inicial = usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?';
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: brand.decoracionTarjeta(scheme),
      child: DecoratedBox(
        // Un brillo suave del color de marca desde la esquina.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.4,
            colors: [
              scheme.primary.withValues(alpha: 0.20),
              scheme.primary.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.primary, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      child: Text(
                        inicial,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('¡Hola, {nombre}!', {'nombre': usuario.nombre}),
                          style: textos.headlineSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          usuario.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textos.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  AppStatusBadge(label: usuario.rol, tone: AppStatusTone.neutral),
                  AppStatusBadge(
                    label: tr('Sesión activa'),
                    tone: AppStatusTone.success,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
