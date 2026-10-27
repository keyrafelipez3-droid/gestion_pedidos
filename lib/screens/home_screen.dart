import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../l10n/tamano_texto.dart';
import '../models/mesa_model.dart';
import '../models/negocio_model.dart';
import '../models/pedido_models.dart';
import '../models/usuario_model.dart';
import '../services/actividad_service.dart';
import '../services/app_theme_controller.dart';
import '../services/codigo_negocio_service.dart';
import '../services/negocio_service.dart';
import '../services/caja_service.dart';
import '../services/mesa_service.dart';
import '../services/pedido_service.dart';
import '../services/sesion_actual.dart';
import '../services/solicitudes_service.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';
import '../widgets/app_status_badge.dart';
import '../widgets/app_fotos_comida.dart';
import '../widgets/avisos_cliente.dart';
import '../widgets/codigo_restaurante.dart';
import '../widgets/logo_caro.dart';
import 'admin/admin_home_screen.dart';
import 'cajero/panel_cajero.dart';
import 'cliente/condiciones_restaurante_screen.dart';
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

          // El personal debe tener activa la verificación en dos pasos.
          final contenido = PuertaDosPasos(
            usuario: usuario,
            // Después de los dos pasos: el personal firma su acuerdo y el
            // cliente acepta los términos vigentes.
            child: PuertaAcuerdos(
              usuario: usuario,
              child: _ContenidoInicio(usuario: usuario, onMiCuenta: _abrirMiCuenta),
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

/// Un dato en vivo de la pantalla principal (por ejemplo "3 pedidos por
/// atender"). El valor viene de las mismas consultas que usan las pantallas
/// de cada rol; mientras llega se muestra "—", nunca un número inventado.
class _Dato {
  final String etiqueta;
  final Stream<String> valor;
  const _Dato(this.etiqueta, this.valor);
}

/// Contenido de la pantalla principal: saludo, datos en vivo del rol y
/// accesos rápidos. Las consultas se crean UNA vez (no en cada redibujo).
class _ContenidoInicio extends StatefulWidget {
  final UsuarioModel usuario;
  final VoidCallback onMiCuenta;

  const _ContenidoInicio({required this.usuario, required this.onMiCuenta});

  @override
  State<_ContenidoInicio> createState() => _ContenidoInicioState();
}

class _ContenidoInicioState extends State<_ContenidoInicio> {
  List<_Dato> _datos = const [];
  // Cantidad que se muestra en la acción principal ("3 nuevos").
  Stream<int>? _contador;
  String Function(int)? _textoContador;

  // Cliente: restaurantes a los que entró con su código (null = cargando).
  StreamSubscription<List<String>>? _subMios;
  List<NegocioModel>? _mios;

  static bool _enCurso(PedidoModel p) =>
      p.estado != PedidoEstado.entregado && p.estado != PedidoEstado.cancelado;

  @override
  void initState() {
    super.initState();
    final u = widget.usuario;
    final idNegocio = u.idNegocio;
    if (u.esCliente) {
      _entrarPorEnlace();
      _subMios = CodigoNegocioService.instancia.streamMisNegocios(u.idUsuario).listen(
            _cargarMios,
            onError: (_) {
              if (mounted) setState(() => _mios = const []);
            },
          );
      final pedidos = PedidoService.instancia.streamPedidosCliente(u.idUsuario).asBroadcastStream();
      final enCurso = pedidos.map((l) => l.where(_enCurso).length).asBroadcastStream();
      _datos = [
        _Dato(tr('pedidos en curso'), enCurso.map((n) => '$n')),
        _Dato(tr('pedidos realizados'), pedidos.map((l) => '${l.length}')),
      ];
      _contador = enCurso;
      _textoContador = (n) => tr('{n} en curso', {'n': n});
    } else if (u.esSuperAdmin) {
      final solicitudes =
          SolicitudesService.instancia.streamPendientes().map((l) => l.length).asBroadcastStream();
      _datos = [_Dato('solicitudes de negocios por revisar', solicitudes.map((n) => '$n'))];
      _contador = solicitudes;
      _textoContador = (n) => n == 1 ? '1 solicitud' : '$n solicitudes';
    } else if (idNegocio != null && idNegocio.isNotEmpty) {
      final pendientes = PedidoService.instancia
          .streamPendientes(idNegocio)
          .map((l) => l.length)
          .asBroadcastStream();
      switch (u.rol) {
        case Rol.cajero:
          _datos = [
            _Dato('pedidos por atender', pendientes.map((n) => '$n')),
            if (u.idSucursal != null && u.idSucursal!.isNotEmpty)
              _Dato(
                'mesas ocupadas',
                MesaService.instancia
                    .streamMesas(u.idSucursal!)
                    .map((l) => '${l.where((m) => m.estado == MesaEstado.ocupada).length}'),
              ),
            _Dato(
              'tu caja',
              CajaService.instancia.streamCajaAbierta(u.idUsuario).map(
                    (c) => c == null ? 'Cerrada' : (c.contada ? 'En cierre' : 'Abierta'),
                  ),
            ),
          ];
          _contador = pendientes;
          _textoContador = (n) => n == 1 ? '1 nuevo' : '$n nuevos';
          break;
        case Rol.cocina:
          final cocina = PedidoService.instancia.streamPedidosCocina(idNegocio).asBroadcastStream();
          final porPreparar = cocina
              .map((l) => l.where((p) => p.estado == PedidoEstado.pendiente).length)
              .asBroadcastStream();
          _datos = [
            _Dato('por preparar', porPreparar.map((n) => '$n')),
            _Dato(
              'en preparación',
              cocina.map((l) => '${l.where((p) => p.estado == PedidoEstado.enPreparacion).length}'),
            ),
          ];
          _contador = porPreparar;
          _textoContador = (n) => '$n por preparar';
          break;
        case Rol.repartidor:
          final disponibles = PedidoService.instancia
              .streamEntregasDisponibles(idNegocio, idSucursal: u.idSucursal)
              .map((l) => l.length)
              .asBroadcastStream();
          _datos = [
            _Dato('entregas disponibles', disponibles.map((n) => '$n')),
            _Dato(
              'en curso',
              PedidoService.instancia
                  .streamMisEntregas(idNegocio, u.idUsuario)
                  .map((l) => '${l.length}'),
            ),
            _Dato(
              'propinas de hoy',
              PedidoService.instancia.streamEntregadosHoy(idNegocio, u.idUsuario).map(
                    (l) => 'Bs ${l.fold<double>(0, (a, p) => a + p.propina).toStringAsFixed(2)}',
                  ),
            ),
          ];
          _contador = disponibles;
          _textoContador = (n) => n == 1 ? '1 disponible' : '$n disponibles';
          break;
        default:
          if (u.esAdministrador) {
            _datos = [
              _Dato('pedidos en curso',
                  PedidoService.instancia.streamPedidosActivos(idNegocio).map((n) => '$n')),
              _Dato('por atender', pendientes.map((n) => '$n')),
            ];
            _contador = pendientes;
            _textoContador = (n) => n == 1 ? '1 nuevo' : '$n nuevos';
          }
      }
    }
  }

  @override
  void dispose() {
    _subMios?.cancel();
    super.dispose();
  }

  /// Si la app se abrió con el enlace de un restaurante (o se acaba de
  /// registrar con su código), el cliente queda dentro de él.
  Future<void> _entrarPorEnlace() async {
    final codigo = CodigoNegocioService.codigoDelEnlace;
    if (codigo == null) return;
    final inv = await CodigoNegocioService.instancia.buscar(codigo);
    if (inv == null) return;
    try {
      await CodigoNegocioService.instancia.unirse(widget.usuario.idUsuario, inv);
      CodigoNegocioService.codigoDelEnlace = null;
    } catch (_) {
      // Se puede volver a intentar escribiendo el código.
    }
  }

  Future<void> _cargarMios(List<String> ids) async {
    final lista = <NegocioModel>[];
    for (final id in ids) {
      try {
        final n = await NegocioService.instancia.obtenerNegocioPorId(id);
        if (n.estado && n.nombre.isNotEmpty) lista.add(n);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _mios = lista);
    // Con un solo restaurante, toda la app toma su marca: para el cliente
    // es "la app del restaurante".
    if (lista.length == 1) AppThemeController.instancia.actualizar(lista.first);
  }

  Future<void> _pedirCodigo() async {
    await pedirCodigoRestaurante(context, widget.usuario.idUsuario);
  }

  void _ir(Widget pantalla) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));

  @override
  Widget build(BuildContext context) {
    final u = widget.usuario;
    final scheme = Theme.of(context).colorScheme;
    final acciones = <_AccionHome>[
      if (u.esCliente) ...[
        if (_mios != null && _mios!.isEmpty)
          // Todavía no entró a ningún restaurante: se le pide el código.
          _AccionHome(
            icono: Icons.vpn_key_outlined,
            titulo: tr('Ingresa el código de tu restaurante'),
            descripcion: tr('Te lo da el restaurante donde quieres pedir.'),
            destacada: true,
            onTap: _pedirCodigo,
          )
        else if (_mios != null)
          _AccionHome(
            icono: Icons.restaurant_menu_outlined,
            titulo: _mios!.length == 1
                ? tr('Pedir en {nombre}', {'nombre': _mios!.first.nombre})
                : tr('Pedir ahora'),
            descripcion: _mios!.length == 1
                ? tr('Mira el menú y arma tu pedido')
                : tr('Elige un restaurante y arma tu pedido'),
            destacada: true,
            contador: _contador,
            textoContador: _textoContador,
            onTap: _mios!.length == 1
                ? () => abrirRestaurante(context, _mios!.first,
                    fotoRespaldo: fotoComidaPorIndice(0))
                : () => _ir(ClienteNegociosScreen(
                      soloIds: [for (final n in _mios!) n.idNegocio],
                    )),
          ),
        _AccionHome(
          icono: Icons.receipt_long_outlined,
          titulo: tr('Mis pedidos'),
          descripcion: tr('Sigue tus pedidos y revisa los anteriores'),
          onTap: () => _ir(const MisPedidosScreen()),
        ),
      ],
      if (u.rol == Rol.cajero) ...[
        _AccionHome(
          icono: Icons.receipt_long_outlined,
          titulo: tr('Pedidos recibidos'),
          descripcion: 'Ver, preparar y cobrar pedidos',
          destacada: true,
          contador: _contador,
          textoContador: _textoContador,
          onTap: () => _ir(const PanelCajero(seccion: PanelCajero.pedidos)),
        ),
        _AccionHome(
          icono: Icons.table_restaurant_outlined,
          titulo: tr('Mesas'),
          descripcion: 'Tomar pedidos en el local',
          onTap: () => _ir(const PanelCajero(seccion: PanelCajero.mesas)),
        ),
        _AccionHome(
          icono: Icons.point_of_sale_outlined,
          titulo: tr('Caja'),
          descripcion: 'Abrir, registrar y cerrar caja',
          onTap: () => _ir(const PanelCajero(seccion: PanelCajero.caja)),
        ),
        _AccionHome(
          icono: Icons.two_wheeler_outlined,
          titulo: tr('Rendición de repartidores'),
          descripcion: 'Recibir el efectivo de las entregas',
          onTap: () => _ir(const PanelCajero(seccion: PanelCajero.rendicion)),
        ),
      ],
      if (u.rol == Rol.cocina)
        _AccionHome(
          icono: Icons.soup_kitchen_outlined,
          titulo: tr('Pedidos pendientes'),
          descripcion: 'Lo que hay que preparar ahora',
          destacada: true,
          contador: _contador,
          textoContador: _textoContador,
          onTap: () => _ir(const CocinaPedidosScreen()),
        ),
      if (u.rol == Rol.repartidor)
        _AccionHome(
          icono: Icons.delivery_dining_outlined,
          titulo: tr('Mis entregas'),
          descripcion: 'Tomar pedidos y entregarlos',
          destacada: true,
          contador: _contador,
          textoContador: _textoContador,
          onTap: () => _ir(const RepartidorEntregasScreen()),
        ),
      if (u.esAdministrador || u.esSuperAdmin)
        _AccionHome(
          icono: Icons.admin_panel_settings_outlined,
          titulo: tr('Panel de administración'),
          descripcion: u.esSuperAdmin
              ? 'Negocios, solicitudes, versiones y errores'
              : 'Negocio, menú, personal, ventas y reportes',
          destacada: true,
          contador: _contador,
          textoContador: _textoContador,
          onTap: () => _ir(const AdminHomeScreen()),
        ),
      _AccionHome(
        icono: Icons.manage_accounts_outlined,
        titulo: tr('Mi cuenta'),
        descripcion: tr('Tus datos, contraseña y preferencias'),
        onTap: widget.onMiCuenta,
      ),
    ];

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final amplio = c.maxWidth >= 720;
          final columnas = amplio ? 2 : 1;
          final filas = <Widget>[];
          for (var i = 0; i < acciones.length; i += columnas) {
            if (columnas == 1) {
              filas.add(acciones[i]);
            } else {
              filas.add(IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: acciones[i]),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: i + 1 < acciones.length ? acciones[i + 1] : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ));
            }
            filas.add(const SizedBox(height: AppSpacing.md));
          }
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: amplio ? AppSpacing.lg : AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TarjetaBienvenida(usuario: u, scheme: scheme, amplio: amplio),
                    if (_datos.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < _datos.length; i++) ...[
                              if (i > 0) SizedBox(width: amplio ? AppSpacing.md : AppSpacing.sm),
                              Expanded(child: _TarjetaDato(dato: _datos[i])),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      tr('Accesos rápidos').toUpperCase(),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.sm + 4),
                    ...filas,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Tarjeta chica con un dato en vivo: número grande y qué significa.
class _TarjetaDato extends StatelessWidget {
  final _Dato dato;
  const _TarjetaDato({required this.dato});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 6),
      decoration: context.brand.decoracionTarjeta(scheme),
      child: StreamBuilder<String>(
        stream: dato.valor,
        builder: (context, s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.hasError ? '—' : (s.data ?? '—'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textos.headlineSmall?.copyWith(color: scheme.primary),
            ),
            const SizedBox(height: 2),
            Text(
              dato.etiqueta,
              style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acceso rápido de la pantalla principal: tarjeta horizontal con ícono,
/// título, para qué sirve y una flecha. La acción principal del rol va
/// rellena con el color de marca y puede mostrar un aviso ("3 nuevos").
class _AccionHome extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;
  final bool destacada;
  final Stream<int>? contador;
  final String Function(int)? textoContador;

  const _AccionHome({
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.descripcion = '',
    this.destacada = false,
    this.contador,
    this.textoContador,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final brand = context.brand;
    final oscuro = scheme.brightness == Brightness.dark;
    final fondo = destacada
        ? scheme.primary
        : (oscuro ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest);
    final texto = destacada ? scheme.onPrimary : scheme.onSurface;
    final flecha = Icon(Icons.chevron_right, color: texto.withValues(alpha: 0.6));
    return Material(
      color: fondo,
      elevation: !destacada && brand.tarjeta == 'sombra' && !oscuro ? 1 : 0,
      shadowColor: brand.colorSombra,
      shape: RoundedRectangleBorder(
        borderRadius: brand.card,
        side: destacada
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant, width: brand.grosorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 4, vertical: AppSpacing.md + 2),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: destacada
                      ? texto.withValues(alpha: 0.12)
                      : scheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(
                    brand.radioPequeno > 14 ? 26 : brand.radioPequeno + 2,
                  ),
                ),
                child: Icon(icono, size: 26, color: destacada ? texto : scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      brand.titulo(titulo),
                      style: textos.titleMedium?.copyWith(color: texto, fontWeight: FontWeight.w800),
                    ),
                    if (descripcion.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        descripcion,
                        style: textos.bodyMedium?.copyWith(color: texto.withValues(alpha: 0.75)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (contador == null)
                flecha
              else
                StreamBuilder<int>(
                  stream: contador,
                  builder: (context, s) {
                    final n = s.data ?? 0;
                    if (n <= 0) return flecha;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: destacada ? texto : scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        textoContador?.call(n) ?? '$n',
                        maxLines: 1,
                        style: textos.labelLarge?.copyWith(
                          color: destacada ? fondo : scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Saludo: foto con aro del color de marca, nombre y correo; el rol y
/// "Sesión activa" a la derecha (o debajo, en el celular).
class _TarjetaBienvenida extends StatelessWidget {
  final UsuarioModel usuario;
  final ColorScheme scheme;
  final bool amplio;

  const _TarjetaBienvenida({required this.usuario, required this.scheme, required this.amplio});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final textos = Theme.of(context).textTheme;
    final inicial = usuario.nombre.isNotEmpty ? usuario.nombre[0].toUpperCase() : '?';
    final etiquetas = Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        AppStatusBadge(label: usuario.rol, tone: AppStatusTone.neutral),
        AppStatusBadge(label: tr('Sesión activa'), tone: AppStatusTone.success),
      ],
    );
    final datos = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: scheme.primary, width: 2),
          ),
          child: CircleAvatar(
            radius: amplio ? 30 : 26,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(inicial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('¡Hola, {nombre}!', {'nombre': usuario.nombre}),
                style: amplio ? textos.headlineSmall : textos.titleLarge,
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
    );
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: brand.decoracionTarjeta(scheme),
      child: DecoratedBox(
        // Un brillo suave del color de marca desde la esquina.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.6,
            colors: [
              scheme.primary.withValues(alpha: 0.16),
              scheme.primary.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(amplio ? AppSpacing.lg : AppSpacing.md + 4),
          child: amplio
              ? Row(
                  children: [
                    Expanded(child: datos),
                    const SizedBox(width: AppSpacing.md),
                    etiquetas,
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [datos, const SizedBox(height: AppSpacing.md), etiquetas],
                ),
        ),
      ),
    );
  }
}
