import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/pedido_models.dart';
import '../../models/sucursal_model.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/sucursal_service.dart';
import '../../theme/brand_style.dart';
import '../../theme/design_tokens.dart';
import '../../utils/comanda_cocina.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/app_iconos_pedido.dart';
import '../../widgets/aviso_pedidos_nuevos.dart';
import '../../widgets/panel_personal.dart';
import '../../widgets/tarjeta_pedido_personal.dart';
import '../../widgets/texto_traducido.dart';
import '../cliente/pedido_detalle_screen.dart';

/// "12 min", "3 h 05" o "2 d": el tiempo que lleva esperando un pedido.
String textoEspera(int minutos) => duracionCorta(minutos);

/// Recorta una nota muy larga para que no tape el tablero.
String notaCorta(String nota, {int max = 280}) =>
    nota.length <= max ? nota : '${nota.substring(0, max).trimRight()}… (nota recortada)';

/// Color según los minutos de espera: verde (menos de 10), amarillo
/// (menos de 20) y rojo (20 o más).
Color colorEspera(int minutos) {
  if (minutos < 10) return const Color(0xFF2E7D32);
  if (minutos < 20) return const Color(0xFFF9A825);
  return const Color(0xFFC62828);
}

/// Qué parte del tablero se ve en el celular.
enum VistaCocina { porPreparar, preparando, masTarde }

/// Pantalla de cocina (KDS) para tablet, monitor o celular: comandas con
/// lo que lleva cada pedido, una barra que se llena según el tiempo de
/// espera, casillas para ir marcando cada plato y un solo botón grande
/// (Empezar / Marcar listo). Arriba, el resumen y el botón para pausar
/// los pedidos nuevos si la cocina se llenó.
class CocinaTableroScreen extends StatefulWidget {
  const CocinaTableroScreen({super.key});

  @override
  State<CocinaTableroScreen> createState() => _CocinaTableroScreenState();
}

class _CocinaTableroScreenState extends State<CocinaTableroScreen> {
  late final String? _idNegocio = SesionActual.instancia.idNegocio;
  late final String? _idSucursal = SesionActual.instancia.idSucursal;
  late final Stream<List<PedidoModel>>? _stream =
      _idNegocio == null ? null : PedidoService.instancia.streamPedidosCocina(_idNegocio);
  late final Stream<SucursalModel?>? _sucursal =
      _idSucursal == null ? null : SucursalService.instancia.streamSucursal(_idSucursal);
  VistaCocina _vista = VistaCocina.porPreparar;
  Timer? _reloj;

  /// Platos ya marcados en cada comanda (id del pedido → ids del detalle).
  /// Solo en este dispositivo: es una ayuda para la cocina.
  final Map<String, Set<String>> _marcados = {};

  @override
  void initState() {
    super.initState();
    // Actualiza los minutos de espera de cada pedido.
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _avanzar(PedidoModel p) async {
    final siguiente = p.estado == PedidoEstado.enPreparacion ? PedidoEstado.listo : PedidoEstado.enPreparacion;
    try {
      await PedidoService.instancia.cambiarEstado(
        idPedido: p.id,
        nuevoEstado: siguiente,
        idUsuarioQueCambio: SesionActual.instancia.actual?.idUsuario ?? '',
      );
      if (siguiente == PedidoEstado.listo) _marcados.remove(p.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(textoError(e))));
    }
  }

  Future<void> _cambiarPausa(SucursalModel s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (s.pedidosPausados) {
      try {
        await SucursalService.instancia.pausarPedidos(s.id, pausar: false);
        messenger.showSnackBar(SnackBar(content: Text(tr('Se reanudaron los pedidos nuevos.'))));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
      }
      return;
    }
    final motivo = await showDialog<String>(context: context, builder: (_) => const _DialogoPausa());
    if (motivo == null) return;
    try {
      await SucursalService.instancia.pausarPedidos(s.id, pausar: true, motivo: motivo);
      messenger.showSnackBar(SnackBar(content: Text(tr('Pedidos nuevos pausados. Los clientes verán el aviso.'))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    final idNegocio = _idNegocio;
    final sucursal = _sucursal;
    return StreamBuilder<SucursalModel?>(
      stream: sucursal,
      builder: (context, sSucursal) {
        final s = sSucursal.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(tr('Cocina')),
            actions: [
              if (s != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: s.pedidosPausados
                      ? FilledButton.icon(
                          onPressed: () => _cambiarPausa(s),
                          icon: const Icon(Icons.play_arrow),
                          label: Text(tr('Reanudar pedidos')),
                        )
                      : OutlinedButton.icon(
                          onPressed: () => _cambiarPausa(s),
                          icon: const Icon(Icons.pause),
                          label: Text(tr('Pausar pedidos nuevos')),
                        ),
                ),
            ],
          ),
          body: stream == null || idNegocio == null
              ? Center(child: Text(tr('No se pudo identificar tu negocio.')))
              : AvisoPedidosNuevos(
                  idNegocio: idNegocio,
                  child: StreamBuilder<List<PedidoModel>>(
                    stream: stream,
                    builder: (context, snap) {
                      if (snap.hasError) return Center(child: Text(textoError(snap.error!)));
                      if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                      return _tablero(context, snap.data!, s);
                    },
                  ),
                ),
        );
      },
    );
  }

  List<Widget> _contenidoVista(
    List<PedidoModel> lista,
    Widget Function(List<PedidoModel>, String) grilla,
    ColorScheme scheme,
  ) {
    if (_vista != VistaCocina.masTarde) {
      return [
        grilla(lista, _vista == VistaCocina.porPreparar ? tr('No hay pedidos nuevos.') : tr('Nada en preparación.')),
      ];
    }
    if (lista.isEmpty) {
      return [Text(tr('No hay pedidos programados.'), style: TextStyle(color: scheme.onSurfaceVariant))];
    }
    return [for (final p in lista) _FilaProgramado(pedido: p)];
  }

  Widget _tablero(BuildContext context, List<PedidoModel> pedidos, SucursalModel? sucursal) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    DateTime hora(PedidoModel p) => p.programadoPara ?? p.fechaCreacion ?? DateTime.now();
    final ahora = pedidos.where((p) => !p.esParaMasTarde).toList()..sort((a, b) => hora(a).compareTo(hora(b)));
    final masTarde = pedidos.where((p) => p.esParaMasTarde).toList()..sort((a, b) => hora(a).compareTo(hora(b)));
    final porPreparar = ahora.where((p) => p.estado == PedidoEstado.pendiente).toList();
    final preparando = ahora.where((p) => p.estado == PedidoEstado.enPreparacion).toList();
    final atrasados = ahora.where((p) => pedidoAtrasado(p)).length;

    final resumen = ResumenTurno(datos: [
      DatoTurno('${porPreparar.length}', tr('por preparar'), icono: Icons.receipt_long_outlined),
      DatoTurno('${preparando.length}', tr('preparando'), icono: Icons.local_fire_department_outlined,
          color: semantic.warning),
      DatoTurno('$atrasados', tr('atrasados'), icono: Icons.alarm, color: atrasados > 0 ? scheme.error : semantic.success),
      DatoTurno('${masTarde.length}', tr('programados para más tarde'), icono: Icons.schedule),
    ]);

    final avisoPausa = sucursal != null && sucursal.pedidosPausados
        ? Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
            padding: const EdgeInsets.all(AppSpacing.sm + 4),
            decoration: BoxDecoration(
              color: semantic.warning.withValues(alpha: 0.16),
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: semantic.warning.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.pause_circle_outline, color: semantic.warning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    sucursal.motivoPausa.trim().isEmpty
                        ? tr('Los pedidos nuevos están pausados.')
                        : tr('Los pedidos nuevos están pausados: {motivo}', {'motivo': sucursal.motivoPausa.trim()}),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        : null;

    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth;
        final ancha = ancho >= 760;
        final columnas = (ancho / 340).floor() < 1 ? 1 : (ancho / 340).floor();
        const gap = AppSpacing.sm + 4;
        final anchoComanda = (ancho - AppSpacing.md * 2 - gap * (columnas - 1)) / columnas;

        Widget comanda(PedidoModel p) => _Comanda(
              key: ValueKey(p.id),
              pedido: p,
              marcados: _marcados.putIfAbsent(p.id, () => <String>{}),
              onMarcar: (idDetalle) => setState(() {
                final set = _marcados.putIfAbsent(p.id, () => <String>{});
                if (!set.remove(idDetalle)) set.add(idDetalle);
              }),
              onAvanzar: () => _avanzar(p),
            );

        Widget grilla(List<PedidoModel> lista, String vacio) => lista.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(vacio, style: TextStyle(color: scheme.onSurfaceVariant)),
              )
            : Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final p in lista) SizedBox(width: columnas == 1 ? double.infinity : anchoComanda, child: comanda(p)),
                ],
              );

        final secciones = <Widget>[];
        if (ancha) {
          secciones.addAll([
            TituloColumna(tr('Por preparar'), contador: porPreparar.length, color: scheme.primary),
            grilla(porPreparar, tr('No hay pedidos nuevos.')),
            const SizedBox(height: AppSpacing.lg),
            TituloColumna(tr('Preparando'), contador: preparando.length, color: semantic.warning),
            grilla(preparando, tr('Nada en preparación.')),
            if (masTarde.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              TituloColumna(tr('Programados para más tarde'), contador: masTarde.length, color: semantic.info),
              Text(
                tr('Aparecen en "Por preparar" 45 minutos antes de su hora.'),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final p in masTarde) _FilaProgramado(pedido: p),
            ],
          ]);
        } else {
          final lista = switch (_vista) {
            VistaCocina.porPreparar => porPreparar,
            VistaCocina.preparando => preparando,
            VistaCocina.masTarde => masTarde,
          };
          secciones.addAll([
            PildorasFiltro<VistaCocina>(
              seleccion: _vista,
              onChanged: (v) => setState(() => _vista = v),
              opciones: [
                OpcionPildora(VistaCocina.porPreparar, tr('Por preparar'), contador: porPreparar.length),
                OpcionPildora(VistaCocina.preparando, tr('Preparando'), contador: preparando.length),
                OpcionPildora(VistaCocina.masTarde, tr('Más tarde'), contador: masTarde.length),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            ..._contenidoVista(lista, grilla, scheme),
          ]);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          children: [
            if (avisoPausa != null) avisoPausa,
            resumen,
            const SizedBox(height: AppSpacing.md),
            ...secciones,
          ],
        );
      },
    );
  }
}

/// Una comanda: barra de tiempo, número, modalidad, alergias, platos con
/// casilla, nota del cliente y el botón para avanzar.
class _Comanda extends StatefulWidget {
  final PedidoModel pedido;
  final Set<String> marcados;
  final ValueChanged<String> onMarcar;
  final Future<void> Function() onAvanzar;

  const _Comanda({
    super.key,
    required this.pedido,
    required this.marcados,
    required this.onMarcar,
    required this.onAvanzar,
  });

  @override
  State<_Comanda> createState() => _ComandaState();
}

class _ComandaState extends State<_Comanda> {
  late final Stream<List<DetallePedidoModel>> _detalle = PedidoService.instancia.streamDetalle(widget.pedido.id);
  bool _enviando = false;

  Future<void> _avanzar() async {
    setState(() => _enviando = true);
    await widget.onAvanzar();
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final brand = context.brand;
    final minutos = minutosTranscurridos(p.programadoPara ?? p.fechaCreacion);
    final colorTiempo = minutos < 10
        ? semantic.success
        : minutos < minutosAtraso
            ? semantic.warning
            : scheme.error;
    final enPreparacion = p.estado == PedidoEstado.enPreparacion;

    return Container(
      decoration: brand.decoracionTarjeta(scheme),
      child: ClipRRect(
        borderRadius: brand.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Se llena a medida que se acerca a los 20 minutos.
            LinearProgressIndicator(
              value: (minutos / minutosAtraso).clamp(0.05, 1.0).toDouble(),
              minHeight: 5,
              color: colorTiempo,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm + 4, AppSpacing.md, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            numeroPedido(p),
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        EtiquetaPanel(
                          p.programadoPara != null && minutos == 0
                              ? formatoHora(p.programadoPara!)
                              : duracionCorta(minutos),
                          icono: Icons.schedule,
                          color: colorTiempo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    DatoConIcono(
                      iconoModalidad(p.modalidad),
                      [
                        p.etiquetaModalidad,
                        if (p.programadoPara != null)
                          tr('para las {hora}', {'hora': formatoHora(p.programadoPara!)}),
                      ].join(' · '),
                    ),
                  ],
                ),
              ),
            ),
            if (p.tieneAlergias)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.16),
                  borderRadius: AppRadius.smAll,
                  border: Border.all(color: scheme.error.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${tr('ALERGIA')}: ${textoAlergias(p).toUpperCase()}',
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            StreamBuilder<List<DetallePedidoModel>>(
              stream: _detalle,
              builder: (context, s) {
                if (!s.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: LinearProgressIndicator(),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final i in s.data!) _PlatoComanda(
                      detalle: i,
                      hecho: widget.marcados.contains(i.id),
                      onTap: () => widget.onMarcar(i.id),
                    ),
                  ],
                );
              },
            ),
            if (p.notas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: TextoTraducido(
                  texto: notaCorta(p.notas),
                  idiomaOrigen: p.idiomaCliente,
                  etiqueta: tr('Nota'),
                  destacado: true,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
              child: Row(
                children: [
                  IconButton.outlined(
                    tooltip: tr('Imprimir comanda'),
                    onPressed: () => imprimirComanda(context, p),
                    icon: const Icon(Icons.print_outlined),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: enPreparacion ? semantic.success : null,
                        foregroundColor: enPreparacion ? semantic.onSuccess : null,
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      onPressed: _enviando ? null : _avanzar,
                      icon: Icon(enPreparacion ? Icons.check_circle_outline : Icons.local_fire_department_outlined),
                      label: Text(enPreparacion ? tr('Marcar listo') : tr('Empezar')),
                    ),
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

/// Un plato de la comanda, con su casilla para marcarlo cuando está hecho.
class _PlatoComanda extends StatelessWidget {
  final DetallePedidoModel detalle;
  final bool hecho;
  final VoidCallback onTap;

  const _PlatoComanda({required this.detalle, required this.hecho, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final extras = [...detalle.variantes, ...detalle.complementos].map((o) => o.nombre).join(', ');
    final apagado = scheme.onSurfaceVariant.withValues(alpha: 0.7);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 4, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: hecho,
              onChanged: (_) => onTap(),
              visualDensity: VisualDensity.compact,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: 34,
                child: Text(
                  '${detalle.cantidad}×',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: hecho ? apagado : scheme.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detalle.nombreProducto,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: hecho ? apagado : null,
                        decoration: hecho ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if (extras.isNotEmpty)
                      Text('+ $extras', style: TextStyle(color: hecho ? apagado : scheme.onSurfaceVariant)),
                    if (detalle.notas.isNotEmpty)
                      Text(
                        '» ${notaCorta(detalle.notas, max: 160)}',
                        style: TextStyle(fontWeight: FontWeight.w700, color: hecho ? apagado : null),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un pedido programado para más tarde (todavía no se prepara).
class _FilaProgramado extends StatelessWidget {
  final PedidoModel pedido;

  const _FilaProgramado({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final p = pedido;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TarjetaPanel(
        franja: p.tieneAlergias ? Theme.of(context).colorScheme.error : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true)),
        ),
        child: Row(
          children: [
            Icon(iconoModalidad(p.modalidad)),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Text(
                '${numeroPedido(p)} · ${p.etiquetaModalidad}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (p.programadoPara != null)
              EtiquetaPanel(formatoProgramado(p.programadoPara!), icono: Icons.schedule),
          ],
        ),
      ),
    );
  }
}

/// Pide el motivo (opcional) para pausar los pedidos nuevos.
class _DialogoPausa extends StatefulWidget {
  const _DialogoPausa();

  @override
  State<_DialogoPausa> createState() => _DialogoPausaState();
}

class _DialogoPausaState extends State<_DialogoPausa> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rapidos = [tr('Cocina llena'), tr('Faltan insumos'), tr('Cerramos en unos minutos')];
    return AlertDialog(
      title: Text(tr('Pausar pedidos nuevos')),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Los clientes no podrán hacer pedidos nuevos en esta sucursal hasta que los reanudes. '
                'Los pedidos que ya llegaron siguen normal.')),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs + 2,
              runSpacing: AppSpacing.xs + 2,
              children: [
                for (final r in rapidos)
                  Pildora(
                    etiqueta: r,
                    seleccionada: _motivo.text == r,
                    onTap: () => setState(() => _motivo.text = r),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _motivo,
              maxLength: 120,
              decoration: InputDecoration(labelText: tr('Motivo que verán los clientes (opcional)')),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Cancelar'))),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_motivo.text.trim()),
          icon: const Icon(Icons.pause),
          label: Text(tr('Pausar')),
        ),
      ],
    );
  }
}
