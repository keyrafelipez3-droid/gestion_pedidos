import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/actividad_model.dart';
import '../models/pedido_models.dart';
import '../services/actividad_service.dart';
import '../services/pedido_service.dart';
import '../services/sesion_actual.dart';
import '../theme/design_tokens.dart';
import '../utils/errores.dart';
import 'confirmar_identidad.dart';

/// Motivos frecuentes (la persona puede elegir uno y completarlo).
const motivosCancelacion = [
  'El cliente pidió cancelar',
  'Producto agotado',
  'El cliente no respondió',
  'Dirección fuera de la zona de entrega',
  'Pago no verificado',
];

/// Quién puede cancelar pedidos: Cajero y Administrador.
bool puedeCancelarPedidos() =>
    SesionActual.instancia.esCajero || SesionActual.instancia.esAdministrador;

/// Pide el motivo y cancela el pedido. Muestra el resultado en un SnackBar.
Future<void> cancelarPedidoConMotivo(BuildContext context, PedidoModel pedido) async {
  final motivo = await showDialog<String>(
    context: context,
    builder: (_) => _DialogoMotivo(pedido: pedido),
  );
  if (motivo == null || !context.mounted) return;
  // Acción sensible: se vuelve a pedir la contraseña (y el código).
  if (!await confirmarIdentidad(context, accion: 'cancelar el pedido') || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await PedidoService.instancia.cancelarPedido(
      idPedido: pedido.id,
      motivo: motivo,
      idUsuario: SesionActual.instancia.actual?.idUsuario ?? '',
    );
    ActividadService.instancia.registrar(
      ActividadTipo.pedido,
      'Canceló el pedido #${pedido.id.substring(0, 6)} (Bs ${pedido.total.toStringAsFixed(2)}). Motivo: $motivo',
    );
    messenger.showSnackBar(const SnackBar(content: Text('Pedido cancelado. El cliente verá el motivo.')));
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
  }
}

class _DialogoMotivo extends StatefulWidget {
  final PedidoModel pedido;
  const _DialogoMotivo({required this.pedido});

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _elegido;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enReparto = widget.pedido.enReparto;
    return AlertDialog(
      title: Text('Cancelar pedido #${widget.pedido.id.substring(0, 6)}'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (enReparto)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Text(
                    'Este pedido ya salió con un repartidor. Avísale que vuelva al local.',
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              const Text('Elige un motivo o escríbelo. El cliente lo verá en su pedido.'),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final m in motivosCancelacion)
                    ChoiceChip(
                      label: Text(m),
                      selected: _elegido == m,
                      onSelected: (_) => setState(() {
                        _elegido = m;
                        _ctrl.text = m;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ctrl,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Motivo de la cancelación *'),
                validator: (v) =>
                    (v == null || v.trim().length < 4) ? 'Escribe el motivo (mínimo 4 letras).' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () {
            if (_formKey.currentState!.validate()) Navigator.of(context).pop(_ctrl.text.trim());
          },
          child: const Text('Cancelar pedido'),
        ),
      ],
    );
  }
}

/// Aviso rojo con el motivo, visible en el detalle de un pedido cancelado.
class AvisoCancelacion extends StatefulWidget {
  final String idPedido;
  const AvisoCancelacion({super.key, required this.idPedido});

  @override
  State<AvisoCancelacion> createState() => _AvisoCancelacionState();
}

class _AvisoCancelacionState extends State<AvisoCancelacion> {
  late final Stream<List<HistorialEstadoModel>> _historial =
      PedidoService.instancia.streamHistorial(widget.idPedido);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<List<HistorialEstadoModel>>(
      stream: _historial,
      builder: (context, s) {
        final cancelacion = (s.data ?? const <HistorialEstadoModel>[])
            .where((h) => h.estado == PedidoEstado.cancelado)
            .lastOrNull;
        final motivo = cancelacion?.comentario.replaceFirst('Motivo: ', '').trim() ?? '';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: AppRadius.mdAll),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.cancel_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Este pedido fue cancelado'),
                      style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700),
                    ),
                    if (motivo.isNotEmpty)
                      Text(tr('Motivo: {motivo}', {'motivo': tr(motivo)}), style: TextStyle(color: scheme.onErrorContainer)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
