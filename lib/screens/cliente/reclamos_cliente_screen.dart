import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/reclamo_model.dart';
import '../../services/reclamo_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import 'resenas_negocio_screen.dart' show formatoFecha;

AppStatusTone tonoReclamo(String estado) {
  if (estado == ReclamoEstado.resuelto) return AppStatusTone.success;
  if (estado == ReclamoEstado.enRevision) return AppStatusTone.warning;
  return AppStatusTone.neutral;
}

/// Los reclamos que el cliente hizo en un negocio, con la respuesta del local.
class MisReclamosScreen extends StatelessWidget {
  final String idNegocio;
  final String nombreNegocio;
  const MisReclamosScreen({super.key, required this.idNegocio, required this.nombreNegocio});

  @override
  Widget build(BuildContext context) {
    final uid = SesionActual.instancia.actual?.idUsuario;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Mis reclamos'))),
      floatingActionButton: uid == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => NuevoReclamoScreen(idNegocio: idNegocio, nombreNegocio: nombreNegocio),
              )),
              icon: const Icon(Icons.add),
              label: Text(tr('Presentar un reclamo')),
            ),
      body: uid == null
          ? AppEmptyState(
              icon: Icons.lock_outline,
              title: tr('Inicia sesión para presentar un reclamo.'),
            )
          : StreamBuilder<List<ReclamoModel>>(
              stream: ReclamoService.instancia.streamMios(idNegocio, uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text(tr('No se pudieron cargar tus reclamos.')));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final lista = snapshot.data!;
                if (lista.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.support_agent_outlined,
                    title: tr('No tienes reclamos'),
                    message: tr('Si algo salió mal con tu pedido, cuéntaselo a {restaurante}.',
                        {'restaurante': nombreNegocio}),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final r = lista[i];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(tr(ReclamoMotivo.etiqueta(r.motivo)),
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                    ),
                                    AppStatusBadge(
                                      label: tr(ReclamoEstado.etiqueta(r.estado)),
                                      tone: tonoReclamo(r.estado),
                                    ),
                                  ],
                                ),
                                if (r.fecha != null)
                                  Text(formatoFecha(r.fecha!), style: textos.bodySmall),
                                if (r.idPedido.isNotEmpty)
                                  Text(tr('Pedido #{id}', {'id': r.idPedido.length > 6 ? r.idPedido.substring(0, 6) : r.idPedido}),
                                      style: textos.bodySmall),
                                const SizedBox(height: AppSpacing.xs),
                                Text(r.descripcion),
                                if (r.respuesta.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Text(tr('Respuesta del negocio'),
                                      style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                                  Text(r.respuesta),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Formulario para presentar un reclamo, suelto o de un pedido.
class NuevoReclamoScreen extends StatefulWidget {
  final String idNegocio;
  final String nombreNegocio;
  final String idPedido;
  const NuevoReclamoScreen({
    super.key,
    required this.idNegocio,
    this.nombreNegocio = '',
    this.idPedido = '',
  });

  @override
  State<NuevoReclamoScreen> createState() => _NuevoReclamoScreenState();
}

class _NuevoReclamoScreenState extends State<NuevoReclamoScreen> {
  final _descripcionCtrl = TextEditingController();
  String? _motivo;
  bool _enviando = false;

  @override
  void dispose() {
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    // El flag va antes de cualquier await para que dos toques seguidos no
    // manden el reclamo dos veces.
    if (_enviando) return;
    if (_motivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Elige un motivo.'))));
      return;
    }
    setState(() => _enviando = true);
    try {
      await ReclamoService.instancia.crear(
        idNegocio: widget.idNegocio,
        idPedido: widget.idPedido,
        motivo: _motivo!,
        descripcion: _descripcionCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Reclamo enviado. El negocio te responderá en "Mis reclamos".')),
      ));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Presentar un reclamo'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (widget.nombreNegocio.isNotEmpty)
                  Text(widget.nombreNegocio, style: textos.titleLarge),
                if (widget.idPedido.isNotEmpty)
                  Text(tr('Pedido #{id}', {'id': widget.idPedido.length > 6 ? widget.idPedido.substring(0, 6) : widget.idPedido}),
                      style: textos.bodyMedium),
                const SizedBox(height: AppSpacing.lg),
                Text(tr('¿Qué pasó?'), style: textos.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final m in ReclamoMotivo.todos)
                      ChoiceChip(
                        label: Text(tr(ReclamoMotivo.etiqueta(m))),
                        selected: _motivo == m,
                        onSelected: _enviando ? null : (_) => setState(() => _motivo = m),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: _descripcionCtrl,
                  enabled: !_enviando,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    labelText: tr('Cuéntanos qué pasó'),
                    helperText: tr('Mínimo 10 letras. El negocio verá tu nombre corto y tu mensaje.'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _enviando ? null : _enviar,
                  icon: _enviando
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined),
                  label: Text(tr('Enviar reclamo')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
