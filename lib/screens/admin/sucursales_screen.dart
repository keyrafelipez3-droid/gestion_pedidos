import 'package:flutter/material.dart';

import '../../models/sucursal_model.dart';
import '../../services/sucursal_service.dart';
import 'horarios_screen.dart';

class SucursalesScreen extends StatelessWidget {
  const SucursalesScreen({super.key});

  Future<void> _editar(BuildContext context, {SucursalModel? sucursal}) async {
    final nombre = TextEditingController(text: sucursal?.nombre ?? '');
    final direccion = TextEditingController(text: sucursal?.direccion ?? '');
    final telefono = TextEditingController(text: sucursal?.telefono ?? '');
    final key = GlobalKey<FormState>();
    var guardando = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(sucursal == null ? 'Nueva sucursal' : 'Editar sucursal'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: direccion,
                    decoration: const InputDecoration(
                      labelText: 'Dirección',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      setState(() => guardando = true);
                      final item = SucursalModel(
                        id: sucursal?.id ?? '',
                        nombre: nombre.text.trim(),
                        direccion: direccion.text.trim(),
                        telefono: telefono.text.trim(),
                        estado: sucursal?.estado ?? true,
                        horarios: sucursal?.horarios ?? SucursalModel.horariosPorDefecto(),
                      );
                      try {
                        await SucursalService.instancia.guardar(item);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext)
                              .showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (dialogContext.mounted) setState(() => guardando = false);
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    nombre.dispose();
    direccion.dispose();
    telefono.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sucursales · HU-08')),
      body: StreamBuilder<List<SucursalModel>>(
        stream: SucursalService.instancia.streamSucursales(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No hay sucursales. Crea la primera con +.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final s = items[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
                  title: Text(s.nombre),
                  subtitle: Text([s.direccion, s.telefono].where((e) => e.isNotEmpty).join(' · ')),
                  onTap: () => _editar(context, sucursal: s),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: 'Horarios',
                        icon: const Icon(Icons.schedule_outlined),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => HorariosScreen(sucursal: s)),
                        ),
                      ),
                      Switch(
                        value: s.estado,
                        onChanged: (v) => SucursalService.instancia.cambiarEstado(s.id, v),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva sucursal'),
      ),
    );
  }
}
