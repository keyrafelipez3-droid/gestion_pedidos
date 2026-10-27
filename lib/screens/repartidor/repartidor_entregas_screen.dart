import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/idioma.dart';
import '../../models/pedido_models.dart';
import '../../models/usuario_model.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/ubicacion_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contacto.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/mapa_seguimiento.dart';
import '../../widgets/panel_personal.dart';
import '../../widgets/tarjeta_pedido_personal.dart';
import '../../widgets/texto_traducido.dart';

/// Efectivo que el repartidor todavía tiene que entregar en caja (sin sus
/// propinas): pedidos entregados, pagados en efectivo y no rendidos.
double efectivoPorRendir(Iterable<PedidoModel> entregados) => entregados
    .where((p) => p.metodoPago == MetodoPago.efectivo && !p.cobrado)
    .fold(0.0, (a, p) => a + p.montoNegocio);

/// Panel del Repartidor: "Para tomar" (pedidos de delivery listos), "En
/// camino" (sus entregas, con mapa y botones grandes) y "Mi efectivo" (lo
/// que debe entregar en caja). Barra flotante abajo en el celular.
class RepartidorEntregasScreen extends StatelessWidget {
  static const paraTomar = 0;
  static const enCamino = 1;
  static const miEfectivo = 2;

  const RepartidorEntregasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = SesionActual.instancia;
    final idNegocio = sesion.idNegocio;
    final usuario = sesion.actual;
    if (idNegocio == null || usuario == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Mis entregas'))),
        body: Center(child: Text(tr('No se pudo identificar tu negocio.'))),
      );
    }
    return PanelConNavegacion(
      destinos: [
        DestinoPanel(
          icono: Icons.inventory_2_outlined,
          iconoActivo: Icons.inventory_2,
          etiqueta: tr('Para tomar'),
          builder: (_) => _ParaTomar(idNegocio: idNegocio, usuario: usuario),
        ),
        DestinoPanel(
          icono: Icons.two_wheeler_outlined,
          iconoActivo: Icons.two_wheeler,
          etiqueta: tr('En camino'),
          builder: (_) => _EnCamino(idNegocio: idNegocio, usuario: usuario),
        ),
        DestinoPanel(
          icono: Icons.account_balance_wallet_outlined,
          iconoActivo: Icons.account_balance_wallet,
          etiqueta: tr('Mi efectivo'),
          builder: (_) => _MiEfectivo(idNegocio: idNegocio, usuario: usuario),
        ),
      ],
    );
  }
}

/// Ejecuta una acción del repartidor mostrando el resultado.
Future<bool> _ejecutar(BuildContext context, Future<void> Function() accion, String exito) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await accion();
    messenger.showSnackBar(SnackBar(content: Text(exito)));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
    return false;
  }
}

String _direccion(PedidoModel p) {
  final direccion = (p.direccionEntrega?['direccion'] as String?) ?? '';
  final etiqueta = (p.direccionEntrega?['etiqueta'] as String?) ?? '';
  if (direccion.isEmpty) return tr('Sin dirección registrada');
  return etiqueta.isEmpty ? direccion : '$etiqueta · $direccion';
}

LatLng? _destino(PedidoModel p) {
  final lat = (p.direccionEntrega?['latitud'] as num?)?.toDouble();
  final lng = (p.direccionEntrega?['longitud'] as num?)?.toDouble();
  return (lat != null && lng != null) ? LatLng(lat, lng) : null;
}

// ------------------------------------------------------------ para tomar

class _ParaTomar extends StatefulWidget {
  final String idNegocio;
  final UsuarioModel usuario;

  const _ParaTomar({required this.idNegocio, required this.usuario});

  @override
  State<_ParaTomar> createState() => _ParaTomarState();
}

class _ParaTomarState extends State<_ParaTomar> {
  late final Stream<List<PedidoModel>> _disponibles = PedidoService.instancia.streamEntregasDisponibles(
    widget.idNegocio,
    idSucursal: widget.usuario.idSucursal,
  );
  late final Stream<List<PedidoModel>> _hoy =
      PedidoService.instancia.streamEntregadosHoy(widget.idNegocio, widget.usuario.idUsuario);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Entregas'))),
      body: StreamBuilder<List<PedidoModel>>(
        stream: _disponibles,
        builder: (context, s) => StreamBuilder<List<PedidoModel>>(
          stream: _hoy,
          builder: (context, sHoy) {
            if (s.hasError) return Center(child: Text(textoError(s.error!)));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final pedidos = s.data!;
            final llevas = efectivoPorRendir(sHoy.data ?? const <PedidoModel>[]);
            return AppContenidoCentrado(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
                children: [
                  ResumenTurno(datos: [
                    DatoTurno('${pedidos.length}', tr('pedidos para tomar'), icono: Icons.inventory_2_outlined),
                    DatoTurno(dinero(llevas), tr('efectivo que llevas'), icono: Icons.payments_outlined),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  if (pedidos.isEmpty)
                    AppEmptyState(
                      icon: Icons.delivery_dining_outlined,
                      title: tr('No hay pedidos para repartir'),
                      message: tr('Cuando la cocina deje un pedido de delivery listo, va a aparecer aquí.'),
                    )
                  else
                    for (final p in pedidos) ...[
                      _TarjetaParaTomar(key: ValueKey(p.id), pedido: p, usuario: widget.usuario),
                      const SizedBox(height: AppSpacing.sm + 4),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TarjetaParaTomar extends StatefulWidget {
  final PedidoModel pedido;
  final UsuarioModel usuario;

  const _TarjetaParaTomar({super.key, required this.pedido, required this.usuario});

  @override
  State<_TarjetaParaTomar> createState() => _TarjetaParaTomarState();
}

class _TarjetaParaTomarState extends State<_TarjetaParaTomar> {
  bool _ocupado = false;

  Future<void> _tomar() async {
    setState(() => _ocupado = true);
    final p = widget.pedido;
    final u = widget.usuario;
    final ok = await _ejecutar(
      context,
      () => PedidoService.instancia.tomarEntrega(
        idPedido: p.id,
        idRepartidor: u.idUsuario,
        nombreRepartidor: u.nombre,
        telefonoRepartidor: u.telefono,
      ),
      tr('Tomaste el pedido. ¡Buen viaje!'),
    );
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) PanelConNavegacion.irA(context, RepartidorEntregasScreen.enCamino);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final efectivo = p.metodoPago == MetodoPago.efectivo;
    return TarjetaPanel(
      franja: p.tieneAlergias ? scheme.error : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(numeroPedido(p), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ),
              EtiquetaPanel(
                tr('Listo {tiempo}', {'tiempo': haceTiempo(p.fechaCreacion)}),
                icono: Icons.schedule,
                color: scheme.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DatoConIcono(Icons.place_outlined, _direccion(p), color: scheme.onSurface),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if ((p.zonaEntrega ?? '').isNotEmpty) ...[
                Flexible(child: DatoConIcono(Icons.map_outlined, tr('Zona {zona}', {'zona': p.zonaEntrega}))),
                const SizedBox(width: AppSpacing.md),
              ],
              Flexible(
                child: DatoConIcono(
                  efectivo ? Icons.payments_outlined : Icons.check_circle_outline,
                  efectivo ? tr('Cobrar en efectivo') : tr('Ya pagado ({metodo})', {'metodo': tr(p.metodoPago)}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  efectivo ? tr('Total a cobrar') : tr('Total del pedido'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                dinero(efectivo ? p.totalACobrar : p.montoNegocio),
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (p.propina > 0)
            Text(
              tr('Incluye tu propina de {monto}', {'monto': dinero(p.propina)}),
              textAlign: TextAlign.right,
              style: TextStyle(color: context.semanticColors.success, fontSize: 13),
            ),
          const SizedBox(height: AppSpacing.sm + 4),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _ocupado ? null : _tomar,
            icon: const Icon(Icons.two_wheeler_outlined),
            label: Text(tr('Tomar entrega')),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- en camino

class _EnCamino extends StatefulWidget {
  final String idNegocio;
  final UsuarioModel usuario;

  const _EnCamino({required this.idNegocio, required this.usuario});

  @override
  State<_EnCamino> createState() => _EnCaminoState();
}

class _EnCaminoState extends State<_EnCamino> {
  late final Stream<List<PedidoModel>> _mias =
      PedidoService.instancia.streamMisEntregas(widget.idNegocio, widget.usuario.idUsuario);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('En camino'))),
      body: StreamBuilder<List<PedidoModel>>(
        stream: _mias,
        builder: (context, s) {
          if (s.hasError) return Center(child: Text(textoError(s.error!)));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final pedidos = s.data!;
          if (pedidos.isEmpty) {
            return AppEmptyState(
              icon: Icons.two_wheeler_outlined,
              title: tr('No tienes entregas en curso'),
              message: tr('Toma un pedido en "Para tomar" para empezar.'),
            );
          }
          final enReparto = pedidos.where((p) => p.enReparto).map((p) => p.id).toList();
          return AppContenidoCentrado(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
              children: [
                // Solo se comparte la ubicación de los pedidos que ya salieron.
                if (enReparto.isNotEmpty) ...[
                  _RastreoUbicacion(idPedidos: enReparto),
                  const SizedBox(height: AppSpacing.sm + 4),
                ],
                for (final (i, p) in pedidos.indexed) ...[
                  _TarjetaEnCamino(
                    key: ValueKey(p.id),
                    pedido: p,
                    usuario: widget.usuario,
                    conMapa: i == 0,
                  ),
                  const SizedBox(height: AppSpacing.sm + 4),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaEnCamino extends StatefulWidget {
  final PedidoModel pedido;
  final UsuarioModel usuario;
  final bool conMapa;

  const _TarjetaEnCamino({super.key, required this.pedido, required this.usuario, required this.conMapa});

  @override
  State<_TarjetaEnCamino> createState() => _TarjetaEnCaminoState();
}

class _TarjetaEnCaminoState extends State<_TarjetaEnCamino> {
  bool _ocupado = false;

  Future<void> _hacer(Future<void> Function() accion, String exito) async {
    setState(() => _ocupado = true);
    await _ejecutar(context, accion, exito);
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final u = widget.usuario;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final efectivo = p.metodoPago == MetodoPago.efectivo;
    final referencia = (p.direccionEntrega?['referencia'] as String?) ?? '';
    final destino = _destino(p);
    final repartidor = p.latRepartidor != null && p.lngRepartidor != null
        ? LatLng(p.latRepartidor!, p.lngRepartidor!)
        : null;
    final (estadoTexto, estadoColor) = switch (p.estado) {
      PedidoEstado.listo => (tr('Te lo asignaron'), semantic.info),
      PedidoEstado.llego => (tr('Llegaste'), semantic.success),
      _ => (tr('En camino'), scheme.primary),
    };

    final Widget accion;
    if (p.estado == PedidoEstado.listo) {
      // HU-39: te lo asignaron; sales cuando lo recoges.
      accion = FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: _ocupado
            ? null
            : () => _hacer(
                  () => PedidoService.instancia.salirConEntregaAsignada(
                    idPedido: p.id,
                    idRepartidor: u.idUsuario,
                    nombreRepartidor: u.nombre,
                  ),
                  tr('Saliste con el pedido. ¡Buen viaje!'),
                ),
        icon: const Icon(Icons.two_wheeler_outlined),
        label: Text(tr('Recogí el pedido · Salir a entregar')),
      );
    } else {
      final entregar = FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: semantic.success,
          foregroundColor: semantic.onSuccess,
        ),
        onPressed: _ocupado
            ? null
            : () => _hacer(
                  () => PedidoService.instancia.entregarPedido(idPedido: p.id, idRepartidor: u.idUsuario),
                  tr('Pedido entregado.'),
                ),
        icon: const Icon(Icons.check_circle_outline),
        label: Text(efectivo ? tr('Entregado y cobrado') : tr('Entregado')),
      );
      accion = p.estado == PedidoEstado.enCamino
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  onPressed: _ocupado
                      ? null
                      : () => _hacer(
                            () => PedidoService.instancia.avisarLlegada(idPedido: p.id, idRepartidor: u.idUsuario),
                            tr('Le avisamos al cliente que ya llegaste.'),
                          ),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(tr('Avisar que llegué')),
                ),
                const SizedBox(height: AppSpacing.sm),
                entregar,
              ],
            )
          : entregar;
    }

    return TarjetaPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.conMapa && p.enReparto && destino != null)
            MapaSeguimiento(destino: destino, repartidor: repartidor, actualizado: p.ubicacionActualizada),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [numeroPedido(p), if ((p.nombreCliente ?? '').isNotEmpty) p.nombreCliente!].join(' · '),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    EtiquetaPanel(estadoTexto, color: estadoColor),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                DatoConIcono(Icons.place_outlined, _direccion(p), color: scheme.onSurface, negrita: true),
                if (referencia.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  TextoTraducido(
                    texto: referencia,
                    idiomaOrigen: p.idiomaCliente,
                    etiqueta: tr('Referencia'),
                    icono: Icons.info_outline,
                  ),
                ],
                if (p.notas.isNotEmpty)
                  TextoTraducido(texto: p.notas, idiomaOrigen: p.idiomaCliente, etiqueta: tr('Nota')),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => llamarPorTelefono(context, p.telefonoCliente),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(tr('Llamar')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => abrirEnMapas(
                          context,
                          (p.direccionEntrega?['direccion'] as String?) ?? '',
                          latitud: destino?.latitude,
                          longitud: destino?.longitude,
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: Text(tr('Abrir mapa')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              efectivo ? tr('Cobrar al entregar') : tr('Ya pagado ({metodo})', {'metodo': tr(p.metodoPago)}),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ),
                          Text(
                            efectivo ? dinero(p.totalACobrar) : tr('No cobrar'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: efectivo ? scheme.primary : semantic.success,
                            ),
                          ),
                        ],
                      ),
                      if (p.propina > 0)
                        Text(
                          efectivo
                              ? tr('Incluye tu propina de {monto}', {'monto': dinero(p.propina)})
                              : tr('Propina para ti en efectivo: {monto}', {'monto': dinero(p.propina)}),
                          style: TextStyle(color: semantic.success, fontSize: 13),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                accion,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- mi efectivo

class _MiEfectivo extends StatefulWidget {
  final String idNegocio;
  final UsuarioModel usuario;

  const _MiEfectivo({required this.idNegocio, required this.usuario});

  @override
  State<_MiEfectivo> createState() => _MiEfectivoState();
}

class _MiEfectivoState extends State<_MiEfectivo> {
  late final Stream<List<PedidoModel>> _hoy =
      PedidoService.instancia.streamEntregadosHoy(widget.idNegocio, widget.usuario.idUsuario);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mi efectivo'))),
      body: StreamBuilder<List<PedidoModel>>(
        stream: _hoy,
        builder: (context, s) {
          if (s.hasError) return Center(child: Text(textoError(s.error!)));
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final entregados = [...s.data!]
            ..sort((a, b) => (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
          final porRendir = efectivoPorRendir(entregados);
          final enEfectivo = entregados.where((p) => p.metodoPago == MetodoPago.efectivo && !p.cobrado).length;
          final propinas = entregados.fold(0.0, (a, p) => a + p.propina);
          return AppContenidoCentrado(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
              children: [
                TarjetaPanel(
                  padding: const EdgeInsets.all(AppSpacing.lg - 4),
                  child: Column(
                    children: [
                      Text(
                        tr('EFECTIVO QUE DEBES ENTREGAR EN CAJA'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        dinero(porRendir),
                        style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
                      ),
                      Text(
                        tr('{n} entrega(s) cobradas en efectivo, sin rendir', {'n': enEfectivo}),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                ResumenTurno(datos: [
                  DatoTurno('${entregados.length}', tr('entregas hoy'), icono: Icons.task_alt),
                  DatoTurno(dinero(propinas), tr('propinas de hoy'),
                      icono: Icons.volunteer_activism_outlined, color: semantic.success),
                ]),
                const SizedBox(height: AppSpacing.md),
                TituloColumna(tr('Entregas de hoy'), contador: entregados.length),
                if (entregados.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      tr('Todavía no entregaste pedidos hoy.'),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                else
                  TarjetaPanel(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    child: Column(
                      children: [
                        for (final (i, p) in entregados.indexed) ...[
                          if (i > 0) const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm + 2),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${numeroPedido(p)}'
                                        '${p.fechaCreacion == null ? '' : ' · ${formatoHora(p.fechaCreacion!)}'}',
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                      Text(
                                        tr(p.metodoPago),
                                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(dinero(p.montoNegocio), style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (p.metodoPago == MetodoPago.efectivo)
                                      EtiquetaPanel(
                                        p.cobrado ? tr('Entregado en caja') : tr('Por entregar'),
                                        color: p.cobrado ? semantic.success : semantic.warning,
                                      ),
                                    if (p.propina > 0)
                                      Text(
                                        '+${dinero(p.propina)}',
                                        style: TextStyle(color: semantic.success, fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  tr('El cajero confirma cuando recibe el dinero.'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------- ubicación

/// Comparte la posición del repartidor con el cliente mientras tenga
/// entregas en curso. Pide permiso al dispositivo, avisa que se está
/// compartiendo y se detiene solo cuando ya no quedan entregas (o al salir
/// del panel). La posición se borra del pedido al entregarlo.
class _RastreoUbicacion extends StatefulWidget {
  final List<String> idPedidos;

  const _RastreoUbicacion({required this.idPedidos});

  @override
  State<_RastreoUbicacion> createState() => _RastreoUbicacionState();
}

class _RastreoUbicacionState extends State<_RastreoUbicacion> {
  StreamSubscription<LatLng>? _suscripcion;
  DateTime _ultimaEscritura = DateTime.fromMillisecondsSinceEpoch(0);
  String? _aviso;
  bool _compartiendo = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _suscripcion?.cancel();
    super.dispose();
  }

  Future<void> _iniciar() async {
    try {
      await UbicacionService.instancia.asegurarPermiso();
      final inicial = await UbicacionService.instancia.obtenerPosicionActual();
      if (!mounted) return;
      _enviar(inicial, forzar: true);
      _suscripcion = UbicacionService.instancia.seguirPosicion().listen(
            _enviar,
            onError: (_) {
              if (mounted) {
                setState(() {
                  _compartiendo = false;
                  _aviso = tr('Se perdió la señal de ubicación.');
                });
              }
            },
          );
      if (mounted) setState(() => _compartiendo = true);
    } on UbicacionException catch (e) {
      if (mounted) {
        setState(() {
          _compartiendo = false;
          _aviso = e.mensaje;
        });
      }
    }
  }

  void _enviar(LatLng punto, {bool forzar = false}) {
    // Máximo una escritura cada 8 segundos, para no gastar de más.
    final ahora = DateTime.now();
    if (!forzar && ahora.difference(_ultimaEscritura) < const Duration(seconds: 8)) return;
    _ultimaEscritura = ahora;
    for (final id in widget.idPedidos) {
      PedidoService.instancia
          .actualizarUbicacionRepartidor(
            idPedido: id,
            latitud: punto.latitude,
            longitud: punto.longitude,
          )
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final ok = _compartiendo && _aviso == null;
    final color = ok ? semantic.success : scheme.error;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.my_location : Icons.location_off_outlined, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              ok
                  ? tr('Compartiendo tu ubicación con el cliente mientras tengas entregas en curso. Deja la app abierta.')
                  : (_aviso ?? tr('Activando ubicación…')),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
