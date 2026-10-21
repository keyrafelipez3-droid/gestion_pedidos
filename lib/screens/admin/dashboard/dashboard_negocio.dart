import 'package:flutter/material.dart';

import '../../../models/caja_models.dart';
import '../../../models/catalogo_models.dart';
import '../../../models/cliente_negocio_model.dart';
import '../../../models/pedido_models.dart';
import '../../../models/resena_model.dart';
import '../../../models/sucursal_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/catalogo_service.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/pedido_service.dart';
import '../../../services/resena_service.dart';
import '../../../services/sucursal_service.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/app_metrica_card.dart';
import 'dashboard_comun.dart';

/// Panel del Administrador: lo importante del negocio en una sola pantalla,
/// calculado con los datos reales de Firestore.
///
/// - Hoy: ventas, pedidos entregados, ticket promedio, pedidos en curso y
///   cajas abiertas.
/// - Últimos 7 días: ventas por día (comparadas con la semana anterior),
///   productos más vendidos, métodos de pago y modalidades.
/// - Operación: pedidos en curso por estado y los que más esperan, cajas
///   abiertas, reseñas y alertas (productos agotados, sucursales cerradas,
///   clientes bloqueados).
///
/// "Ventas" = pedidos Entregados (igual que el historial de ventas).
class DashboardNegocio extends StatefulWidget {
  final String idNegocio;
  const DashboardNegocio({super.key, required this.idNegocio});

  @override
  State<DashboardNegocio> createState() => _DashboardNegocioState();
}

class _DashboardNegocioState extends State<DashboardNegocio> {
  // Las consultas compartidas se abren UNA vez y viven en la raíz del
  // panel (nunca se quitan del árbol), para no repetir lecturas.
  late Stream<List<PedidoModel>> _ventas;
  late Stream<List<PedidoModel>> _enCurso;
  late Stream<List<CajaModel>> _cajas;
  late DateTime _hoy;

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  @override
  void didUpdateWidget(covariant DashboardNegocio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.idNegocio != widget.idNegocio) _abrir();
  }

  void _abrir() {
    _hoy = inicioDelDia(DateTime.now());
    // 14 días: esta semana + la anterior (para comparar). Usa el índice que
    // ya existe (idNegocio + estado + fechaCreacion).
    _ventas = PedidoService.instancia.streamVentas(
      idNegocio: widget.idNegocio,
      desde: _hoy.subtract(const Duration(days: 13)),
      hasta: _hoy.add(const Duration(days: 1)),
    );
    _enCurso = PedidoService.instancia.streamPedidosEnCurso(widget.idNegocio);
    _cajas = DashboardService.instancia.streamCajasAbiertas(widget.idNegocio);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: _ventas,
      builder: (context, sVentas) => StreamBuilder<List<PedidoModel>>(
        stream: _enCurso,
        builder: (context, sCurso) => StreamBuilder<List<CajaModel>>(
          stream: _cajas,
          builder: (context, sCajas) => _contenido(context, sVentas, sCurso, sCajas),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<List<PedidoModel>> sVentas,
    AsyncSnapshot<List<PedidoModel>> sCurso,
    AsyncSnapshot<List<CajaModel>> sCajas,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;

    final ventas = sVentas.data;
    final enCurso = sCurso.data;
    final cajas = sCajas.data;

    // ----------------------------------------------------------- cálculos
    final ventasHoy = ventas == null ? null : pedidosDelDia(ventas, _hoy);
    final totalHoy = ventasHoy == null ? null : sumarTotales(ventasHoy);
    final ticketHoy = (ventasHoy == null || ventasHoy.isEmpty)
        ? (ventasHoy == null ? null : 0.0)
        : redondearDinero(totalHoy! / ventasHoy.length);

    final inicioSemana = _hoy.subtract(const Duration(days: 6));
    final semana = ventas == null
        ? null
        : pedidosEntre(ventas, inicioSemana, _hoy.add(const Duration(days: 1)));
    final semanaAnterior = ventas == null
        ? null
        : pedidosEntre(ventas, _hoy.subtract(const Duration(days: 13)), inicioSemana);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hoy', style: texto.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (sVentas.hasError)
          const TextoError(
            'No se pudieron cargar las ventas. Revisa la conexión o que el índice '
            'de Firestore (firestore.indexes.json) esté publicado.',
          ),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            AppMetricaCard(
              icon: Icons.payments_outlined,
              color: semantic.success,
              etiqueta: 'Ventas de hoy',
              valor: totalHoy == null ? null : bs(totalHoy),
              detalle: 'Pedidos entregados',
            ),
            AppMetricaCard(
              icon: Icons.check_circle_outline,
              color: scheme.primary,
              etiqueta: 'Entregados hoy',
              valor: ventasHoy == null ? null : '${ventasHoy.length}',
            ),
            AppMetricaCard(
              icon: Icons.receipt_outlined,
              color: semantic.info,
              etiqueta: 'Ticket promedio',
              valor: ticketHoy == null ? null : bs(ticketHoy),
              detalle: 'Por pedido, hoy',
            ),
            AppMetricaCard(
              icon: Icons.local_fire_department_outlined,
              color: AppBrand.rojo,
              etiqueta: 'Pedidos en curso',
              valor: enCurso == null ? null : '${enCurso.length}',
              detalle: 'Sin terminar ahora',
            ),
            AppMetricaCard(
              icon: Icons.point_of_sale_outlined,
              color: semantic.warning,
              etiqueta: 'Cajas abiertas',
              valor: cajas == null ? null : '${cajas.length}',
              detalle: 'Cobrando ahora',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GrillaDashboard(
          children: [
            _PanelVentasSemana(semana: semana, semanaAnterior: semanaAnterior, hoy: _hoy),
            _PanelEnCurso(enCurso: enCurso, error: sCurso.hasError),
            _PanelTopProductos(entregados: semana),
            _PanelPagosYModalidad(semana: semana),
            _PanelCajas(cajas: cajas, error: sCajas.hasError),
            _PanelResenas(idNegocio: widget.idNegocio),
            _PanelAlertas(idNegocio: widget.idNegocio, enCurso: enCurso),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ventas de los últimos 7 días
// ---------------------------------------------------------------------------
class _PanelVentasSemana extends StatelessWidget {
  final List<PedidoModel>? semana;
  final List<PedidoModel>? semanaAnterior;
  final DateTime hoy;

  const _PanelVentasSemana({
    required this.semana,
    required this.semanaAnterior,
    required this.hoy,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;
    final datos = semana;
    if (datos == null) {
      return const PanelDashboard(
        titulo: 'Ventas de los últimos 7 días',
        icono: Icons.bar_chart_rounded,
        child: CargandoSeccion(),
      );
    }
    final dias = [for (var i = 6; i >= 0; i--) hoy.subtract(Duration(days: i))];
    final valores = [for (final d in dias) sumarTotales(pedidosDelDia(datos, d))];
    final etiquetas = [
      for (var i = 0; i < dias.length; i++) i == dias.length - 1 ? 'Hoy' : diasCortos[dias[i].weekday - 1],
    ];
    final total = sumarTotales(datos);
    final anterior = sumarTotales(semanaAnterior ?? const []);
    final variacion = variacionPorcentual(total, anterior);
    final mejorIndice = valores.indexWhere((v) => v == valores.reduce((a, b) => a > b ? a : b));

    return PanelDashboard(
      titulo: 'Ventas de los últimos 7 días',
      icono: Icons.bar_chart_rounded,
      subtitulo: '${datos.length} pedidos entregados · ${bs(total)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GraficoBarras(
            valores: valores,
            etiquetas: etiquetas,
            formato: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              if (variacion != null)
                Text.rich(TextSpan(children: [
                  TextSpan(
                    text: '${variacion >= 0 ? '▲' : '▼'} ${variacion.abs().toStringAsFixed(0)}% ',
                    style: TextStyle(
                      color: variacion >= 0 ? semantic.success : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: 'frente a la semana anterior'),
                ]), style: texto.bodySmall)
              else
                Text('Sin ventas la semana anterior para comparar.', style: texto.bodySmall),
              if (total > 0 && mejorIndice >= 0)
                Text(
                  'Mejor día: ${etiquetas[mejorIndice]} (${bs(valores[mejorIndice])})',
                  style: texto.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pedidos en curso
// ---------------------------------------------------------------------------
class _PanelEnCurso extends StatelessWidget {
  final List<PedidoModel>? enCurso;
  final bool error;
  const _PanelEnCurso({required this.enCurso, required this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;
    final lista = enCurso;

    Widget contenido;
    if (error) {
      contenido = const TextoError('No se pudieron cargar los pedidos en curso.');
    } else if (lista == null) {
      contenido = const CargandoSeccion();
    } else if (lista.isEmpty) {
      contenido = const TextoVacio('No hay pedidos en curso en este momento.');
    } else {
      final conteo = agruparConteo(lista, (p) => p.estado);
      final colores = <String, Color>{
        PedidoEstado.pendiente: AppBrand.rojo,
        PedidoEstado.enPreparacion: semantic.warning,
        PedidoEstado.listo: semantic.success,
        PedidoEstado.enCamino: semantic.info,
        PedidoEstado.llego: semantic.info,
      };
      final iconos = <String, IconData>{
        PedidoEstado.pendiente: Icons.hourglass_top_rounded,
        PedidoEstado.enPreparacion: Icons.soup_kitchen_outlined,
        PedidoEstado.listo: Icons.room_service_outlined,
        PedidoEstado.enCamino: Icons.delivery_dining_outlined,
        PedidoEstado.llego: Icons.where_to_vote_outlined,
      };
      // Los que más esperan: la lista ya viene del más antiguo al más nuevo.
      final masAntiguos = lista.take(3).toList();
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final estado in colores.keys)
            if ((conteo[estado] ?? 0) > 0)
              FilaIndicador(
                icono: iconos[estado]!,
                color: colores[estado]!,
                texto: estado,
                valor: '${conteo[estado]}',
              ),
          const Divider(),
          Text('Los que más esperan', style: texto.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          for (final p in masAntiguos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '#${p.id.substring(0, 6)} · ${p.etiquetaModalidad} · ${p.estado}',
                      style: texto.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    textoEspera(minutosDesde(p.fechaCreacion)),
                    style: texto.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: minutosDesde(p.fechaCreacion) >= 30 ? scheme.error : null,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return PanelDashboard(
      titulo: 'Pedidos en curso',
      icono: Icons.local_fire_department_outlined,
      subtitulo: 'Se actualiza en vivo',
      child: contenido,
    );
  }
}

// ---------------------------------------------------------------------------
// Productos más vendidos (últimos 7 días)
// ---------------------------------------------------------------------------
class _PanelTopProductos extends StatefulWidget {
  final List<PedidoModel>? entregados;
  const _PanelTopProductos({required this.entregados});

  @override
  State<_PanelTopProductos> createState() => _PanelTopProductosState();
}

class _PanelTopProductosState extends State<_PanelTopProductos> {
  Future<List<ProductoVendido>>? _top;
  String _firma = '';

  @override
  void initState() {
    super.initState();
    _recalcularSiCambio();
  }

  @override
  void didUpdateWidget(covariant _PanelTopProductos oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recalcularSiCambio();
  }

  /// Solo vuelve a leer el detalle si cambió el conjunto de pedidos
  /// (no en cada redibujado del panel).
  void _recalcularSiCambio() {
    final lista = widget.entregados;
    if (lista == null) return;
    final firma = (lista.map((p) => p.id).toList()..sort()).join(',');
    if (firma == _firma && _top != null) return;
    _firma = firma;
    _top = DashboardService.instancia.topProductos(lista);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    Widget contenido;
    if (widget.entregados == null || _top == null) {
      contenido = const CargandoSeccion();
    } else if (widget.entregados!.isEmpty) {
      contenido = const TextoVacio('Todavía no hay ventas en los últimos 7 días.');
    } else {
      contenido = FutureBuilder<List<ProductoVendido>>(
        future: _top,
        builder: (context, s) {
          if (s.hasError) return const TextoError('No se pudo calcular el ranking.');
          if (!s.hasData) return const CargandoSeccion();
          final top = s.data!;
          if (top.isEmpty) return const TextoVacio('Sin productos vendidos todavía.');
          final maximo = top.first.cantidad;
          return Column(
            children: [
              for (var i = 0; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: i == 0 ? scheme.primary : scheme.surfaceContainerHighest,
                        foregroundColor: i == 0 ? scheme.onPrimary : scheme.onSurface,
                        child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    top[i].nombre,
                                    style: texto.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text('${top[i].cantidad} u. · ${bs(top[i].total)}', style: texto.bodySmall),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: maximo == 0 ? 0 : top[i].cantidad / maximo,
                                minHeight: 6,
                                backgroundColor: scheme.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      );
    }
    return PanelDashboard(
      titulo: 'Productos más vendidos',
      icono: Icons.emoji_events_outlined,
      subtitulo: 'Últimos 7 días, por unidades',
      child: contenido,
    );
  }
}

// ---------------------------------------------------------------------------
// Métodos de pago y modalidad
// ---------------------------------------------------------------------------
class _PanelPagosYModalidad extends StatelessWidget {
  final List<PedidoModel>? semana;
  const _PanelPagosYModalidad({required this.semana});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final semantic = context.semanticColors;
    final datos = semana;
    return PanelDashboard(
      titulo: 'Cómo compran tus clientes',
      icono: Icons.pie_chart_outline_rounded,
      subtitulo: 'Ventas de los últimos 7 días',
      child: datos == null
          ? const CargandoSeccion()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Método de pago', style: texto.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                ListaProporciones(
                  datos: agruparSuma(datos, (p) => p.metodoPago),
                  formato: bs,
                  vacio: 'Todavía no hay ventas esta semana.',
                  colores: {
                    MetodoPago.efectivo: semantic.success,
                    MetodoPago.qr: semantic.info,
                    MetodoPago.transferencia: semantic.warning,
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('Modalidad', style: texto.labelLarge),
                const SizedBox(height: AppSpacing.sm),
                ListaProporciones(
                  datos: agruparSuma(datos, (p) => p.modalidad),
                  formato: bs,
                  vacio: 'Todavía no hay ventas esta semana.',
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cajas abiertas
// ---------------------------------------------------------------------------
class _PanelCajas extends StatelessWidget {
  final List<CajaModel>? cajas;
  final bool error;
  const _PanelCajas({required this.cajas, required this.error});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final lista = cajas;
    Widget contenido;
    if (error) {
      contenido = const TextoError('No se pudieron cargar las cajas.');
    } else if (lista == null) {
      contenido = const CargandoSeccion();
    } else if (lista.isEmpty) {
      contenido = const TextoVacio('Ninguna caja abierta en este momento.');
    } else {
      contenido = Column(
        children: [
          for (final c in lista)
            FilaIndicador(
              icono: c.montoContado != null ? Icons.lock_clock_outlined : Icons.point_of_sale_outlined,
              color: c.montoContado != null ? semantic.warning : semantic.success,
              texto: '${c.nombreCajero.isEmpty ? 'Cajero' : c.nombreCajero}'
                  '${c.fechaApertura == null ? '' : ' · desde las ${_hora(c.fechaApertura!)}'}'
                  '${c.montoContado != null ? ' · en cierre' : ''}',
              valor: 'Inicial ${bs(c.montoInicial)}',
            ),
        ],
      );
    }
    return PanelDashboard(
      titulo: 'Caja',
      icono: Icons.point_of_sale_outlined,
      subtitulo: 'Cajas abiertas ahora',
      child: contenido,
    );
  }

  String _hora(DateTime f) =>
      '${f.hour.toString().padLeft(2, '0')}:${f.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Reseñas
// ---------------------------------------------------------------------------
class _PanelResenas extends StatefulWidget {
  final String idNegocio;
  const _PanelResenas({required this.idNegocio});

  @override
  State<_PanelResenas> createState() => _PanelResenasState();
}

class _PanelResenasState extends State<_PanelResenas> {
  late final Stream<List<ResenaModel>> _resenas = ResenaService.instancia.streamTodas(widget.idNegocio);

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return PanelDashboard(
      titulo: 'Reseñas de clientes',
      icono: Icons.star_outline_rounded,
      child: StreamBuilder<List<ResenaModel>>(
        stream: _resenas,
        builder: (context, s) {
          if (s.hasError) return const TextoError('No se pudieron cargar las reseñas.');
          if (!s.hasData) return const CargandoSeccion();
          final todas = s.data!;
          final visibles = todas.where((r) => r.estado == ResenaEstado.visible).toList();
          if (todas.isEmpty) return const TextoVacio('Todavía no hay reseñas.');
          final promedio = visibles.isEmpty
              ? 0.0
              : visibles.fold<int>(0, (a, r) => a + r.calificacion) / visibles.length;
          final ocultas = todas.length - visibles.length;
          final distribucion = <String, double>{
            for (var e = 5; e >= 1; e--)
              '$e ★': visibles.where((r) => r.calificacion == e).length.toDouble(),
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    promedio.toStringAsFixed(1),
                    style: texto.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '${'★' * promedio.round()}${'☆' * (5 - promedio.round())}  '
                      '(${visibles.length} visibles${ocultas > 0 ? ', $ocultas ocultas' : ''})',
                      style: texto.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ListaProporciones(
                datos: distribucion,
                formato: (v) => v.toStringAsFixed(0),
                vacio: 'No hay reseñas visibles.',
                colores: {for (var e = 1; e <= 5; e++) '$e ★': AppBrand.dorado},
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alertas
// ---------------------------------------------------------------------------
class _PanelAlertas extends StatefulWidget {
  final String idNegocio;
  final List<PedidoModel>? enCurso;
  const _PanelAlertas({required this.idNegocio, required this.enCurso});

  @override
  State<_PanelAlertas> createState() => _PanelAlertasState();
}

class _PanelAlertasState extends State<_PanelAlertas> {
  late final Stream<List<ProductoModel>> _productos =
      CatalogoService.instancia.streamProductos(widget.idNegocio);
  late final Stream<List<SucursalModel>> _sucursales =
      SucursalService.instancia.streamSucursales(widget.idNegocio);
  late final Stream<List<ClienteNegocioModel>> _clientes =
      AdminService.instancia.streamClientesDeNegocio(widget.idNegocio);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    return PanelDashboard(
      titulo: 'Atención',
      icono: Icons.notifications_active_outlined,
      subtitulo: 'Lo que conviene revisar',
      child: StreamBuilder<List<ProductoModel>>(
        stream: _productos,
        builder: (context, sProd) => StreamBuilder<List<SucursalModel>>(
          stream: _sucursales,
          builder: (context, sSuc) => StreamBuilder<List<ClienteNegocioModel>>(
            stream: _clientes,
            builder: (context, sCli) {
              if (!sProd.hasData || !sSuc.hasData || !sCli.hasData) {
                if (sProd.hasError || sSuc.hasError || sCli.hasError) {
                  return const TextoError('No se pudieron cargar las alertas.');
                }
                return const CargandoSeccion();
              }
              final agotados = sProd.data!.where((p) => p.estado && !p.disponible).toList();
              final activas = sSuc.data!.where((s) => s.estado).toList();
              final cerradas = activas.where((s) => !s.estadoApertura().abierta).toList();
              final bloqueados = sCli.data!.where((c) => c.bloqueado).length;
              final demorados = (widget.enCurso ?? const <PedidoModel>[])
                  .where((p) =>
                      p.estado == PedidoEstado.pendiente && minutosDesde(p.fechaCreacion) >= 15)
                  .length;

              final filas = <Widget>[
                if (demorados > 0)
                  FilaIndicador(
                    icono: Icons.timer_outlined,
                    color: scheme.error,
                    texto: 'Pedidos pendientes hace más de 15 min',
                    valor: '$demorados',
                  ),
                if (agotados.isNotEmpty)
                  FilaIndicador(
                    icono: Icons.remove_shopping_cart_outlined,
                    color: semantic.warning,
                    texto: 'Productos agotados: ${agotados.take(3).map((p) => p.nombre).join(', ')}'
                        '${agotados.length > 3 ? '…' : ''}',
                    valor: '${agotados.length}',
                  ),
                if (cerradas.isNotEmpty)
                  FilaIndicador(
                    icono: Icons.store_mall_directory_outlined,
                    color: semantic.info,
                    texto: 'Sucursales cerradas ahora: ${cerradas.map((s) => s.nombre).join(', ')}',
                    valor: '${cerradas.length}/${activas.length}',
                  ),
                if (bloqueados > 0)
                  FilaIndicador(
                    icono: Icons.block_outlined,
                    color: scheme.onSurfaceVariant,
                    texto: 'Clientes bloqueados',
                    valor: '$bloqueados',
                  ),
              ];
              if (filas.isEmpty) {
                return FilaIndicador(
                  icono: Icons.check_circle_outline,
                  color: semantic.success,
                  texto: 'Todo en orden por ahora.',
                  valor: '',
                );
              }
              return Column(children: filas);
            },
          ),
        ),
      ),
    );
  }
}
