import 'package:flutter/material.dart';

import '../../models/mesa_model.dart';
import '../../services/mesa_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';

/// HU-32: el Cajero gestiona las mesas de su sucursal — crearlas y
/// cambiar su estado (Libre/Ocupada/Reservada).
class CajeroMesasScreen extends StatelessWidget {
  const CajeroMesasScreen({super.key});

  AppStatusTone _tono(String estado) {
    switch (estado) {
      case MesaEstado.libre:
        return AppStatusTone.success;
      case MesaEstado.ocupada:
        return AppStatusTone.danger;
      case MesaEstado.reservada:
        return AppStatusTone.warning;
      default:
        return AppStatusTone.neutral;
    }
  }

  Future<void> _nuevaMesa(BuildContext context, String idSucursal) async {
    final numeroCtrl = TextEditingController();
    final capacidadCtrl = TextEditingController(text: '4');
    final crear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva mesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numeroCtrl,
              decoration: const InputDecoration(labelText: 'Número / nombre de la mesa'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: capacidadCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Capacidad (personas)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Crear')),
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

  @override
  Widget build(BuildContext context) {
    final idSucursal = SesionActual.instancia.idSucursal;
    return Scaffold(
      appBar: AppBar(title: const Text('Mesas')),
      floatingActionButton: idSucursal == null
          ? null
          : FloatingActionButton(
              onPressed: () => _nuevaMesa(context, idSucursal),
              child: const Icon(Icons.add),
            ),
      body: idSucursal == null
          ? const Center(child: Text('No tienes una sucursal asignada.'))
          : StreamBuilder<List<MesaModel>>(
              stream: MesaService.instancia.streamMesas(idSucursal),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final mesas = snapshot.data!;
                if (mesas.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.table_bar_outlined,
                    title: 'Todavía no hay mesas registradas',
                    actionLabel: 'Nueva mesa',
                    onAction: () => _nuevaMesa(context, idSucursal),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppSpacing.sm,
                    crossAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: mesas.length,
                  itemBuilder: (context, i) {
                    final mesa = mesas[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mesa ${mesa.numero}',
                                style: Theme.of(context).textTheme.titleMedium),
                            Text('${mesa.capacidad} personas'),
                            const Spacer(),
                            AppStatusBadge(label: mesa.estado, tone: _tono(mesa.estado)),
                            const SizedBox(height: AppSpacing.xs),
                            DropdownButton<String>(
                              isDense: true,
                              isExpanded: true,
                              value: mesa.estado,
                              items: MesaEstado.todos
                                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (nuevo) {
                                if (nuevo == null) return;
                                MesaService.instancia.cambiarEstado(idSucursal, mesa.id, nuevo);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
