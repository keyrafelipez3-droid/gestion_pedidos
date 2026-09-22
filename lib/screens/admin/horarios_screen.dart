import 'package:flutter/material.dart';

import '../../models/sucursal_model.dart';
import '../../services/sucursal_service.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text('Horarios · ${widget.sucursal.nombre}')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: SucursalModel.dias.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final dia = SucursalModel.dias[i];
          final h = _horarios[dia]!;
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  SwitchListTile(
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
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            leading: const Icon(Icons.login),
                            title: const Text('Apertura'),
                            subtitle: Text(h.apertura),
                            onTap: () => _elegirHora(dia, apertura: true),
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            leading: const Icon(Icons.logout),
                            title: const Text('Cierre'),
                            subtitle: Text(h.cierre),
                            onTap: () => _elegirHora(dia, apertura: false),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
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
