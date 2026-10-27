import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/mesa_model.dart';
import '../../models/pedido_models.dart';
import '../../services/caja_service.dart';
import '../../services/mesa_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/panel_personal.dart';
import '../../widgets/tarjeta_pedido_personal.dart';
import '../cliente/pedido_detalle_screen.dart';
import 'cajero_pedido_mesa_screen.dart';

/// Cómo se ve una mesa en el plano.
enum EstadoVisualMesa { libre, ocupada, porCobrar, reservada }

/// Estado que se pinta en el plano: una mesa ocupada cuyos pedidos ya se
/// entregaron todos está "por cobrar".
EstadoVisualMesa estadoVisualMesa(MesaModel mesa, List<PedidoModel> cuenta) {
  if (mesa.estado == MesaEstado.reservada) return EstadoVisualMesa.reservada;
  if (mesa.estado != MesaEstado.ocupada) return EstadoVisualMesa.libre;
  final activos = cuenta.where((p) => p.estado != PedidoEstado.cancelado).toList();
  if (activos.isNotEmpty && activos.every((p) => p.estado == PedidoEstado.entregado)) {
    return EstadoVisualMesa.porCobrar;
  }
  return EstadoVisualMesa.ocupada;
}

/// Total de la cuenta abierta de una mesa (sin los pedidos cancelados).
double totalCuentaMesa(List<PedidoModel> cuenta) => cuenta
    .where((p) => p.estado != PedidoEstado.cancelado)
    .fold(0.0, (a, p) => a + p.total);

/// HU-32: el Cajero gestiona las mesas de su sucursal como un plano: cada
/// mesa con su color (libre, ocupada, por cobrar, reservada), cuánto lleva
/// su cuenta y desde cuándo. Al tocar una mesa se asigna, se toma su
/// pedido o se cobra y se libera.
class CajeroMesasScreen extends StatefulWidget {
  const CajeroMesasScreen({super.key});

  @override
  State<CajeroMesasScreen> createState() => _CajeroMesasScreenState();
}

class _CajeroMesasScreenState extends State<CajeroMesasScreen> {
  EstadoVisualMesa? _filtro;

  late final String? _idSucursal = SesionActual.instancia.idSucursal;
  late final String? _idNegocio = SesionActual.instancia.idNegocio;
  late final Stream<List<MesaModel>>? _mesas =
      _idSucursal == null ? null : MesaService.instancia.streamMesas(_idSucursal);
  late final Stream<List<PedidoModel>>? _cuentas = _idSucursal == null || _idNegocio == null
      ? null
      : PedidoService.instancia.streamCuentasAbiertas(_idNegocio, _idSucursal);

  Future<void> _nuevaMesa(String idSucursal) async {
    final numeroCtrl = TextEditingController();
    final capacidadCtrl = TextEditingController(text: '4');
    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Nueva mesa')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numeroCtrl,
              autofocus: true,
              decoration: InputDecoration(labelText: tr('Número o nombre de la mesa')),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: capacidadCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('Capacidad (personas)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('Cancelar'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('Crear'))),
        ],
      ),
    );
    if (crear != true || numeroCtrl.text.trim().isEmpty) return;
    await MesaService.instancia.guardarMesa(
      idSucursal,
      MesaModel(
        id: '',
        numero: numeroCtrl.text.trim(),
        capacidad: int.tryParse(capacidadCtrl.text) ?? 4,
        idNegocio: SesionActual.instancia.idNegocio,
      ),
    );
  }

  /// El cliente llegó y el Cajero le asigna esta mesa. Lo único que se
  /// pregunta es para cuántas personas es (opcional).
  Future<void> _asignarMesa(String idSucursal, MesaModel mesa) async {
    final personasCtrl = TextEditingController();
    final asignar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Asignar mesa {numero}', {'numero': mesa.numero})),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Esta mesa es para {n} personas.', {'n': mesa.capacidad})),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: personasCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr('¿Para cuántas personas? (opcional)')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('Cancelar'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('Asignar'))),
        ],
      ),
    );
    if (asignar != true) return;
    final personas = int.tryParse(personasCtrl.text.trim());
    try {
      await MesaService.instancia.asignarMesa(
        idSucursal,
        mesa.id,
        personas: (personas != null && personas > 0) ? personas : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(textoError(e))));
    }
  }

  void _tomarPedido(String idSucursal, MesaModel mesa) {
    final s = SesionActual.instancia;
    if (s.esCajero && !s.permisos.cajeroTomaPedidosMesa) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Tu Administrador desactivó la toma de pedidos en mesa para cajeros.')),
      ));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CajeroPedidoMesaScreen(mesa: mesa, idSucursal: idSucursal)),
    );
  }

  /// Opciones de una mesa libre o reservada.
  Future<void> _opcionesMesaLibre(String idSucursal, MesaModel mesa) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                tr('Mesa {numero}', {'numero': mesa.numero}),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(tr('Capacidad: {n} personas', {'n': mesa.capacidad})),
            ),
            ListTile(
              leading: const Icon(Icons.event_seat_outlined),
              title: Text(tr('Asignar a clientes')),
              onTap: () => Navigator.pop(ctx, 'asignar'),
            ),
            for (final e in MesaEstado.todos)
              if (e != mesa.estado && e != MesaEstado.ocupada)
                ListTile(
                  leading: Icon(e == MesaEstado.reservada ? Icons.bookmark_outline : Icons.check_circle_outline),
                  title: Text(tr('Marcar como {estado}', {'estado': tr(e)})),
                  onTap: () => Navigator.pop(ctx, e),
                ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (opcion == null || !mounted) return;
    if (opcion == 'asignar') {
      await _asignarMesa(idSucursal, mesa);
    } else {
      await MesaService.instancia.cambiarEstado(idSucursal, mesa.id, opcion);
    }
  }

  void _verCuenta(String idSucursal, MesaModel mesa) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _CuentaMesaSheet(
        mesa: mesa,
        idSucursal: idSucursal,
        onTomarPedido: () => _tomarPedido(idSucursal, mesa),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final idSucursal = _idSucursal;
    final mesas = _mesas;
    final cuentas = _cuentas;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mesas'))),
      floatingActionButton: idSucursal == null
          ? null
          : FloatingActionButton.extended(
              tooltip: tr('Nueva mesa'),
              onPressed: () => _nuevaMesa(idSucursal),
              icon: const Icon(Icons.add),
              label: Text(tr('Mesa')),
            ),
      body: idSucursal == null || mesas == null || cuentas == null
          ? Center(child: Text(tr('No tienes una sucursal asignada.')))
          : StreamBuilder<List<MesaModel>>(
              stream: mesas,
              builder: (context, sMesas) => StreamBuilder<List<PedidoModel>>(
                stream: cuentas,
                builder: (context, sCuentas) {
                  if (sMesas.hasError) return Center(child: Text(textoError(sMesas.error!)));
                  if (!sMesas.hasData) return const Center(child: CircularProgressIndicator());
                  final lista = sMesas.data!;
                  if (lista.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.table_bar_outlined,
                      title: tr('Todavía no hay mesas registradas'),
                      actionLabel: tr('Nueva mesa'),
                      onAction: () => _nuevaMesa(idSucursal),
                    );
                  }
                  return _plano(context, idSucursal, lista, sCuentas.data ?? const <PedidoModel>[]);
                },
              ),
            ),
    );
  }

  Widget _plano(BuildContext context, String idSucursal, List<MesaModel> mesas, List<PedidoModel> pedidos) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final porMesa = <String, List<PedidoModel>>{};
    for (final p in pedidos) {
      final id = p.idMesa;
      if (id != null) porMesa.putIfAbsent(id, () => []).add(p);
    }
    final estados = {
      for (final m in mesas) m.id: estadoVisualMesa(m, porMesa[m.id] ?? const []),
    };
    int cuantas(EstadoVisualMesa e) => estados.values.where((v) => v == e).length;
    final ocupadas = cuantas(EstadoVisualMesa.ocupada) + cuantas(EstadoVisualMesa.porCobrar);
    final enCuentas = [
      for (final m in mesas)
        if (m.estado == MesaEstado.ocupada) totalCuentaMesa(porMesa[m.id] ?? const []),
    ].fold(0.0, (a, b) => a + b);

    final visibles = [
      for (final m in mesas)
        if (_filtro == null ||
            estados[m.id] == _filtro ||
            (_filtro == EstadoVisualMesa.ocupada && estados[m.id] == EstadoVisualMesa.porCobrar))
          m,
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm + 4),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResumenTurno(datos: [
                  DatoTurno('${cuantas(EstadoVisualMesa.libre)}', tr('mesas libres'),
                      icono: Icons.check_circle_outline, color: semantic.success),
                  DatoTurno('$ocupadas', tr('mesas ocupadas'), icono: Icons.groups_outlined),
                  DatoTurno('${cuantas(EstadoVisualMesa.porCobrar)}', tr('esperando cobro'),
                      icono: Icons.payments_outlined, color: scheme.error),
                  DatoTurno(dinero(enCuentas), tr('en cuentas abiertas'), icono: Icons.receipt_long_outlined),
                ]),
                const SizedBox(height: AppSpacing.sm + 4),
                PildorasFiltro<EstadoVisualMesa?>(
                  seleccion: _filtro,
                  onChanged: (f) => setState(() => _filtro = f),
                  opciones: [
                    OpcionPildora(null, tr('Todas'), contador: mesas.length),
                    OpcionPildora(EstadoVisualMesa.libre, tr('Libres'), contador: cuantas(EstadoVisualMesa.libre)),
                    OpcionPildora(EstadoVisualMesa.ocupada, tr('Ocupadas'), contador: ocupadas),
                    OpcionPildora(EstadoVisualMesa.porCobrar, tr('Por cobrar'),
                        contador: cuantas(EstadoVisualMesa.porCobrar)),
                    OpcionPildora(EstadoVisualMesa.reservada, tr('Reservadas'),
                        contador: cuantas(EstadoVisualMesa.reservada)),
                  ],
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: AppSpacing.sm + 2,
              crossAxisSpacing: AppSpacing.sm + 2,
              childAspectRatio: 1.05,
            ),
            delegate: SliverChildBuilderDelegate(
              childCount: visibles.length,
              (context, i) {
                final m = visibles[i];
                final estado = estados[m.id]!;
                return _MesaEnPlano(
                  mesa: m,
                  estado: estado,
                  cuenta: porMesa[m.id] ?? const [],
                  onTap: () => m.estado == MesaEstado.ocupada
                      ? _verCuenta(idSucursal, m)
                      : _opcionesMesaLibre(idSucursal, m),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Una mesa del plano: número grande y, según su estado, "Libre" o hace
/// cuánto está ocupada y cuánto lleva la cuenta.
class _MesaEnPlano extends StatelessWidget {
  final MesaModel mesa;
  final EstadoVisualMesa estado;
  final List<PedidoModel> cuenta;
  final VoidCallback onTap;

  const _MesaEnPlano({required this.mesa, required this.estado, required this.cuenta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final Color color;
    final String detalle;
    final activos = cuenta.where((p) => p.estado != PedidoEstado.cancelado).toList();
    DateTime? desde;
    for (final p in activos) {
      final f = p.fechaCreacion;
      if (f != null && (desde == null || f.isBefore(desde))) desde = f;
    }
    final total = totalCuentaMesa(cuenta);
    final tiempo = desde == null ? '' : duracionCorta(minutosTranscurridos(desde));
    switch (estado) {
      case EstadoVisualMesa.libre:
        color = semantic.success;
        detalle = tr('Libre');
        break;
      case EstadoVisualMesa.reservada:
        color = semantic.warning;
        detalle = tr('Reservada');
        break;
      case EstadoVisualMesa.porCobrar:
        color = scheme.error;
        detalle = '${tr('Por cobrar')} · ${dinero(total)}';
        break;
      case EstadoVisualMesa.ocupada:
        color = scheme.primary;
        detalle = activos.isEmpty
            ? tr('Sin pedidos todavía')
            : '$tiempo · ${dinero(total)}';
        break;
    }
    final listos = activos.where((p) => p.estado == PedidoEstado.listo).length;
    return Semantics(
      button: true,
      label: tr('Mesa {numero}: {detalle}', {'numero': mesa.numero, 'detalle': detalle}),
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgAll,
          side: BorderSide(color: color.withValues(alpha: 0.65), width: 1.5),
        ),
        child: InkWell(
          borderRadius: AppRadius.lgAll,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          mesa.numero,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detalle,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (mesa.estado == MesaEstado.ocupada && mesa.personas != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
                        Text('${mesa.personas}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                if (listos > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Tooltip(
                      message: tr('{n} pedido(s) listo(s) para llevar a la mesa', {'n': listos}),
                      child: Icon(Icons.room_service_outlined, size: 18, color: semantic.success),
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

AppStatusTone _tonoPedido(String estado) {
  switch (estado) {
    case PedidoEstado.entregado:
      return AppStatusTone.success;
    case PedidoEstado.cancelado:
      return AppStatusTone.danger;
    case PedidoEstado.enPreparacion:
    case PedidoEstado.listo:
      return AppStatusTone.warning;
    default:
      return AppStatusTone.neutral;
  }
}

/// Cuenta abierta de una mesa: los pedidos que el Cajero registró para
/// ella, el total a cobrar y los botones para agregar un pedido o cobrar y
/// liberar la mesa.
class _CuentaMesaSheet extends StatelessWidget {
  final MesaModel mesa;
  final String idSucursal;
  final VoidCallback onTomarPedido;

  const _CuentaMesaSheet({required this.mesa, required this.idSucursal, required this.onTomarPedido});

  Future<void> _cerrarMesa(BuildContext context, List<PedidoModel> pedidos, double total) async {
    // HU-46: no se cobra sin caja abierta (y que no esté ya en cierre).
    final cajero = SesionActual.instancia.actual;
    final caja = cajero == null ? null : await CajaService.instancia.cajaAbiertaActual(cajero.idUsuario);
    if (!context.mounted) return;
    if (cajero == null || caja == null || caja.contada) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(caja == null ? tr('Primero abre tu caja') : tr('Tu caja está en cierre')),
          content: Text(
            caja == null
                ? tr('Para cobrar una mesa necesitas una caja abierta. Ábrela desde Caja.')
                : tr('Ya contaste el efectivo de tu caja, así que no se pueden registrar más cobros. Ciérrala desde Caja.'),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Entendido'))),
          ],
        ),
      );
      return;
    }

    final sinEntregar =
        pedidos.where((p) => p.estado != PedidoEstado.entregado && p.estado != PedidoEstado.cancelado).length;
    var metodo = MetodoPago.efectivo;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(tr('Cobrar mesa {numero}', {'numero': mesa.numero})),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Total a cobrar: {monto}', {'monto': dinero(total)}),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (sinEntregar > 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    tr('Atención: {n} pedido(s) todavía no se entregaron.', {'n': sinEntregar}),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(tr('Forma de pago')),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs + 2,
                runSpacing: AppSpacing.xs + 2,
                children: [
                  for (final m in MetodoPago.todos)
                    Pildora(
                      etiqueta: tr(m),
                      seleccionada: m == metodo,
                      onTap: () => setLocal(() => metodo = m),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('Cancelar'))),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(tr('Cobrar y liberar'))),
          ],
        ),
      ),
    );
    if (confirmar != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await CajaService.instancia.cobrarMesa(
        caja: caja,
        mesa: mesa,
        metodoPago: metodo,
        idUsuario: cajero.idUsuario,
      );
      await MesaService.instancia.liberarMesa(idSucursal, mesa.id);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(tr('Mesa {numero} cobrada y liberada.', {'numero': mesa.numero}))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idNegocio = SesionActual.instancia.idNegocio;
    final altoMaximo = MediaQuery.sizeOf(context).height * 0.4;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: idNegocio == null
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(tr('No se pudo identificar tu negocio.')),
              )
            : StreamBuilder<List<PedidoModel>>(
                stream: PedidoService.instancia.streamCuentaMesa(idNegocio, mesa.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final pedidos = snapshot.data!;
                  final total = totalCuentaMesa(pedidos);
                  final desde = pedidos.isEmpty ? null : pedidos.first.fechaCreacion;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('Mesa {numero}', {'numero': mesa.numero}),
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          AppStatusBadge(
                            label: tr('Ocupada'),
                            tone: AppStatusTone.warning,
                          ),
                        ],
                      ),
                      Text(
                        [
                          if (mesa.personas != null) tr('{n} personas', {'n': mesa.personas}),
                          if (desde != null) tr('ocupada desde {hora}', {'hora': formatoHora(desde)}),
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (pedidos.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          child: Text(tr('Todavía no hay pedidos en esta mesa.')),
                        )
                      else
                        ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: altoMaximo),
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              for (final p in pedidos)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    tr('Pedido {numero}', {'numero': numeroPedido(p)}),
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  subtitle: Align(
                                    alignment: Alignment.centerLeft,
                                    child: AppStatusBadge(label: p.estado, tone: _tonoPedido(p.estado)),
                                  ),
                                  trailing: Text(
                                    dinero(p.total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      decoration:
                                          p.estado == PedidoEstado.cancelado ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(tr('Total'), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text(
                            dinero(total),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                onTomarPedido();
                              },
                              icon: const Icon(Icons.add),
                              label: Text(tr('Agregar pedido')),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 3,
                            child: FilledButton.icon(
                              onPressed: () => _cerrarMesa(context, pedidos, total),
                              icon: const Icon(Icons.payments_outlined),
                              label: Text(tr('Cobrar y cerrar')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
