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
  late final DateTime _hoy = inicioDelDia(DateTime.now());
  late final Stream<List<PedidoModel>> _pedidos =
      DashboardService.instancia.streamPedidosPlataforma(_hoy.subtract(const Duration(days: 13)));
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

    final hoyPedidos = pedidos == null ? null : pedidosDelDia(pedidos, _hoy);
    final hoyVentas = hoyPedidos?.where((p) => p.estado == PedidoEstado.entregado).toList();
    final inicioSemana = _hoy.subtract(const Duration(days: 6));
    final semana = pedidos == null
        ? null
        : pedidosEntre(pedidos, inicioSemana, _hoy.add(const Duration(days: 1)));
    final semanaAnterior = pedidos == null
        ? null
        : pedidosEntre(pedidos, _hoy.subtract(const Duration(days: 13)), inicioSemana);
    final activos = negocios?.where((n) => n.estado).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hoy en la plataforma', style: texto.titleMedium),
        const SizedBox(height: AppSpacing.md),
        if (sPed.hasError)
          const TextoError('No se pudieron cargar los pedidos de la plataforma.'),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
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
            AppMetricaCard(
              icon: Icons.people_outline,
              color: semantic.info,
              etiqueta: 'Clientes registrados',
              valor: clientes == null ? null : '${clientes.length}',
            ),
            AppMetricaCard(
              icon: Icons.receipt_long_outlined,
              color: AppBrand.rojo,
              etiqueta: 'Pedidos de hoy',
              valor: hoyPedidos == null ? null : '${hoyPedidos.length}',
              detalle: 'En todos los negocios',
            ),
            AppMetricaCard(
              icon: Icons.payments_outlined,
              color: semantic.success,
              etiqueta: 'Ventas de hoy',
              valor: hoyVentas == null ? null : bs(sumarTotales(hoyVentas)),
              detalle: 'Pedidos entregados',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GrillaDashboard(
          children: [
            _PanelVentasPlataforma(semana: semana, semanaAnterior: semanaAnterior, hoy: _hoy),
            _PanelRankingNegocios(semana: semana, negocios: negocios),
            _PanelEstadoPedidos(semana: semana),
            _PanelClientes(clientes: clientes, hoy: _hoy),
            _PanelAtencionPlataforma(negocios: negocios, admins: admins),
          ],
        ),
      ],
    );
  }
}

class _PanelVentasPlataforma extends StatelessWidget {
  final List<PedidoModel>? semana;
  final List<PedidoModel>? semanaAnterior;
  final DateTime hoy;
  const _PanelVentasPlataforma({required this.semana, required this.semanaAnterior, required this.hoy});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;
    final datos = semana;
    if (datos == null) {
      return const PanelDashboard(
        titulo: 'Ventas de la plataforma (7 días)',
        icono: Icons.bar_chart_rounded,
        child: CargandoSeccion(),
      );
    }
    final entregados = datos.where((p) => p.estado == PedidoEstado.entregado).toList();
    final dias = [for (var i = 6; i >= 0; i--) hoy.subtract(Duration(days: i))];
    final valores = [for (final d in dias) sumarTotales(pedidosDelDia(entregados, d))];
    final etiquetas = [
      for (var i = 0; i < dias.length; i++) i == dias.length - 1 ? 'Hoy' : diasCortos[dias[i].weekday - 1],
    ];
    final total = sumarTotales(entregados);
    final anterior = sumarTotales(
      (semanaAnterior ?? const <PedidoModel>[]).where((p) => p.estado == PedidoEstado.entregado),
    );
    final variacion = variacionPorcentual(total, anterior);
    return PanelDashboard(
      titulo: 'Ventas de la plataforma (7 días)',
      icono: Icons.bar_chart_rounded,
      subtitulo: '${entregados.length} pedidos entregados · ${bs(total)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GraficoBarras(
            valores: valores,
            etiquetas: etiquetas,
            formato: (v) => v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
          ),
          const SizedBox(height: AppSpacing.sm),
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
        ],
      ),
    );
  }
}

class _PanelRankingNegocios extends StatelessWidget {
  final List<PedidoModel>? semana;
  final List<NegocioModel>? negocios;
  const _PanelRankingNegocios({required this.semana, required this.negocios});

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
        contenido = const TextoVacio('Ningún negocio recibió pedidos en los últimos 7 días.');
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
      subtitulo: 'Últimos 7 días',
      child: contenido,
    );
  }
}

class _PanelEstadoPedidos extends StatelessWidget {
  final List<PedidoModel>? semana;
  const _PanelEstadoPedidos({required this.semana});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final texto = Theme.of(context).textTheme;
    final datos = semana;
    Widget contenido;
    if (datos == null) {
      contenido = const CargandoSeccion();
    } else if (datos.isEmpty) {
      contenido = const TextoVacio('No hubo pedidos en los últimos 7 días.');
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
      titulo: 'Pedidos de la semana',
      icono: Icons.receipt_long_outlined,
      subtitulo: 'Todos los negocios, últimos 7 días',
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
