import 'package:flutter/material.dart';

import '../../models/actividad_model.dart';
import '../../models/sucursal_model.dart';
import '../../services/actividad_service.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../widgets/app_empty_state.dart';

/// Zonas de delivery de una sucursal, con su costo de envío, y la compra
/// mínima para pedir delivery. El cliente elige su zona al confirmar.
class ZonasDeliveryScreen extends StatefulWidget {
  final SucursalModel sucursal;
  const ZonasDeliveryScreen({super.key, required this.sucursal});

  @override
  State<ZonasDeliveryScreen> createState() => _ZonasDeliveryScreenState();
}

class _ZonasDeliveryScreenState extends State<ZonasDeliveryScreen> {
  late final Map<String, double> _zonas = {...widget.sucursal.zonasDelivery};
  late final _minimo = TextEditingController(
    text: widget.sucursal.pedidoMinimoDelivery > 0
        ? widget.sucursal.pedidoMinimoDelivery.toStringAsFixed(2)
        : '',
  );
  bool _guardando = false;

  @override
  void dispose() {
    _minimo.dispose();
    super.dispose();
  }

  Future<void> _editarZona([String? nombreActual]) async {
    final nombre = TextEditingController(text: nombreActual ?? '');
    final costo = TextEditingController(
      text: nombreActual == null ? '' : _zonas[nombreActual]!.toStringAsFixed(2),
    );
    final key = GlobalKey<FormState>();
    final resultado = await showDialog<MapEntry<String, double>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nombreActual == null ? 'Nueva zona' : 'Editar zona'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nombre,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la zona *',
                  helperText: 'Ej.: Centro, Zona Norte, Sacaba',
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Escribe el nombre';
                  if (t.contains('.')) return 'Sin puntos en el nombre';
                  if (t != nombreActual && _zonas.containsKey(t)) return 'Ya existe esa zona';
                  return null;
                },
              ),
              TextFormField(
                controller: costo,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Costo de envío (Bs) *', prefixText: 'Bs '),
                validator: (v) {
                  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                  if (n == null || n < 0 || n > 200) return 'Entre 0 y 200';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!key.currentState!.validate()) return;
              Navigator.pop(
                ctx,
                MapEntry(nombre.text.trim(), double.parse(costo.text.replaceAll(',', '.'))),
              );
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    nombre.dispose();
    costo.dispose();
    if (resultado == null) return;
    setState(() {
      if (nombreActual != null) _zonas.remove(nombreActual);
      _zonas[resultado.key] = double.parse(resultado.value.toStringAsFixed(2));
    });
  }

  Future<void> _guardar() async {
    final minimo = double.tryParse(_minimo.text.trim().replaceAll(',', '.')) ?? 0;
    if (minimo < 0) return;
    setState(() => _guardando = true);
    try {
      await SucursalService.instancia.guardarDelivery(widget.sucursal.id, _zonas, minimo);
      ActividadService.instancia.registrar(
        ActividadTipo.catalogo,
        'Cambió las zonas de delivery de ${widget.sucursal.nombre} (${_zonas.length} zonas)',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zonas de delivery guardadas.')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(textoError(e))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final zonas = _zonas.entries.toList()
      ..sort((a, b) => a.value != b.value ? a.value.compareTo(b.value) : a.key.compareTo(b.key));
    return Scaffold(
      appBar: AppBar(title: Text('Delivery · ${widget.sucursal.nombre}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editarZona(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Agregar zona'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
        children: [
          Text(
            'El cliente elige su zona al pedir delivery y se le suma el costo de envío. '
            'Si no agregas zonas, el delivery no cobra envío.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _minimo,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Pedido mínimo para delivery (Bs)',
              helperText: 'En productos. Vacío o 0 = sin mínimo.',
              prefixText: 'Bs ',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (zonas.isEmpty)
            const AppEmptyState(
              icon: Icons.map_outlined,
              title: 'Sin zonas',
              message: 'Agrega las zonas donde entregas y cuánto cuesta el envío a cada una.',
            )
          else
            for (final z in zonas)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(z.key),
                  subtitle: Text('Envío: Bs ${z.value.toStringAsFixed(2)}'),
                  onTap: () => _editarZona(z.key),
                  trailing: IconButton(
                    tooltip: 'Quitar zona',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _zonas.remove(z.key)),
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: const Icon(Icons.save_outlined),
            label: Text(_guardando ? 'Guardando…' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
