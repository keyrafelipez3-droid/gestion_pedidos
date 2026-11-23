import 'package:flutter/material.dart';

import '../../models/reclamo_model.dart';
import '../../services/reclamo_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../cliente/reclamos_cliente_screen.dart' show tonoReclamo;
import '../cliente/resenas_negocio_screen.dart' show formatoFecha;

/// Libro de reclamos del negocio: el Administrador los revisa y responde.
/// Los reclamos no se borran.
class ReclamosScreen extends StatefulWidget {
  final bool incrustada;
  const ReclamosScreen({super.key, this.incrustada = false});

  @override
  State<ReclamosScreen> createState() => _ReclamosScreenState();
}

class _ReclamosScreenState extends State<ReclamosScreen> {
  String _filtro = 'Pendientes';
  final Set<String> _ocupados = {};

  Future<void> _ejecutar(String id, Future<void> Function() accion, String exito) async {
    if (_ocupados.contains(id)) return;
    setState(() => _ocupados.add(id));
    try {
      await accion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo completar: ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _ocupados.remove(id));
    }
  }

  Future<void> _responder(ReclamoModel r) async {
    final ctrl = TextEditingController(text: r.respuesta);
    final texto = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        // Con el teclado abierto el contenido se desplaza en vez de
        // encimarse con los botones.
        scrollable: true,
        title: const Text('Responder reclamo'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 1000,
          decoration: const InputDecoration(
            labelText: 'Respuesta para el cliente',
            helperText: 'El cliente la verá en "Mis reclamos". El reclamo queda resuelto.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Responder'),
          ),
        ],
      ),
    );
    if (texto == null) return;
    await _ejecutar(
      r.id,
      () => ReclamoService.instancia.responder(
        idNegocio: r.idNegocio,
        idReclamo: r.id,
        respuesta: texto,
        idAdmin: SesionActual.instancia.actual?.idUsuario ?? '',
      ),
      'Reclamo respondido.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Reclamos'),
      ),
      body: idNegocio == null
          ? const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Sin negocio asignado',
              message: 'Tu cuenta no está asignada a ningún negocio.',
            )
          : StreamBuilder<List<ReclamoModel>>(
              stream: ReclamoService.instancia.streamTodos(idNegocio),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('No se pudieron cargar los reclamos: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final todos = snapshot.data!;
                final pendientes = todos.where((r) => !r.resuelto).length;
                final lista = todos.where((r) {
                  if (_filtro == 'Pendientes') return !r.resuelto;
                  if (_filtro == 'Resueltos') return r.resuelto;
                  return true;
                }).toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (final f in ['Pendientes', 'Resueltos', 'Todos'])
                            ChoiceChip(
                              label: Text(f == 'Pendientes' ? 'Pendientes ($pendientes)' : f),
                              selected: _filtro == f,
                              onSelected: (_) => setState(() => _filtro = f),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: lista.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.support_agent_outlined,
                              title: 'No hay reclamos',
                              message: 'Los reclamos de tus clientes aparecerán acá.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                              itemCount: lista.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) {
                                final r = lista[i];
                                final ocupado = _ocupados.contains(r.id);
                                return _TarjetaReclamo(
                                  reclamo: r,
                                  ocupado: ocupado,
                                  onRevisar: () => _ejecutar(
                                    r.id,
                                    () => ReclamoService.instancia.ponerEnRevision(r.idNegocio, r.id),
                                    'Reclamo en revisión.',
                                  ),
                                  onResponder: () => _responder(r),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _TarjetaReclamo extends StatelessWidget {
  final ReclamoModel reclamo;
  final bool ocupado;
  final VoidCallback onRevisar;
  final VoidCallback onResponder;

  const _TarjetaReclamo({
    required this.reclamo,
    required this.ocupado,
    required this.onRevisar,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final r = reclamo;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(ReclamoMotivo.etiqueta(r.motivo),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (r.fecha != null) Text(formatoFecha(r.fecha!), style: textos.bodySmall),
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge(label: ReclamoEstado.etiqueta(r.estado), tone: tonoReclamo(r.estado)),
              ],
            ),
            Text(
              [
                r.nombreCliente.isEmpty ? 'Cuenta eliminada' : r.nombreCliente,
                if (r.idPedido.isNotEmpty)
                  'Pedido #${r.idPedido.length > 6 ? r.idPedido.substring(0, 6) : r.idPedido}',
              ].join(' · '),
              style: textos.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(r.descripcion),
            if (r.respuesta.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Respuesta: ${r.respuesta}', style: textos.bodySmall),
            ],
            if (!r.resuelto) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  if (r.estado == ReclamoEstado.abierto)
                    OutlinedButton.icon(
                      onPressed: ocupado ? null : onRevisar,
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Marcar en revisión'),
                    ),
                  FilledButton.icon(
                    onPressed: ocupado ? null : onResponder,
                    icon: const Icon(Icons.reply_outlined),
                    label: const Text('Responder'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
