import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/pedido_models.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/comanda_cocina.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/alergias.dart';
import '../../widgets/aviso_pedidos_nuevos.dart';
import '../../widgets/texto_traducido.dart';

/// Pantalla de cocina para tablet o monitor (KDS): dos columnas, "Por
/// preparar" y "En preparación", con lo que lleva cada pedido, el tiempo
/// que lleva esperando (verde, amarillo, rojo) y botones grandes.
class CocinaTableroScreen extends StatefulWidget {
  const CocinaTableroScreen({super.key});

  @override
  State<CocinaTableroScreen> createState() => _CocinaTableroScreenState();
}

class _CocinaTableroScreenState extends State<CocinaTableroScreen> {
  late final String? _idNegocio = SesionActual.instancia.idNegocio;
  late final Stream<List<PedidoModel>>? _stream =
      _idNegocio == null ? null : PedidoService.instancia.streamPedidosCocina(_idNegocio);
  Timer? _reloj;

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
    final siguiente =
        p.estado == PedidoEstado.enPreparacion ? PedidoEstado.listo : PedidoEstado.enPreparacion;
    try {
      await PedidoService.instancia.cambiarEstado(
        idPedido: p.id,
        nuevoEstado: siguiente,
        idUsuarioQueCambio: SesionActual.instancia.actual?.idUsuario ?? '',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(textoError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    return Scaffold(
      appBar: AppBar(title: const Text('Tablero de cocina')),
      body: stream == null
          ? const Center(child: Text('No se pudo identificar tu negocio.'))
          : AvisoPedidosNuevos(
              idNegocio: _idNegocio!,
              child: StreamBuilder<List<PedidoModel>>(
                stream: stream,
                builder: (context, snap) {
                  if (snap.hasError) return Center(child: Text(textoError(snap.error!)));
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  DateTime hora(PedidoModel p) => p.programadoPara ?? p.fechaCreacion ?? DateTime.now();
                  final ahora = snap.data!.where((p) => !p.esParaMasTarde).toList()
                    ..sort((a, b) => hora(a).compareTo(hora(b)));
                  final masTarde = snap.data!.length - ahora.length;
                  final porPreparar = ahora.where((p) => p.estado == PedidoEstado.pendiente).toList();
                  final enPreparacion = ahora.where((p) => p.estado == PedidoEstado.enPreparacion).toList();
                  final scheme = Theme.of(context).colorScheme;
                  const amarillo = Color(0xFFF9A825);

                  Widget columna(String titulo, List<PedidoModel> lista, Color color) => _Columna(
                        titulo: titulo,
                        color: color,
                        pedidos: lista,
                        onAvanzar: _avanzar,
                      );

                  return Column(
                    children: [
                      if (masTarde > 0)
                        Material(
                          color: scheme.secondaryContainer,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.schedule, size: 18),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$masTarde programado(s) para más tarde (aparecen 45 min antes)',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, c) {
                            if (c.maxWidth >= 760) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(child: columna('Por preparar', porPreparar, scheme.primary)),
                                  const VerticalDivider(width: 1),
                                  Expanded(child: columna('En preparación', enPreparacion, amarillo)),
                                ],
                              );
                            }
                            return DefaultTabController(
                              length: 2,
                              child: Column(
                                children: [
                                  TabBar(tabs: [
                                    Tab(text: 'Por preparar (${porPreparar.length})'),
                                    Tab(text: 'En preparación (${enPreparacion.length})'),
                                  ]),
                                  Expanded(
                                    child: TabBarView(children: [
                                      columna('', porPreparar, scheme.primary),
                                      columna('', enPreparacion, amarillo),
                                    ]),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _Columna extends StatelessWidget {
  final String titulo;
  final Color color;
  final List<PedidoModel> pedidos;
  final Future<void> Function(PedidoModel) onAvanzar;

  const _Columna({
    required this.titulo,
    required this.color,
    required this.pedidos,
    required this.onAvanzar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titulo.isNotEmpty)
          Container(
            color: color.withValues(alpha: 0.15),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              '$titulo (${pedidos.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        Expanded(
          child: pedidos.isEmpty
              ? const Center(child: Text('Nada por aquí', style: TextStyle(fontSize: 18)))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: pedidos.length,
                  itemBuilder: (context, i) => _TarjetaComanda(
                    key: ValueKey(pedidos[i].id),
                    pedido: pedidos[i],
                    onAvanzar: () => onAvanzar(pedidos[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// "12 min", "3 h 05" o "2 d": el tiempo que lleva esperando un pedido.
String textoEspera(int minutos) {
  if (minutos < 60) return '$minutos min';
  if (minutos < 24 * 60) return '${minutos ~/ 60} h ${(minutos % 60).toString().padLeft(2, '0')}';
  return '${minutos ~/ (24 * 60)} d';
}

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

class _TarjetaComanda extends StatefulWidget {
  final PedidoModel pedido;
  final Future<void> Function() onAvanzar;
  const _TarjetaComanda({super.key, required this.pedido, required this.onAvanzar});

  @override
  State<_TarjetaComanda> createState() => _TarjetaComandaState();
}

class _TarjetaComandaState extends State<_TarjetaComanda> {
  late final Stream<List<DetallePedidoModel>> _detalle =
      PedidoService.instancia.streamDetalle(widget.pedido.id);
  bool _enviando = false;

  Future<void> _avanzar() async {
    setState(() => _enviando = true);
    await widget.onAvanzar();
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    final desde = p.programadoPara ?? p.fechaCreacion ?? DateTime.now();
    final minutos = DateTime.now().difference(desde).inMinutes.clamp(0, 999999);
    final enPreparacion = p.estado == PedidoEstado.enPreparacion;
    const blanco = TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: p.tieneAlergias ? const BorderSide(color: Color(0xFFB3261E), width: 3) : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: colorEspera(minutos),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text('#${p.id.substring(0, 6).toUpperCase()} · ${p.etiquetaModalidad}', style: blanco),
                ),
                const Icon(Icons.timer_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 4),
                Text(textoEspera(minutos), style: blanco),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.programadoPara != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('Para las ${formatoProgramado(p.programadoPara!)}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                if (p.tieneAlergias) ...[
                  BandaAlergias(alergias: p.alergias),
                  const SizedBox(height: AppSpacing.sm),
                ],
                StreamBuilder<List<DetallePedidoModel>>(
                  stream: _detalle,
                  builder: (context, s) {
                    if (!s.hasData) return const LinearProgressIndicator();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final i in s.data!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i.cantidad}×  ${i.nombreProducto}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                                if (i.variantes.isNotEmpty || i.complementos.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 28),
                                    child: Text(
                                      '+ ${[...i.variantes, ...i.complementos].map((o) => o.nombre).join(', ')}',
                                    ),
                                  ),
                                if (i.notas.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 28),
                                    child: Text('» ${notaCorta(i.notas, max: 160)}',
                                        style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
                if (p.notas.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  TextoTraducido(
                    texto: notaCorta(p.notas),
                    idiomaOrigen: p.idiomaCliente,
                    etiqueta: 'Nota',
                    destacado: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Imprimir comanda',
                      onPressed: () => imprimirComanda(context, p),
                      icon: const Icon(Icons.print_outlined),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: enPreparacion ? const Color(0xFF2E7D32) : null,
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        onPressed: _enviando ? null : _avanzar,
                        icon: Icon(enPreparacion ? Icons.check_circle_outline : Icons.local_fire_department),
                        label: Text(enPreparacion ? 'Listo' : 'Empezar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
