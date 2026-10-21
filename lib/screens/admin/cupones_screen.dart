import 'package:flutter/material.dart';

import '../../models/cupon_model.dart';
import '../../services/cupon_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';

/// Cupones de descuento del negocio: el Administrador crea códigos (por
/// porcentaje o monto fijo, con compra mínima y fecha de vencimiento) que
/// el cliente escribe al confirmar su pedido.
class CuponesScreen extends StatelessWidget {
  final bool incrustada;
  const CuponesScreen({super.key, this.incrustada = false});

  static String _fecha(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

  Future<void> _editar(BuildContext context, String idNegocio, {CuponModel? cupon}) async {
    final codigo = TextEditingController(text: cupon?.codigo ?? '');
    final valor = TextEditingController(text: cupon == null ? '' : cupon.valor.toString());
    final minimo = TextEditingController(text: cupon == null || cupon.minimo == 0 ? '' : cupon.minimo.toString());
    final descripcion = TextEditingController(text: cupon?.descripcion ?? '');
    var tipo = cupon?.tipo ?? CuponModel.porcentaje;
    DateTime? vence = cupon?.vence;
    final key = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(cupon == null ? 'Nuevo cupón' : 'Editar cupón ${cupon.codigo}'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: codigo,
                      enabled: cupon == null,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Código *',
                        hintText: 'Ej. CARO10',
                        helperText: 'Solo letras y números, sin espacios.',
                      ),
                      validator: (v) {
                        final c = CuponService.normalizar(v ?? '');
                        if (c.length < 3) return 'Mínimo 3 caracteres';
                        if (c.length > 20) return 'Máximo 20 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: CuponModel.porcentaje, label: Text('Porcentaje %'), icon: Icon(Icons.percent)),
                        ButtonSegment(value: CuponModel.monto, label: Text('Monto Bs'), icon: Icon(Icons.payments_outlined)),
                      ],
                      selected: {tipo},
                      onSelectionChanged: (s) => setState(() => tipo = s.first),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: valor,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: tipo == CuponModel.porcentaje ? 'Descuento (%) *' : 'Descuento (Bs) *',
                        suffixText: tipo == CuponModel.porcentaje ? '%' : null,
                        prefixText: tipo == CuponModel.monto ? 'Bs ' : null,
                      ),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (n == null || n <= 0) return 'Ingresa un valor mayor a 0';
                        if (tipo == CuponModel.porcentaje && n > 90) return 'Máximo 90 %';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: minimo,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Compra mínima (opcional)',
                        prefixText: 'Bs ',
                      ),
                      validator: (v) {
                        if ((v ?? '').trim().isEmpty) return null;
                        final n = double.tryParse(v!.replaceAll(',', '.'));
                        return n == null || n < 0 ? 'Monto no válido' : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: descripcion,
                      maxLength: 80,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        hintText: 'Ej. Promo de bienvenida',
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: Text(vence == null ? 'Sin fecha de vencimiento' : 'Vence el ${_fecha(vence!)}'),
                      trailing: Wrap(
                        children: [
                          if (vence != null)
                            IconButton(
                              tooltip: 'Quitar fecha',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => vence = null),
                            ),
                          IconButton(
                            tooltip: 'Elegir fecha',
                            icon: const Icon(Icons.edit_calendar_outlined),
                            onPressed: () async {
                              final hoy = DateTime.now();
                              final f = await showDatePicker(
                                context: ctx,
                                firstDate: hoy,
                                lastDate: hoy.add(const Duration(days: 365)),
                                initialDate: vence ?? hoy.add(const Duration(days: 30)),
                              );
                              // Vence al final de ese día.
                              if (f != null) setState(() => vence = DateTime(f.year, f.month, f.day, 23, 59, 59));
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!key.currentState!.validate()) return;
                final nuevo = CuponModel(
                  codigo: CuponService.normalizar(codigo.text),
                  tipo: tipo,
                  valor: double.parse(valor.text.replaceAll(',', '.')),
                  minimo: double.tryParse(minimo.text.replaceAll(',', '.')) ?? 0,
                  vence: vence,
                  activo: cupon?.activo ?? true,
                  descripcion: descripcion.text.trim(),
                );
                try {
                  await CuponService.instancia.guardar(idNegocio, nuevo);
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(textoError(e))));
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      codigo.dispose();
      valor.dispose();
      minimo.dispose();
      descripcion.dispose();
    });
  }

  Future<void> _eliminar(BuildContext context, String idNegocio, CuponModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar el cupón ${c.codigo}?'),
        content: const Text('Los clientes ya no podrán usarlo. Los pedidos que lo usaron no cambian.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok == true) await CuponService.instancia.eliminar(idNegocio, c.codigo);
  }

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Cupones de descuento'),
      ),
      floatingActionButton: idNegocio == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editar(context, idNegocio),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo cupón'),
            ),
      body: idNegocio == null
          ? const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Sin negocio asignado',
              message: 'Tu cuenta no está asignada a ningún negocio.',
            )
          : StreamBuilder<List<CuponModel>>(
              stream: CuponService.instancia.stream(idNegocio),
              builder: (context, s) {
                if (s.hasError) {
                  return const Center(child: Text('No se pudieron cargar los cupones.'));
                }
                if (!s.hasData) return const AppCargando();
                final cupones = s.data!;
                if (cupones.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.local_offer_outlined,
                    title: 'Todavía no tienes cupones',
                    message: 'Crea un código de descuento (ej. CARO10) y compártelo con tus clientes.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 96),
                  itemCount: cupones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final c = cupones[i];
                    final detalle = [
                      if (c.descripcion.isNotEmpty) c.descripcion,
                      if (c.minimo > 0) 'Compra mínima Bs ${c.minimo.toStringAsFixed(2)}',
                      c.vence == null ? 'Sin vencimiento' : 'Vence el ${_fecha(c.vence!)}',
                    ].join(' · ');
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(Icons.local_offer_outlined,
                              color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        title: Wrap(
                          spacing: AppSpacing.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SelectableText(c.codigo, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                            Text('−${c.etiquetaValor}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            AppStatusBadge(
                              label: c.vencido ? 'Vencido' : (c.activo ? 'Activo' : 'Pausado'),
                              tone: c.vigente ? AppStatusTone.success : AppStatusTone.neutral,
                            ),
                          ],
                        ),
                        subtitle: Text(detalle),
                        onTap: () => _editar(context, idNegocio, cupon: c),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Switch(
                              value: c.activo,
                              onChanged: (v) => CuponService.instancia.cambiarActivo(idNegocio, c.codigo, v),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _eliminar(context, idNegocio, c),
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
