import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/acciones_pedido.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/aviso_pedidos_nuevos.dart';
import '../../widgets/panel_personal.dart';
import '../../widgets/tarjeta_pedido_personal.dart';

/// Grupos en los que el Cajero ve los pedidos.
enum GrupoPedidos { nuevos, preparando, listos, reparto, entregados, cancelados }

/// Grupo al que pertenece un pedido en curso (null si ya terminó).
GrupoPedidos? grupoDePedido(PedidoModel p) {
  switch (p.estado) {
    case PedidoEstado.pendiente:
      return GrupoPedidos.nuevos;
    case PedidoEstado.enPreparacion:
      return GrupoPedidos.preparando;
    case PedidoEstado.listo:
      return GrupoPedidos.listos;
    case PedidoEstado.enCamino:
    case PedidoEstado.llego:
      return GrupoPedidos.reparto;
    case PedidoEstado.entregado:
      return GrupoPedidos.entregados;
    case PedidoEstado.cancelado:
      return GrupoPedidos.cancelados;
    default:
      return null;
  }
}

/// true si el pedido coincide con lo que se escribió en el buscador: su
/// número, el nombre del cliente o el número de mesa.
bool coincideBusqueda(PedidoModel p, String texto) {
  final q = texto.trim().toLowerCase().replaceFirst('#', '');
  if (q.isEmpty) return true;
  return p.id.toLowerCase().startsWith(q) ||
      (p.nombreCliente ?? '').toLowerCase().contains(q) ||
      (p.numeroMesa ?? '').toLowerCase() == q;
}

/// Total de los pedidos en curso que todavía hay que cobrar en caja.
double porCobrarEnCaja(Iterable<PedidoModel> enCurso) => enCurso
    .where((p) => p.origen == PedidoOrigen.cliente && loCobraLaCaja(p) && !p.cobrado)
    .fold(0.0, (a, p) => a + p.montoNegocio);

/// HU-29: el Cajero registra y consulta los pedidos recibidos de su
/// negocio. En pantallas anchas los ve como tablero (Nuevos → En
/// preparación → Listos → En reparto); en el celular, por grupos con
/// píldoras. Cada tarjeta tiene el botón de la siguiente acción.
class CajeroPedidosScreen extends StatefulWidget {
  const CajeroPedidosScreen({super.key});

  @override
  State<CajeroPedidosScreen> createState() => _CajeroPedidosScreenState();
}

class _CajeroPedidosScreenState extends State<CajeroPedidosScreen> {
  final _buscador = TextEditingController();
  String _busqueda = '';
  GrupoPedidos _grupo = GrupoPedidos.nuevos;

  /// En el tablero (pantalla ancha): en curso, entregados o cancelados.
  GrupoPedidos? _historial;
  Timer? _reloj;

  late final String? _idNegocio = SesionActual.instancia.idNegocio;

  // Una consulta por grupo: los pedidos en curso y los entregados /
  // cancelados de los últimos 7 días (no todos los del negocio).
  late final Stream<List<PedidoModel>>? _enCurso =
      _idNegocio == null ? null : PedidoService.instancia.streamPedidosEnCurso(_idNegocio);
  late final Stream<List<PedidoModel>>? _entregados = _idNegocio == null
      ? null
      : PedidoService.instancia.streamRecientesPorEstado(_idNegocio, PedidoEstado.entregado);
  Stream<List<PedidoModel>>? _cancelados;

  @override
  void initState() {
    super.initState();
    // Actualiza "hace X min" y los atrasos.
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  Stream<List<PedidoModel>> _streamCancelados(String idNegocio) => _cancelados ??=
      PedidoService.instancia.streamRecientesPorEstado(idNegocio, PedidoEstado.cancelado);

  static String _nombreGrupo(GrupoPedidos g) {
    switch (g) {
      case GrupoPedidos.nuevos:
        return tr('Nuevos');
      case GrupoPedidos.preparando:
        return tr('En preparación');
      case GrupoPedidos.listos:
        return tr('Listos');
      case GrupoPedidos.reparto:
        return tr('En reparto');
      case GrupoPedidos.entregados:
        return tr('Entregados');
      case GrupoPedidos.cancelados:
        return tr('Cancelados');
    }
  }

  @override
  Widget build(BuildContext context) {
    final idNegocio = _idNegocio;
    final enCurso = _enCurso;
    final entregados = _entregados;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Pedidos'))),
      body: idNegocio == null || enCurso == null || entregados == null
          ? Center(child: Text(tr('No se pudo identificar tu negocio.')))
          : AvisoPedidosNuevos(
              idNegocio: idNegocio,
              child: StreamBuilder<List<PedidoModel>>(
                stream: enCurso,
                builder: (context, sCurso) => StreamBuilder<List<PedidoModel>>(
                  stream: entregados,
                  builder: (context, sEntregados) {
                    if (sCurso.hasError) {
                      return Center(child: Text(textoError(sCurso.error!)));
                    }
                    if (!sCurso.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _contenido(
                      context,
                      idNegocio,
                      sCurso.data!,
                      sEntregados.data ?? const <PedidoModel>[],
                    );
                  },
                ),
              ),
            ),
    );
  }

  Widget _contenido(
    BuildContext context,
    String idNegocio,
    List<PedidoModel> enCurso,
    List<PedidoModel> entregados,
  ) {
    final semantic = context.semanticColors;
    final scheme = Theme.of(context).colorScheme;
    final porGrupo = <GrupoPedidos, List<PedidoModel>>{
      for (final g in GrupoPedidos.values) g: <PedidoModel>[],
    };
    for (final p in enCurso) {
      final g = grupoDePedido(p);
      if (g != null && coincideBusqueda(p, _busqueda)) porGrupo[g]!.add(p);
    }
    porGrupo[GrupoPedidos.entregados] = [
      for (final p in entregados)
        if (coincideBusqueda(p, _busqueda)) p,
    ];
    final hoy = DateTime.now();
    final entregadosHoy = entregados.where((p) {
      final f = p.fechaCreacion;
      return f != null && f.year == hoy.year && f.month == hoy.month && f.day == hoy.day;
    }).length;
    final nuevos = enCurso.where((p) => p.estado == PedidoEstado.pendiente).length;
    final atrasados = enCurso.where((p) => pedidoAtrasado(p)).length;

    final resumen = ResumenTurno(datos: [
      DatoTurno('$nuevos', tr('pedidos nuevos sin aceptar'), icono: Icons.notifications_active_outlined),
      DatoTurno(dinero(porCobrarEnCaja(enCurso)), tr('por cobrar en caja'), icono: Icons.payments_outlined),
      DatoTurno(
        '$atrasados',
        tr('atrasados (más de {n} min)', {'n': minutosAtraso}),
        icono: Icons.alarm,
        color: atrasados > 0 ? scheme.error : semantic.success,
      ),
      DatoTurno('$entregadosHoy', tr('entregados hoy'), icono: Icons.task_alt),
    ]);

    final buscador = TextField(
      controller: _buscador,
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        hintText: tr('Buscar por número, cliente o mesa'),
        suffixIcon: _busqueda.isEmpty
            ? null
            : IconButton(
                tooltip: tr('Borrar'),
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _buscador.clear();
                  _busqueda = '';
                }),
              ),
      ),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final tablero = c.maxWidth >= AppBreakpoints.expanded;
        final Widget cuerpo;
        if (tablero) {
          final historial = _historial;
          cuerpo = historial == null
              ? _Tablero(porGrupo: porGrupo, nombre: _nombreGrupo)
              : _ListaDeGrupo(
                  grupo: historial,
                  pedidos: historial == GrupoPedidos.entregados ? porGrupo[historial]! : null,
                  streamCancelados: _streamCancelados(idNegocio),
                  busqueda: _busqueda,
                  ancho: c.maxWidth,
                );
        } else {
          cuerpo = _ListaDeGrupo(
            grupo: _grupo,
            pedidos: _grupo == GrupoPedidos.cancelados ? null : porGrupo[_grupo]!,
            streamCancelados: _streamCancelados(idNegocio),
            busqueda: _busqueda,
            ancho: c.maxWidth,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  resumen,
                  const SizedBox(height: AppSpacing.sm + 4),
                  if (tablero)
                    Row(
                      children: [
                        SizedBox(width: 380, child: buscador),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: PildorasFiltro<GrupoPedidos?>(
                            seleccion: _historial,
                            onChanged: (g) => setState(() => _historial = g),
                            opciones: [
                              OpcionPildora(null, tr('En curso'), contador: enCurso.length),
                              OpcionPildora(GrupoPedidos.entregados, tr('Entregados (7 días)')),
                              OpcionPildora(GrupoPedidos.cancelados, tr('Cancelados (7 días)')),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    buscador,
                    const SizedBox(height: AppSpacing.sm + 2),
                    PildorasFiltro<GrupoPedidos>(
                      seleccion: _grupo,
                      onChanged: (g) => setState(() => _grupo = g),
                      opciones: [
                        for (final g in GrupoPedidos.values)
                          OpcionPildora(
                            g,
                            _nombreGrupo(g),
                            contador: g == GrupoPedidos.cancelados || g == GrupoPedidos.entregados
                                ? null
                                : porGrupo[g]!.length,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm + 4),
                ],
              ),
            ),
            Expanded(child: cuerpo),
          ],
        );
      },
    );
  }
}

/// Tablero de cuatro columnas (pantallas anchas).
class _Tablero extends StatelessWidget {
  final Map<GrupoPedidos, List<PedidoModel>> porGrupo;
  final String Function(GrupoPedidos) nombre;

  const _Tablero({required this.porGrupo, required this.nombre});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final columnas = <(GrupoPedidos, Color)>[
      (GrupoPedidos.nuevos, scheme.primary),
      (GrupoPedidos.preparando, semantic.warning),
      (GrupoPedidos.listos, semantic.success),
      (GrupoPedidos.reparto, semantic.info),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, (g, color)) in columnas.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: AppRadius.lgAll,
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TituloColumna(nombre(g), contador: porGrupo[g]!.length, color: color),
                    Expanded(
                      child: porGrupo[g]!.isEmpty
                          ? Center(
                              child: Text(
                                tr('Nada por aquí'),
                                style: TextStyle(color: scheme.onSurfaceVariant),
                              ),
                            )
                          : ListView.separated(
                              itemCount: porGrupo[g]!.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
                              itemBuilder: (context, i) => TarjetaPedidoPersonal(
                                key: ValueKey(porGrupo[g]![i].id),
                                pedido: porGrupo[g]![i],
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
    );
  }
}

/// Pedidos de un solo grupo: en una columna (celular) o en una grilla
/// (pantalla ancha). Los cancelados se cargan recién al abrirlos.
class _ListaDeGrupo extends StatelessWidget {
  final GrupoPedidos grupo;

  /// null = cargar los cancelados desde [streamCancelados].
  final List<PedidoModel>? pedidos;
  final Stream<List<PedidoModel>> streamCancelados;
  final String busqueda;
  final double ancho;

  const _ListaDeGrupo({
    required this.grupo,
    required this.pedidos,
    required this.streamCancelados,
    required this.busqueda,
    required this.ancho,
  });

  @override
  Widget build(BuildContext context) {
    final lista = pedidos;
    if (lista != null) return _grilla(context, lista);
    return StreamBuilder<List<PedidoModel>>(
      stream: streamCancelados,
      builder: (context, s) {
        if (s.hasError) return Center(child: Text(textoError(s.error!)));
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return _grilla(context, [
          for (final p in s.data!)
            if (coincideBusqueda(p, busqueda)) p,
        ]);
      },
    );
  }

  Widget _grilla(BuildContext context, List<PedidoModel> lista) {
    final scheme = Theme.of(context).colorScheme;
    final terminado = grupo == GrupoPedidos.entregados || grupo == GrupoPedidos.cancelados;
    if (lista.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: scheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(
                busqueda.trim().isEmpty ? tr('No hay pedidos aquí') : tr('Ningún pedido coincide con la búsqueda'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (terminado)
                Text(
                  tr('Se muestran los de los últimos 7 días.'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      );
    }
    final columnas = ancho >= 700 ? (ancho / 360).floor().clamp(2, 4) : 1;
    if (columnas == 1) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm + 4),
        itemBuilder: (context, i) => TarjetaPedidoPersonal(
          key: ValueKey(lista[i].id),
          pedido: lista[i],
          conAccion: !terminado,
        ),
      );
    }
    const gap = AppSpacing.sm + 4;
    final anchoTarjeta = (ancho - AppSpacing.md * 2 - gap * (columnas - 1)) / columnas;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      child: Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final p in lista)
            SizedBox(
              width: anchoTarjeta,
              child: TarjetaPedidoPersonal(key: ValueKey(p.id), pedido: p, conAccion: !terminado),
            ),
        ],
      ),
    );
  }
}
