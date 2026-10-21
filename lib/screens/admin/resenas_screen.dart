import 'package:flutter/material.dart';

import '../../models/resena_model.dart';
import '../../services/admin_service.dart';
import '../../services/resena_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/estrellas.dart';
import '../cliente/resenas_negocio_screen.dart' show formatoFecha;

/// Moderación de reseñas del negocio: el Administrador ve todas, puede
/// ocultar las que sean ofensivas (no se borran, se pueden volver a mostrar)
/// y bloquear a la cuenta autora para que no pueda volver a pedir ni a
/// escribir reseñas en este negocio.
class ResenasScreen extends StatefulWidget {
  final bool incrustada;
  const ResenasScreen({super.key, this.incrustada = false});

  @override
  State<ResenasScreen> createState() => _ResenasScreenState();
}

class _ResenasScreenState extends State<ResenasScreen> {
  String _filtro = 'Todas';

  Future<String?> _pedirMotivo(String titulo, String ayuda) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          decoration: InputDecoration(labelText: 'Motivo', helperText: ayuda),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _ejecutar(Future<void> Function() accion, String exito) async {
    try {
      await accion();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo completar: $e')));
    }
  }

  Future<void> _ocultar(ResenaModel r, {required bool bloquear}) async {
    final idAdmin = SesionActual.instancia.actual?.idUsuario ?? '';
    final motivo = await _pedirMotivo(
      bloquear ? 'Ocultar reseña y bloquear cliente' : 'Ocultar reseña',
      bloquear
          ? 'El cliente no podrá volver a pedir ni opinar en este negocio (puedes desbloquearlo en Clientes).'
          : 'Queda oculta para los demás clientes; puedes volver a mostrarla.',
    );
    if (motivo == null) return;
    await _ejecutar(() async {
      await ResenaService.instancia.moderar(
        idNegocio: r.idNegocio,
        idResena: r.id,
        ocultar: true,
        motivo: motivo,
        idAdmin: idAdmin,
      );
      if (bloquear) {
        await AdminService.instancia.cambiarBloqueoCliente(
          idNegocio: r.idNegocio,
          idCliente: r.idCliente,
          bloqueado: true,
          motivo: motivo.isEmpty ? 'Reseña ofensiva' : motivo,
          idAdmin: idAdmin,
        );
      }
    }, bloquear ? 'Reseña oculta y cliente bloqueado.' : 'Reseña oculta.');
  }

  Future<void> _mostrar(ResenaModel r) => _ejecutar(
        () => ResenaService.instancia.moderar(
          idNegocio: r.idNegocio,
          idResena: r.id,
          ocultar: false,
          idAdmin: SesionActual.instancia.actual?.idUsuario ?? '',
        ),
        'La reseña vuelve a ser visible.',
      );

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Reseñas'),
      ),
      body: idNegocio == null
          ? const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Sin negocio asignado',
              message: 'Tu cuenta no está asignada a ningún negocio.',
            )
          : StreamBuilder<List<ResenaModel>>(
              stream: ResenaService.instancia.streamTodas(idNegocio),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('No se pudieron cargar las reseñas: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final todas = snapshot.data!;
                final lista = todas.where((r) {
                  if (_filtro == 'Visibles') return !r.oculta;
                  if (_filtro == 'Ocultas') return r.oculta;
                  return true;
                }).toList();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          for (final f in ['Todas', 'Visibles', 'Ocultas'])
                            ChoiceChip(
                              label: Text(f),
                              selected: _filtro == f,
                              onSelected: (_) => setState(() => _filtro = f),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: lista.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.star_outline_rounded,
                              title: 'No hay reseñas',
                              message: 'Las reseñas de tus clientes aparecerán acá.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                              itemCount: lista.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, i) => _TarjetaResena(
                                resena: lista[i],
                                onOcultar: () => _ocultar(lista[i], bloquear: false),
                                onOcultarYBloquear: () => _ocultar(lista[i], bloquear: true),
                                onMostrar: () => _mostrar(lista[i]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _TarjetaResena extends StatelessWidget {
  final ResenaModel resena;
  final VoidCallback onOcultar;
  final VoidCallback onOcultarYBloquear;
  final VoidCallback onMostrar;

  const _TarjetaResena({
    required this.resena,
    required this.onOcultar,
    required this.onOcultarYBloquear,
    required this.onMostrar,
  });

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(resena.nombreCliente,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (resena.fecha != null)
                  Text(formatoFecha(resena.fecha!), style: textos.bodySmall),
                const SizedBox(width: AppSpacing.sm),
                AppStatusBadge(
                  label: resena.oculta ? 'Oculta' : 'Visible',
                  tone: resena.oculta ? AppStatusTone.danger : AppStatusTone.success,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Estrellas(valor: resena.calificacion.toDouble()),
            if (resena.comentario.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(resena.comentario),
            ],
            if (resena.oculta && (resena.motivoModeracion ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Motivo: ${resena.motivoModeracion}', style: textos.bodySmall),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (resena.oculta)
                  OutlinedButton.icon(
                    onPressed: onMostrar,
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('Volver a mostrar'),
                  )
                else ...[
                  OutlinedButton.icon(
                    onPressed: onOcultar,
                    icon: const Icon(Icons.visibility_off_outlined),
                    label: const Text('Ocultar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOcultarYBloquear,
                    icon: const Icon(Icons.block),
                    label: const Text('Ocultar y bloquear cliente'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
