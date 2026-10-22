import 'package:flutter/material.dart';

import '../../models/sucursal_model.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_status_badge.dart';

class HorariosScreen extends StatefulWidget {
  final SucursalModel sucursal;
  const HorariosScreen({super.key, required this.sucursal});

  @override
  State<HorariosScreen> createState() => _HorariosScreenState();
}

class _HorariosScreenState extends State<HorariosScreen> {
  late Map<String, HorarioDia> _horarios;
  bool _guardando = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final horarios = await SucursalService.instancia.obtenerHorarios(widget.sucursal.id);
    _horarios = {...SucursalModel.horariosPorDefecto(), ...widget.sucursal.horarios, ...horarios};
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _elegirHora(String dia, {required bool apertura}) async {
    final actual = _horarios[dia]!;
    final partes = (apertura ? actual.apertura : actual.cierre).split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(partes.first) ?? 8,
        minute: int.tryParse(partes.last) ?? 0,
      ),
    );
    if (time == null) return;
    final value = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    setState(() {
      _horarios[dia] = apertura
          ? HorarioDia(activo: actual.activo, apertura: value, cierre: actual.cierre)
          : HorarioDia(activo: actual.activo, apertura: actual.apertura, cierre: value);
    });
  }

  Future<void> _guardar() async {
    // Un día activo no puede abrir y cerrar a la misma hora.
    for (final dia in SucursalModel.dias) {
      final h = _horarios[dia];
      if (h != null && h.activo && h.apertura == h.cierre) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El ${dia[0].toUpperCase()}${dia.substring(1)} abre y cierra a la misma hora (${h.apertura}). '
              'Corrígelo o desactiva ese día.',
            ),
          ),
        );
        return;
      }
    }
    setState(() => _guardando = true);
    try {
      await SucursalService.instancia.guardarHorarios(widget.sucursal.id, _horarios);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Horarios guardados.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Horarios · ${widget.sucursal.nombre}')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: SucursalModel.dias.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final dia = SucursalModel.dias[i];
          final h = _horarios[dia]!;
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: CircleAvatar(
                      backgroundColor: h.activo
                          ? scheme.primary.withValues(alpha: 0.15)
                          : scheme.surfaceContainerHighest,
                      foregroundColor:
                          h.activo ? scheme.primary : scheme.onSurfaceVariant,
                      child: const Icon(Icons.calendar_today, size: 18),
                    ),
                    title: Text(dia[0].toUpperCase() + dia.substring(1)),
                    value: h.activo,
                    onChanged: (v) => setState(() {
                      _horarios[dia] = HorarioDia(
                        activo: v,
                        apertura: h.apertura,
                        cierre: h.cierre,
                      );
                    }),
                  ),
                  if (h.activo)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ChipHora(
                              icono: Icons.login,
                              etiqueta: 'Apertura',
                              hora: h.apertura,
                              onTap: () => _elegirHora(dia, apertura: true),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: _ChipHora(
                              icono: Icons.logout,
                              etiqueta: 'Cierre',
                              hora: h.cierre,
                              onTap: () => _elegirHora(dia, apertura: false),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        bottom: AppSpacing.sm,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppStatusBadge(
                          label: 'Cerrado',
                          tone: AppStatusTone.neutral,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar horarios'),
          ),
        ),
      ),
    );
  }
}

class _ChipHora extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String hora;
  final VoidCallback onTap;

  const _ChipHora({
    required this.icono,
    required this.etiqueta,
    required this.hora,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(icono, size: 18, color: scheme.primary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    etiqueta,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  Text(
                    hora,
                    style: Theme.of(context).textTheme.titleSmall,
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
