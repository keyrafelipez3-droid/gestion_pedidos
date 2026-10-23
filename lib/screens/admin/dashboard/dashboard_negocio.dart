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
import '../../../utils/reporte_excel.dart';
import '../../../widgets/app_status_badge.dart';
import '../../cliente/pedido_detalle_screen.dart';
import 'dashboard_comun.dart';
import 'dashboard_graficos.dart';

/// Panel del Administrador: lo importante del negocio en una sola pantalla,
/// calculado con los datos reales de Firestore.
///
/// - Selector de periodo (Hoy / 7 días / 30 días): todos los indicadores
///   se comparan con el periodo anterior de la misma duración.
/// - Indicadores: ventas, pedidos entregados, ticket promedio,
///   cancelaciones, pedidos en curso y cajas abiertas.
/// - Evolución de ventas, horas pico, productos más vendidos, métodos de
///   pago y modalidad, últimos pedidos, caja, reseñas y alertas.
/// - Exportar las ventas del periodo a Excel (CSV).
///
/// "Ventas" = pedidos Entregados (igual que el historial de ventas).
class DashboardNegocio extends StatefulWidget {
  final String idNegocio;
  const DashboardNegocio({super.key, required this.idNegocio});

  @override
  State<DashboardNegocio> createState() => _DashboardNegocioState();
}

class _DashboardNegocioState extends State<DashboardNegocio> {
  PeriodoDashboard _periodo = PeriodoDashboard.semana;

  // Las consultas se abren UNA vez (60 días: el periodo más largo y su
  // anterior) y viven en la raíz del panel; cambiar de periodo solo
  // recalcula en memoria, sin volver a leer Firestore.
  late Stream<List<PedidoModel>> _ventas;
  late Stream<List<PedidoModel>> _cancelados;
  late Stream<List<PedidoModel>> _enCurso;
  late Stream<List<CajaModel>> _cajas;
  late Stream<List<SucursalModel>> _sucursales;
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
    final desde = _hoy.subtract(const Duration(days: 59));
    final hasta = _hoy.add(const Duration(days: 1));
    _ventas = PedidoService.instancia.streamVentas(
      idNegocio: widget.idNegocio,
      desde: desde,
      hasta: hasta,
    );
    _cancelados = DashboardService.instancia.streamPedidosPorEstado(
      idNegocio: widget.idNegocio,
      estado: PedidoEstado.cancelado,
      desde: desde,
      hasta: hasta,
    );
    _enCurso = PedidoService.instancia.streamPedidosEnCurso(widget.idNegocio);
    _cajas = DashboardService.instancia.streamCajasAbiertas(widget.idNegocio);
    _sucursales = SucursalService.instancia.streamSucursales(widget.idNegocio);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: _ventas,
      builder: (context, sVentas) => StreamBuilder<List<PedidoModel>>(
        stream: _cancelados,
        builder: (context, sCanc) => StreamBuilder<List<PedidoModel>>(
          stream: _enCurso,
          builder: (context, sCurso) => StreamBuilder<List<CajaModel>>(
            stream: _cajas,
            builder: (context, sCajas) => StreamBuilder<List<SucursalModel>>(
              stream: _sucursales,
              builder: (context, sSuc) => _contenido(context, sVentas, sCanc, sCurso, sCajas, sSuc),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<List<PedidoModel>> sVentas,
    AsyncSnapshot<List<PedidoModel>> sCanc,
    AsyncSnapshot<List<PedidoModel>> sCurso,
    AsyncSnapshot<List<CajaModel>> sCajas,
    AsyncSnapshot<List<SucursalModel>> sSuc,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;

    final (desde, hasta) = _periodo.rango(_hoy);
    final (desdeAnt, hastaAnt) = _periodo.rangoAnterior(_hoy);

    final todas = sVentas.data;
    final ventas = todas == null ? null : pedidosEntre(todas, desde, hasta);
    final ventasAnt = todas == null ? null : pedidosEntre(todas, desdeAnt, hastaAnt);
    final cancelados = sCanc.data == null ? null : pedidosEntre(sCanc.data!, desde, hasta);
    final canceladosAnt = sCanc.data == null ? null : pedidosEntre(sCanc.data!, desdeAnt, hastaAnt);
    final enCurso = sCurso.data;
    final cajas = sCajas.data;
    final nombresSucursal = {for (final s in sSuc.data ?? const <SucursalModel>[]) s.id: s.nombre};

    // ----------------------------------------------------------- cálculos
    final total = ventas == null ? null : sumarTotales(ventas);
    final totalAnt = ventasAnt == null ? null : sumarTotales(ventasAnt);
    final ticket = (ventas == null || ventas.isEmpty) ? (ventas == null ? null : 0.0) : total! / ventas.length;
    final ticketAnt = (ventasAnt == null || ventasAnt.isEmpty) ? null : totalAnt! / ventasAnt.length;
    final totalPedidos = (ventas?.length ?? 0) + (cancelados?.length ?? 0);
    final tasaCanc = (cancelados == null || totalPedidos == 0) ? null : cancelados.length / totalPedidos * 100;

    // Series para minigráficos y el gráfico principal: por hora (Hoy) o por día.
    final esHoy = _periodo == PeriodoDashboard.hoy;
    final serieVentas = ventas == null ? null : (esHoy ? porHora(ventas) : porDia(ventas, desde, hasta));
    final seriePedidos =
        ventas == null ? null : (esHoy ? porHora(ventas, contar: true) : porDia(ventas, desde, hasta, contar: true));

    String nombreArchivo() =>
        'ventas_${_periodo.name}_${_hoy.year}-${dosDigitos(_hoy.month)}-${dosDigitos(_hoy.day)}.xlsx';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ----------------------------------------------------- cabecera
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Resumen del negocio', style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  esHoy
                      ? 'Hoy, ${fechaCorta(_hoy)} · comparado con ${_periodo.comparacion}'
                      : '${fechaCorta(desde)} al ${fechaCorta(_hoy)} · comparado con ${_periodo.comparacion}',
                  style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SelectorPeriodo(valor: _periodo, onChanged: (p) => setState(() => _periodo = p)),
                OutlinedButton.icon(
                  onPressed: ventas == null
                      ? null
                      : () => exportarExcel(
                            context,
                            nombreArchivo: nombreArchivo(),
                            pedidos: ventas,
                            nombresSucursal: nombresSucursal,
                            periodo: 'Período: ${_periodo.etiqueta}',
                          ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Exportar'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (sVentas.hasError || sCanc.hasError)
          const TextoError(
            'No se pudieron cargar las ventas. Revisa la conexión o que los índices '
            'de Firestore estén publicados.',
          ),

        // ------------------------------------------------------- KPIs
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            KpiCard(
              icono: Icons.payments_outlined,
              color: semantic.success,
              etiqueta: 'Ventas',
              valor: total == null ? null : bs(total),
              variacion: (total == null || totalAnt == null) ? null : variacionPorcentual(total, totalAnt),
              detalle: 'Pedidos entregados',
              serie: serieVentas,
            ),
            KpiCard(
              icono: Icons.check_circle_outline,
              color: scheme.primary,
              etiqueta: 'Pedidos entregados',
              valor: ventas == null ? null : '${ventas.length}',
              variacion: (ventas == null || ventasAnt == null)
                  ? null
                  : variacionPorcentual(ventas.length.toDouble(), ventasAnt.length.toDouble()),
              detalle: esHoy ? 'Hoy' : 'Promedio ${(ventas?.length ?? 0) ~/ _periodo.dias} por día',
              serie: seriePedidos,
            ),
            KpiCard(
              icono: Icons.receipt_outlined,
              color: semantic.info,
              etiqueta: 'Ticket promedio',
              valor: ticket == null ? null : bs(redondearDinero(ticket)),
              variacion: (ticket == null || ticketAnt == null) ? null : variacionPorcentual(ticket, ticketAnt),
              detalle: 'Gasto promedio por pedido',
            ),
            KpiCard(
              icono: Icons.cancel_outlined,
              color: scheme.error,
              etiqueta: 'Cancelados',
              valor: cancelados == null ? null : '${cancelados.length}',
              variacion: (cancelados == null || canceladosAnt == null)
                  ? null
                  : variacionPorcentual(cancelados.length.toDouble(), canceladosAnt.length.toDouble()),
              subirEsMalo: true,
              detalle: tasaCanc == null ? 'Sin pedidos en el periodo' : '${tasaCanc.toStringAsFixed(1)}% de los pedidos',
            ),
            KpiCard(
              icono: Icons.local_fire_department_outlined,
              color: AppBrand.rojo,
              etiqueta: 'En curso ahora',
              valor: enCurso == null ? null : '${enCurso.length}',
              detalle: 'Pedidos sin terminar',
            ),
            KpiCard(
              icono: Icons.point_of_sale_outlined,
              color: semantic.warning,
              etiqueta: 'Cajas abiertas',
              valor: cajas == null ? null : '${cajas.length}',
              detalle: 'Cobrando ahora',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // --------------------------------------------- evolución de ventas
        PanelDashboard(
          titulo: esHoy ? 'Ventas de hoy por hora' : 'Evolución de las ventas',
          icono: Icons.show_chart_rounded,
          subtitulo: ventas == null
              ? null
              : '${ventas.length} pedidos entregados · ${bs(total ?? 0)} · pasa el mouse sobre el gráfico para ver cada valor',
          child: serieVentas == null
              ? const CargandoSeccion()
              : _graficoVentas(serieVentas, desde, esHoy),
        ),
        const SizedBox(height: AppSpacing.md),

        GrillaDashboard(
          children: [
            _PanelHorasPico(ventas: ventas),
            _PanelEnCurso(enCurso: enCurso, error: sCurso.hasError),
            _PanelTopProductos(entregados: ventas, periodo: _periodo),
            _PanelPagosYModalidad(ventas: ventas, periodo: _periodo),
            _PanelUltimosPedidos(enCurso: enCurso, todas: todas, cancelados: sCanc.data),
            _PanelCajas(cajas: cajas, error: sCajas.hasError),
            _PanelResenas(idNegocio: widget.idNegocio),
            _PanelAlertas(idNegocio: widget.idNegocio, enCurso: enCurso),
          ],
        ),
      ],
    );
  }

  Widget _graficoVentas(List<double> serie, DateTime desde, bool esHoy) {
    if (esHoy) {
      // Solo el tramo del día con actividad (o 08–22 si todavía no hay ventas).
      var primera = serie.indexWhere((v) => v > 0);
      var ultima = serie.lastIndexWhere((v) => v > 0);
      final ahora = DateTime.now().hour;
      if (primera < 0) {
        primera = 8;
        ultima = 22;
      }
      primera = primera.clamp(0, 23).toInt();
      ultima = [ultima, ahora, primera + 3].reduce((a, b) => a > b ? a : b).clamp(0, 23).toInt();
      final tramo = serie.sublist(primera, ultima + 1);
      return GraficoArea(
        valores: tramo,
        etiquetas: [for (var h = primera; h <= ultima; h++) '${dosDigitos(h)}h'],
        formato: compacto,
        cadaEtiqueta: tramo.length > 12 ? 2 : 1,
      );
    }
    final etiquetas = [
      for (var i = 0; i < serie.length; i++)
        serie.length <= 7
            ? diasCortos[desde.add(Duration(days: i)).weekday - 1]
            : fechaCorta(desde.add(Duration(days: i))),
    ];
    if (etiquetas.isNotEmpty) etiquetas[etiquetas.length - 1] = 'Hoy';
    return GraficoArea(
      valores: serie,
      etiquetas: etiquetas,
      formato: compacto,
      cadaEtiqueta: serie.length > 7 ? 5 : 1,
    );
  }
}

// ---------------------------------------------------------------------------
// Horas pico
// ---------------------------------------------------------------------------
class _PanelHorasPico extends StatelessWidget {
  final List<PedidoModel>? ventas;
  const _PanelHorasPico({required this.ventas});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final datos = ventas;
    Widget contenido;
    if (datos == null) {
      contenido = const CargandoSeccion();
    } else if (datos.isEmpty) {
      contenido = const TextoVacio('Todavía no hay ventas en este periodo.');
    } else {
      final porH = porHora(datos, contar: true);
      var primera = porH.indexWhere((v) => v > 0);
      var ultima = porH.lastIndexWhere((v) => v > 0);
      if (ultima - primera < 5) {
        primera = (primera - 2).clamp(0, 23).toInt();
        ultima = (ultima + 2).clamp(0, 23).toInt();
      }
      final tramo = porH.sublist(primera, ultima + 1);
      final pico = porH.indexOf(porH.reduce((a, b) => a > b ? a : b));
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GraficoBarras(
            valores: tramo,
            etiquetas: [for (var h = primera; h <= ultima; h++) dosDigitos(h)],
            formato: (v) => v.toStringAsFixed(0),
            alto: 160,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Hora con más pedidos: ${dosDigitos(pico)}:00 a ${dosDigitos((pico + 1) % 24)}:00 '
            '(${porH[pico].toStringAsFixed(0)} pedidos).',
            style: texto.bodySmall,
          ),
        ],
      );
    }
    return PanelDashboard(
      titulo: 'Horas pico',
      icono: Icons.schedule_rounded,
      subtitulo: 'Pedidos entregados según la hora en que se hicieron',
      child: contenido,
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
// Productos más vendidos
// ---------------------------------------------------------------------------
class _PanelTopProductos extends StatefulWidget {
  final List<PedidoModel>? entregados;
  final PeriodoDashboard periodo;
  const _PanelTopProductos({required this.entregados, required this.periodo});

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

  /// Solo vuelve a leer el detalle si cambió el conjunto de pedidos.
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
      contenido = const TextoVacio('Todavía no hay ventas en este periodo.');
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
      subtitulo: '${widget.periodo == PeriodoDashboard.hoy ? 'Hoy' : 'Últimos ${widget.periodo.dias} días'}, por unidades',
      child: contenido,
    );
  }
}

// ---------------------------------------------------------------------------
// Métodos de pago y modalidad
// ---------------------------------------------------------------------------
class _PanelPagosYModalidad extends StatelessWidget {
  final List<PedidoModel>? ventas;
  final PeriodoDashboard periodo;
  const _PanelPagosYModalidad({required this.ventas, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final semantic = context.semanticColors;
    final datos = ventas;
    return PanelDashboard(
      titulo: 'Cómo compran tus clientes',
      icono: Icons.pie_chart_outline_rounded,
      subtitulo: periodo == PeriodoDashboard.hoy ? 'Ventas de hoy' : 'Ventas de los últimos ${periodo.dias} días',
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
                  vacio: 'Todavía no hay ventas en este periodo.',
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
                  vacio: 'Todavía no hay ventas en este periodo.',
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Últimos pedidos
// ---------------------------------------------------------------------------
class _PanelUltimosPedidos extends StatelessWidget {
  final List<PedidoModel>? enCurso;
  final List<PedidoModel>? todas;
  final List<PedidoModel>? cancelados;
  const _PanelUltimosPedidos({required this.enCurso, required this.todas, required this.cancelados});

  AppStatusTone _tono(String estado) => switch (estado) {
        PedidoEstado.entregado => AppStatusTone.success,
        PedidoEstado.cancelado => AppStatusTone.danger,
        PedidoEstado.pendiente => AppStatusTone.neutral,
        _ => AppStatusTone.warning,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    Widget contenido;
    if (enCurso == null || todas == null) {
      contenido = const CargandoSeccion();
    } else {
      final ultimos = [...enCurso!, ...todas!, ...?cancelados]
        ..sort((a, b) => (b.fechaCreacion ?? DateTime.now()).compareTo(a.fechaCreacion ?? DateTime.now()));
      final lista = ultimos.take(6).toList();
      contenido = lista.isEmpty
          ? const TextoVacio('Todavía no hay pedidos.')
          : Column(
              children: [
                for (final p in lista)
                  InkWell(
                    borderRadius: AppRadius.mdAll,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${p.id.substring(0, 6)} · ${p.etiquetaModalidad}',
                                  style: texto.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  p.fechaCreacion == null
                                      ? p.metodoPago
                                      : '${fechaCorta(p.fechaCreacion!)} ${horaCorta(p.fechaCreacion!)} · ${p.metodoPago}',
                                  style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(bs(p.total), style: texto.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(width: AppSpacing.sm),
                          AppStatusBadge(label: p.estado, tone: _tono(p.estado)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
    }
    return PanelDashboard(
      titulo: 'Últimos pedidos',
      icono: Icons.receipt_long_outlined,
      subtitulo: 'Toca un pedido para ver el detalle',
      child: contenido,
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
                  '${c.fechaApertura == null ? '' : ' · desde las ${horaCorta(c.fechaApertura!)}'}'
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
    final scheme = Theme.of(context).colorScheme;
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
          final ultima = visibles.where((r) => r.comentario.trim().isNotEmpty).firstOrNull;
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
              if (ultima != null) ...[
                const Divider(),
                Text(
                  '"${ultima.comentario.trim()}"',
                  style: texto.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '— ${ultima.nombreCliente} · ${'★' * ultima.calificacion}',
                  style: texto.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
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
              final pocoStock = sProd.data!.where((p) => p.estado && p.disponible && p.pocoStock).toList();
              final programados = (widget.enCurso ?? const <PedidoModel>[])
                  .where((p) => p.esParaMasTarde)
                  .length;
              final activas = sSuc.data!.where((s) => s.estado).toList();
              final cerradas = activas.where((s) => !s.estadoApertura().abierta).toList();
              final bloqueados = sCli.data!.where((c) => c.bloqueado).length;
              final demorados = (widget.enCurso ?? const <PedidoModel>[])
                  .where((p) =>
                      p.estado == PedidoEstado.pendiente &&
                      !p.esParaMasTarde &&
                      minutosDesde(p.programadoPara ?? p.fechaCreacion) >= 15)
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
                if (pocoStock.isNotEmpty)
                  FilaIndicador(
                    icono: Icons.inventory_2_outlined,
                    color: semantic.warning,
                    texto: 'Poco stock: ${pocoStock.take(3).map((p) => '${p.nombre} (${p.stock})').join(', ')}'
                        '${pocoStock.length > 3 ? '…' : ''}',
                    valor: '${pocoStock.length}',
                  ),
                if (programados > 0)
                  FilaIndicador(
                    icono: Icons.schedule,
                    color: semantic.info,
                    texto: 'Pedidos programados para más tarde',
                    valor: '$programados',
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
