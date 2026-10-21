import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/carrito_models.dart';
import '../../models/direccion_entrega_model.dart';
import '../../models/mesa_model.dart';
import '../../models/negocio_model.dart';
import '../../models/pedido_models.dart';
import '../../models/sucursal_model.dart';
import '../../services/carrito_service.dart';
import '../../services/direcciones_service.dart';
import '../../services/mesa_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/sucursal_service.dart';
import '../../utils/errores.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/selector_imagen.dart';
import '../mapa/selector_ubicacion_screen.dart';
import 'pedido_detalle_screen.dart';

/// HU-24/25/26/27: elegir modalidad (mesa/recoger/delivery), dirección
/// si corresponde, método de pago, comprobante si corresponde, y
/// confirmar el pedido.
class CheckoutScreen extends StatefulWidget {
  final NegocioModel negocio;
  final String idSucursal;
  final List<CarritoItemModel> items;

  const CheckoutScreen({
    super.key,
    required this.negocio,
    required this.idSucursal,
    required this.items,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _modalidad = PedidoModalidad.recoger;
  String? _idMesa;
  DireccionEntregaModel? _direccionElegida;
  String _metodoPago = MetodoPago.efectivo;
  final _comprobanteCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  bool _confirmando = false;
  SucursalModel? _sucursal;

  String get _uid => SesionActual.instancia.actual!.idUsuario;

  @override
  void initState() {
    super.initState();
    _comprobanteCtrl.addListener(_onComprobanteCambio);
    _cargarSucursal();
  }

  Future<void> _cargarSucursal() async {
    try {
      final s = await SucursalService.instancia.obtener(widget.idSucursal);
      if (mounted) setState(() => _sucursal = s);
    } catch (_) {
      // Sin dato de horarios no se bloquea; se vuelve a comprobar al confirmar.
    }
  }

  AperturaSucursal? get _apertura => _sucursal?.estadoApertura();

  void _onComprobanteCambio() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _comprobanteCtrl.removeListener(_onComprobanteCambio);
    _comprobanteCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  double get _total => CarritoService.instancia.calcularTotal(widget.items);

  bool get _puedeConfirmar {
    if (_apertura != null && !_apertura!.abierta) return false;
    if (_modalidad == PedidoModalidad.mesa && _idMesa == null) return false;
    if (_modalidad == PedidoModalidad.delivery && _direccionElegida == null) return false;
    // HU-26/27: para Transferencia y QR el comprobante ya no es opcional
    // — sin eso el negocio no tiene forma de verificar que se pagó.
    if (_metodoPago != MetodoPago.efectivo && _comprobanteCtrl.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar pedido')),
      body: AppContenidoCentrado(child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_apertura != null && !_apertura!.abierta) ...[
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.schedule, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No se pueden hacer pedidos ahora. ${_apertura!.mensaje}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('1. ¿Cómo quieres tu pedido?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Recoger'),
                selected: _modalidad == PedidoModalidad.recoger,
                onSelected: (_) => setState(() => _modalidad = PedidoModalidad.recoger),
              ),
              ChoiceChip(
                label: const Text('Mesa'),
                selected: _modalidad == PedidoModalidad.mesa,
                onSelected: (_) => setState(() => _modalidad = PedidoModalidad.mesa),
              ),
              ChoiceChip(
                label: const Text('Delivery'),
                selected: _modalidad == PedidoModalidad.delivery,
                onSelected: (_) => setState(() => _modalidad = PedidoModalidad.delivery),
              ),
            ],
          ),
          if (_modalidad == PedidoModalidad.mesa) ...[
            const SizedBox(height: AppSpacing.md),
            _SelectorMesa(
              idSucursal: widget.idSucursal,
              seleccionada: _idMesa,
              onChanged: (id) => setState(() => _idMesa = id),
            ),
          ],
          if (_modalidad == PedidoModalidad.delivery) ...[
            const SizedBox(height: AppSpacing.md),
            _SelectorDireccion(
              uid: _uid,
              seleccionada: _direccionElegida,
              onChanged: (d) => setState(() => _direccionElegida = d),
            ),
          ],
          const Divider(height: AppSpacing.xl),
          Text('2. ¿Cómo vas a pagar?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final m in MetodoPago.todos)
                ChoiceChip(
                  label: Text(m),
                  selected: _metodoPago == m,
                  onSelected: (_) => setState(() => _metodoPago = m),
                ),
            ],
          ),
          if (_metodoPago == MetodoPago.qr) ...[
            const SizedBox(height: AppSpacing.md),
            _QrDelNegocio(qrUrl: widget.negocio.qrPagoUrl),
          ],
          if (_metodoPago != MetodoPago.efectivo) ...[
            const SizedBox(height: AppSpacing.md),
            SelectorImagen(
              etiqueta: 'Comprobante de pago (obligatorio)',
              controller: _comprobanteCtrl,
              rutaStorage:
                  'negocios/${widget.negocio.idNegocio}/comprobantes/${_uid}_${DateTime.now().millisecondsSinceEpoch}',
            ),
            if (_comprobanteCtrl.text.trim().isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sube tu comprobante o pega el link para poder confirmar el pedido.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
          const Divider(height: AppSpacing.xl),
          Text('3. ¿Alguna nota para tu pedido?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notasCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Ej. sin cebolla, tocar el timbre, etc. (opcional)',
            ),
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                'Bs ${_total.toStringAsFixed(2)}',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: !_puedeConfirmar || _confirmando ? null : _confirmar,
            child: _confirmando
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmar pedido'),
          ),
        ],
      )),
    );
  }

  Future<void> _confirmar() async {
    setState(() => _confirmando = true);
    try {
      // Comprobación final con datos frescos: el horario pudo cambiar o la
      // sucursal cerrar mientras el cliente armaba el pedido.
      final fresca = await SucursalService.instancia.obtener(widget.idSucursal);
      if (fresca != null) {
        final ap = fresca.estadoApertura();
        if (!ap.abierta) {
          if (mounted) setState(() => _sucursal = fresca);
          throw Exception('No se pueden hacer pedidos ahora. ${ap.mensaje}');
        }
      }
      final idPedido = await PedidoService.instancia.confirmarPedido(
        idCliente: _uid,
        idNegocio: widget.negocio.idNegocio,
        idSucursal: widget.idSucursal,
        modalidad: _modalidad,
        idMesa: _idMesa,
        direccionEntrega: _direccionElegida?.toSnapshotMap(),
        metodoPago: _metodoPago,
        comprobantePagoUrl: _comprobanteCtrl.text.isEmpty ? null : _comprobanteCtrl.text,
        itemsCarrito: widget.items,
        notas: _notasCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PedidoDetalleScreen(idPedido: idPedido)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(textoError(e))),
      );
    } finally {
      if (mounted) setState(() => _confirmando = false);
    }
  }
}

/// Muestra el QR de pago que el Administrador configuró para el negocio
/// (Personalización → Pagos), para que el cliente lo escanee y pague
/// ANTES de subir su comprobante. Si el negocio todavía no subió uno, se
/// avisa en vez de dejar al cliente sin saber cómo pagar.
class _QrDelNegocio extends StatelessWidget {
  final String qrUrl;
  const _QrDelNegocio({required this.qrUrl});

  @override
  Widget build(BuildContext context) {
    if (qrUrl.isEmpty) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Este negocio todavía no subió su QR de pago. Coordina el pago '
            'directamente con el negocio antes de confirmar.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escanea este código para pagar, luego sube tu comprobante.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppRadius.mdAll,
              child: Image.network(
                qrUrl, webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 220,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorMesa extends StatelessWidget {
  final String idSucursal;
  final String? seleccionada;
  final ValueChanged<String?> onChanged;

  const _SelectorMesa({
    required this.idSucursal,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MesaModel>>(
      stream: MesaService.instancia.streamMesas(idSucursal),
      builder: (context, snapshot) {
        final mesas = snapshot.data ?? [];
        if (mesas.isEmpty) {
          return const Text('Este local todavía no tiene mesas registradas.');
        }
        return DropdownButtonFormField<String>(
          value: seleccionada,
          decoration: const InputDecoration(labelText: 'Elige tu mesa'),
          items: mesas
              .map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text('Mesa ${m.numero} (${m.estado})'),
                  ))
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}

class _SelectorDireccion extends StatelessWidget {
  final String uid;
  final DireccionEntregaModel? seleccionada;
  final ValueChanged<DireccionEntregaModel?> onChanged;

  const _SelectorDireccion({
    required this.uid,
    required this.seleccionada,
    required this.onChanged,
  });

  Future<void> _agregarDireccion(BuildContext context) async {
    final etiquetaCtrl = TextEditingController();
    final direccionCtrl = TextEditingController();
    final referenciaCtrl = TextEditingController();
    LatLng? ubicacion;
    String? error;
    final guardar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva dirección'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: etiquetaCtrl,
                    decoration: const InputDecoration(labelText: 'Etiqueta (ej. Casa, Trabajo)'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: Icon(
                      ubicacion == null ? Icons.add_location_alt_outlined : Icons.check_circle,
                    ),
                    label: Text(
                      ubicacion == null
                          ? 'Marcar ubicación en el mapa *'
                          : 'Ubicación marcada (tocar para cambiar)',
                    ),
                    onPressed: () async {
                      final elegida = await Navigator.of(dialogContext).push<UbicacionElegida>(
                        MaterialPageRoute(
                          builder: (_) => SelectorUbicacionScreen(inicial: ubicacion),
                        ),
                      );
                      if (elegida == null) return;
                      setState(() {
                        ubicacion = elegida.punto;
                        error = null;
                        // Se sugiere la dirección encontrada, sin pisar lo
                        // que el usuario ya hubiera escrito.
                        if (direccionCtrl.text.trim().isEmpty &&
                            elegida.direccionSugerida != null) {
                          direccionCtrl.text = elegida.direccionSugerida!;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: direccionCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Dirección *',
                      helperText: 'Calle, número, edificio o zona. Puedes corregirla.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: referenciaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Referencia (opcional)',
                      helperText: 'Ej. portón verde, piso 3, depto B',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (ubicacion == null) {
                  setState(() => error = 'Marca tu ubicación en el mapa para que el repartidor te encuentre.');
                  return;
                }
                if (direccionCtrl.text.trim().isEmpty) {
                  setState(() => error = 'Escribe la dirección.');
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (guardar != true || ubicacion == null || direccionCtrl.text.trim().isEmpty) return;
    final nueva = DireccionEntregaModel(
      id: '',
      etiqueta: etiquetaCtrl.text.trim().isEmpty ? 'Dirección' : etiquetaCtrl.text.trim(),
      direccion: direccionCtrl.text.trim(),
      referencia: referenciaCtrl.text.trim(),
      latitud: ubicacion!.latitude,
      longitud: ubicacion!.longitude,
    );
    await DireccionesService.instancia.guardarDireccion(uid, nueva);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DireccionEntregaModel>>(
      stream: DireccionesService.instancia.streamDirecciones(uid),
      builder: (context, snapshot) {
        final direcciones = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dirección de entrega', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (direcciones.isEmpty)
              const Text('Todavía no tienes direcciones guardadas.')
            else
              ...direcciones.map((d) => RadioListTile<String>(
                    value: d.id,
                    groupValue: seleccionada?.id,
                    title: Text(d.etiqueta),
                    subtitle: Text(
                      d.tieneUbicacion
                          ? d.direccion
                          : '${d.direccion}\n(Sin ubicación en el mapa: agrega una dirección nueva)',
                    ),
                    onChanged: (_) => onChanged(d),
                  )),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Agregar dirección'),
              onPressed: () => _agregarDireccion(context),
            ),
          ],
        );
      },
    );
  }
}
