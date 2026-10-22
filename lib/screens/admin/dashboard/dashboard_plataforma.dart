import 'package:flutter/material.dart';

import '../../../models/negocio_model.dart';
import '../../../models/pedido_models.dart';
import '../../../models/usuario_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/dashboard_service.dart';
import '../../../services/negocio_service.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/app_metrica_card.dart';
import 'dashboard_comun.dart';
import 'dashboard_graficos.dart';

/// Panel del SuperAdmin: cómo va toda la plataforma (todos los negocios),
/// con datos reales de Firestore.
///
/// - Hoy: negocios activos, administradores, clientes, pedidos y ventas.
/// - Últimos 7 días: ventas por día, ranking de negocios, estado de los
///   pedidos y clientes nuevos.
/// - Atención: negocios desactivados o sin administrador.
class DashboardPlataforma extends StatefulWidget {
  const DashboardPlataforma({super.key});

  @override
  State<DashboardPlataforma> createState() => _DashboardPlataformaState();
}

class _DashboardPlataformaState extends State<DashboardPlataforma> {
  PeriodoDashboard _periodo = PeriodoDashboard.semana;
  late final DateTime _hoy = inicioDelDia(DateTime.now());
  // 60 días: el periodo más largo (30) y su anterior; cambiar de periodo
  // solo recalcula en memoria.
  late final Stream<List<PedidoModel>> _pedidos =
      DashboardService.instancia.streamPedidosPlataforma(_hoy.subtract(const Duration(days: 59)));
  late final Stream<List<NegocioModel>> _negocios = NegocioService.instancia.streamNegocios();
  late final Stream<List<UsuarioModel>> _admins = AdminService.instancia.streamAdministradores();
  late final Stream<List<UsuarioModel>> _clientes = AdminService.instancia.streamTodosLosClientes();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PedidoModel>>(
      stream: _pedidos,
      builder: (context, sPed) => StreamBuilder<List<NegocioModel>>(
        stream: _negocios,
        builder: (context, sNeg) => StreamBuilder<List<UsuarioModel>>(
          stream: _admins,
          builder: (context, sAdm) => StreamBuilder<List<UsuarioModel>>(
            stream: _clientes,
            builder: (context, sCli) => _contenido(context, sPed, sNeg, sAdm, sCli),
          ),
        ),
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    AsyncSnapshot<List<PedidoModel>> sPed,
    AsyncSnapshot<List<NegocioModel>> sNeg,
    AsyncSnapshot<List<UsuarioModel>> sAdm,
    AsyncSnapshot<List<UsuarioModel>> sCli,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;

    final pedidos = sPed.data;
    final negocios = sNeg.data;
    final admins = sAdm.data;
    final clientes = sCli.data;

    final (desde, hasta) = _periodo.rango(_hoy);
    final (desdeAnt, hastaAnt) = _periodo.rangoAnterior(_hoy);
    final esHoy = _periodo == PeriodoDashboard.hoy;

    final periodo = pedidos == null ? null : pedidosEntre(pedidos, desde, hasta);
    final anterior = pedidos == null ? null : pedidosEntre(pedidos, desdeAnt, hastaAnt);
    List<PedidoModel>? entregados(List<PedidoModel>? l) =>
        l?.where((p) => p.estado == PedidoEstado.entregado).toList();
    final ventas = entregados(periodo);
    final ventasAnt = entregados(anterior);
    final total = ventas == null ? null : sumarTotales(ventas);
    final totalAnt = ventasAnt == null ? null : sumarTotales(ventasAnt);
    final activos = negocios?.where((n) => n.estado).length;
    final clientesNuevos = clientes?.where((c) {
      final f = c.fechaRegistro;
      return f != null && !f.isBefore(desde) && f.isBefore(hasta);
    }).length;
    final clientesNuevosAnt = clientes?.where((c) {
      final f = c.fechaRegistro;
      return f != null && !f.isBefore(desdeAnt) && f.isBefore(hastaAnt);
    }).length;
    final serieVentas = ventas == null ? null : (esHoy ? porHora(ventas) : porDia(ventas, desde, hasta));
    final seriePedidos = periodo == null
        ? null
        : (esHoy ? porHora(periodo, contar: true) : porDia(periodo, desde, hasta, contar: true));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('La plataforma', style: texto.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  esHoy
                      ? 'Hoy, ${fechaCorta(_hoy)} · comparado con ${_periodo.comparacion}'
                      : '${fechaCorta(desde)} al ${fechaCorta(_hoy)} · comparado con ${_periodo.comparacion}',
                  style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            SelectorPeriodo(valor: _periodo, onChanged: (p) => setState(() => _periodo = p)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (sPed.hasError)
          const TextoError('No se pudieron cargar los pedidos de la plataforma.'),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            KpiCard(
              icono: Icons.payments_outlined,
              color: semantic.success,
              etiqueta: 'Ventas de la plataforma',
              valor: total == null ? null : bs(total),
              variacion: (total == null || totalAnt == null) ? null : variacionPorcentual(total, totalAnt),
              detalle: 'Pedidos entregados',
              serie: serieVentas,
            ),
            KpiCard(
              icono: Icons.receipt_long_outlined,
              color: AppBrand.rojo,
              etiqueta: 'Pedidos',
              valor: periodo == null ? null : '${periodo.length}',
              variacion: (periodo == null || anterior == null)
                  ? null
                  : variacionPorcentual(periodo.length.toDouble(), anterior.length.toDouble()),
              detalle: 'En todos los negocios',
              serie: seriePedidos,
            ),
            KpiCard(
              icono: Icons.person_add_alt_outlined,
              color: semantic.info,
              etiqueta: 'Clientes nuevos',
              valor: clientesNuevos == null ? null : '$clientesNuevos',
              variacion: (clientesNuevos == null || clientesNuevosAnt == null)
                  ? null
                  : variacionPorcentual(clientesNuevos.toDouble(), clientesNuevosAnt.toDouble()),
              detalle: clientes == null ? null : '${clientes.length} registrados en total',
            ),
            AppMetricaCard(
              icon: Icons.storefront_outlined,
              color: scheme.primary,
              etiqueta: 'Negocios activos',
              valor: negocios == null ? null : '$activos de ${negocios.length}',
            ),
            AppMetricaCard(
              icon: Icons.admin_panel_settings_outlined,
              color: semantic.warning,
              etiqueta: 'Administradores',
              valor: admins == null ? null : '${admins.length}',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        PanelDashboard(
          titulo: esHoy ? 'Ventas de hoy por hora' : 'Evolución de las ventas',
          icono: Icons.show_chart_rounded,
          subtitulo: ventas == null ? null : '${ventas.length} pedidos entregados · ${bs(total ?? 0)}',
          child: serieVentas == null ? const CargandoSeccion() : _grafico(serieVentas, desde, esHoy),
        ),
        const SizedBox(height: AppSpacing.md),
        GrillaDashboard(
          children: [
            _PanelRankingNegocios(semana: periodo, negocios: negocios, periodo: _periodo),
            _PanelEstadoPedidos(semana: periodo, periodo: _periodo),
            _PanelClientes(clientes: clientes, hoy: _hoy),
            _PanelAtencionPlataforma(negocios: negocios, admins: admins),
          ],
        ),
      ],
    );
  }

  Widget _grafico(List<double> serie, DateTime desde, bool esHoy) {
    if (esHoy) {
      final ahora = DateTime.now().hour;
      final fin = ahora < 8 ? 8 : ahora;
      final tramo = serie.sublist(6, fin + 1);
      return GraficoArea(
        valores: tramo,
        etiquetas: [for (var h = 6; h <= fin; h++) '${dosDigitos(h)}h'],
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
    etiquetas[etiquetas.length - 1] = 'Hoy';
    return GraficoArea(
      valores: serie,
      etiquetas: etiquetas,
      formato: compacto,
      cadaEtiqueta: serie.length > 7 ? 5 : 1,
    );
  }
}

class _PanelRankingNegocios extends StatelessWidget {
  final List<PedidoModel>? semana;
  final List<NegocioModel>? negocios;
  final PeriodoDashboard periodo;
  const _PanelRankingNegocios({required this.semana, required this.negocios, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = Theme.of(context).textTheme;
    final datos = semana;
    final lista = negocios;
    Widget contenido;
    if (datos == null || lista == null) {
      contenido = const CargandoSeccion();
    } else {
      final nombres = {for (final n in lista) n.idNegocio: n.nombre};
      final entregados = datos.where((p) => p.estado == PedidoEstado.entregado);
      final ventas = agruparSuma(entregados, (p) => p.idNegocio);
      final pedidosPorNegocio = agruparConteo(datos, (p) => p.idNegocio);
      final cancelados = agruparConteo(
        datos.where((p) => p.estado == PedidoEstado.cancelado),
        (p) => p.idNegocio,
      );
      final orden = pedidosPorNegocio.keys.toList()
        ..sort((a, b) => (ventas[b] ?? 0).compareTo(ventas[a] ?? 0));
      if (orden.isEmpty) {
        contenido = const TextoVacio('Ningún negocio recibió pedidos en este periodo.');
      } else {
        contenido = Column(
          children: [
            for (var i = 0; i < orden.length && i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
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
                          Text(
                            nombres[orden[i]] ?? 'Negocio eliminado',
                            style: texto.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${pedidosPorNegocio[orden[i]]} pedidos'
                            '${(cancelados[orden[i]] ?? 0) > 0 ? ' · ${cancelados[orden[i]]} cancelados' : ''}',
                            style: texto.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(bs(ventas[orden[i]] ?? 0), style: texto.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        );
      }
    }
    return PanelDashboard(
      titulo: 'Negocios con más ventas',
      icono: Icons.emoji_events_outlined,
      subtitulo: periodo == PeriodoDashboard.hoy ? 'Hoy' : 'Últimos ${periodo.dias} días',
      child: contenido,
    );
  }
}

class _PanelEstadoPedidos extends StatelessWidget {
  final List<PedidoModel>? semana;
  final PeriodoDashboard periodo;
  const _PanelEstadoPedidos({required this.semana, required this.periodo});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;
    final datos = semana;
    Widget contenido;
    if (datos == null) {
      contenido = const CargandoSeccion();
    } else if (datos.isEmpty) {
      contenido = const TextoVacio('No hubo pedidos en este periodo.');
    } else {
      final entregados = datos.where((p) => p.estado == PedidoEstado.entregado).length;
      final cancelados = datos.where((p) => p.estado == PedidoEstado.cancelado).length;
      final enCurso = datos.length - entregados - cancelados;
      final tasa = cancelados / datos.length * 100;
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListaProporciones(
            datos: {
              'Entregados': entregados.toDouble(),
              'En curso': enCurso.toDouble(),
              'Cancelados': cancelados.toDouble(),
            },
            formato: (v) => v.toStringAsFixed(0),
            colores: {
              'Entregados': semantic.success,
              'En curso': semantic.info,
              'Cancelados': Theme.of(context).colorScheme.error,
            },
          ),
          Text(
            'Tasa de cancelación: ${tasa.toStringAsFixed(1)}% de ${datos.length} pedidos.',
            style: texto.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Modalidad', style: texto.labelLarge),
          const SizedBox(height: AppSpacing.sm),
          ListaProporciones(
            datos: agruparConteo(datos, (p) => p.modalidad).map((k, v) => MapEntry(k, v.toDouble())),
            formato: (v) => v.toStringAsFixed(0),
          ),
        ],
      );
    }
    return PanelDashboard(
      titulo: 'Estado de los pedidos',
      icono: Icons.receipt_long_outlined,
      subtitulo: periodo == PeriodoDashboard.hoy
          ? 'Todos los negocios, hoy'
          : 'Todos los negocios, últimos ${periodo.dias} días',
      child: contenido,
    );
  }
}

class _PanelClientes extends StatelessWidget {
  final List<UsuarioModel>? clientes;
  final DateTime hoy;
  const _PanelClientes({required this.clientes, required this.hoy});

  @override
  Widget build(BuildContext context) {
    final lista = clientes;
    Widget contenido;
    if (lista == null) {
      contenido = const CargandoSeccion();
    } else {
      final dias = [for (var i = 6; i >= 0; i--) hoy.subtract(Duration(days: i))];
      final valores = [
        for (final d in dias)
          lista
              .where((c) {
                final f = c.fechaRegistro;
                return f != null && inicioDelDia(f) == d;
              })
              .length
              .toDouble(),
      ];
      final nuevos = valores.fold<double>(0, (a, b) => a + b).round();
      contenido = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GraficoBarras(
            alto: 140,
            valores: valores,
            etiquetas: [
              for (var i = 0; i < dias.length; i++) i == dias.length - 1 ? 'Hoy' : diasCortos[dias[i].weekday - 1],
            ],
            formato: (v) => v.toStringAsFixed(0),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$nuevos clientes nuevos esta semana · ${lista.length} en total',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }
    return PanelDashboard(
      titulo: 'Clientes nuevos',
      icono: Icons.person_add_alt_outlined,
      subtitulo: 'Registros por día, últimos 7 días',
      child: contenido,
    );
  }
}

class _PanelAtencionPlataforma extends StatelessWidget {
  final List<NegocioModel>? negocios;
  final List<UsuarioModel>? admins;
  const _PanelAtencionPlataforma({required this.negocios, required this.admins});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final neg = negocios;
    final adm = admins;
    Widget contenido;
    if (neg == null || adm == null) {
      contenido = const CargandoSeccion();
    } else {
      final inactivos = neg.where((n) => !n.estado).toList();
      final conAdmin = adm.where((a) => a.estado).map((a) => a.idNegocio).whereType<String>().toSet();
      final sinAdmin = neg.where((n) => n.estado && !conAdmin.contains(n.idNegocio)).toList();
      final adminsSinNegocio = adm.where((a) => (a.idNegocio ?? '').isEmpty).length;
      final adminsInactivos = adm.where((a) => !a.estado).length;
      final filas = <Widget>[
        if (sinAdmin.isNotEmpty)
          FilaIndicador(
            icono: Icons.person_off_outlined,
            color: scheme.error,
            texto: 'Negocios sin administrador activo: ${sinAdmin.map((n) => n.nombre).join(', ')}',
            valor: '${sinAdmin.length}',
          ),
        if (inactivos.isNotEmpty)
          FilaIndicador(
            icono: Icons.store_mall_directory_outlined,
            color: semantic.warning,
            texto: 'Negocios desactivados: ${inactivos.map((n) => n.nombre).join(', ')}',
            valor: '${inactivos.length}',
          ),
        if (adminsSinNegocio > 0)
          FilaIndicador(
            icono: Icons.link_off_rounded,
            color: semantic.info,
            texto: 'Administradores sin negocio asignado',
            valor: '$adminsSinNegocio',
          ),
        if (adminsInactivos > 0)
          FilaIndicador(
            icono: Icons.block_outlined,
            color: scheme.onSurfaceVariant,
            texto: 'Administradores desactivados',
            valor: '$adminsInactivos',
          ),
      ];
      contenido = filas.isEmpty
          ? FilaIndicador(
              icono: Icons.check_circle_outline,
              color: semantic.success,
              texto: 'Todo en orden por ahora.',
              valor: '',
            )
          : Column(children: filas);
    }
    return PanelDashboard(
      titulo: 'Atención',
      icono: Icons.notifications_active_outlined,
      subtitulo: 'Lo que conviene revisar',
      child: contenido,
    );
  }
}
