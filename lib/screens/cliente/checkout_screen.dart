import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/idioma.dart';
import '../../models/alergenos.dart';
import '../../models/carrito_models.dart';
import '../../models/cupon_model.dart';
import '../../models/direccion_entrega_model.dart';
import '../../models/mesa_model.dart';
import '../../models/negocio_model.dart';
import '../../models/pedido_models.dart';
import '../../models/sucursal_model.dart';
import '../../services/auth_service.dart';
import '../../services/carrito_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/cupon_service.dart';
import '../../services/direcciones_service.dart';
import '../../services/mesa_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/alergias.dart';
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
  String? _zona; // zona de delivery elegida

  /// Alergias del cliente para este pedido (empiezan con las de su cuenta).
  late List<String> _alergias = [...?SesionActual.instancia.actual?.alergias];
  bool _recordarAlergias = true;

  /// Alérgenos de cada producto del carrito (idProducto → códigos).
  Map<String, List<String>> _alergenosProducto = const {};

  /// Productos del carrito que se agotaron (control de stock).
  List<String> _agotados = const [];

  // Cupón
  final _cuponCtrl = TextEditingController();
  CuponModel? _cupon;
  String? _errorCupon;
  bool _validandoCupon = false;

  // Propina (solo Delivery)
  double _propina = 0;

  // Pedido programado (null = lo antes posible)
  bool _programar = false;
  DateTime? _programadoPara;

  // Factura
  bool _quiereFactura = false;
  final _nitCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();

  String get _uid => SesionActual.instancia.actual!.idUsuario;

  /// El cliente debe confirmar su correo antes de pedir (evita cuentas
  /// falsas). Las reglas de Firestore también lo exigen.
  bool _correoVerificado = FirebaseAuth.instance.currentUser?.emailVerified ?? true;
  bool _revisandoCorreo = false;

  Future<void> _reenviarVerificacion() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      messenger.showSnackBar(SnackBar(
        content: Text(tr('Te enviamos el enlace a {correo}. Revisa también la carpeta de spam.',
            {'correo': FirebaseAuth.instance.currentUser?.email ?? ''})),
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr('Espera un momento antes de pedir otro correo.'))));
    }
  }

  Future<void> _comprobarCorreo() async {
    setState(() => _revisandoCorreo = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final ok = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      // Token nuevo: las reglas leen "email_verified" del token.
      if (ok) await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (!mounted) return;
      setState(() => _correoVerificado = ok);
      if (!ok) {
        messenger.showSnackBar(SnackBar(
          content: Text(tr('Todavía no vemos tu correo verificado. Abre el enlace del correo e intenta de nuevo.')),
        ));
      }
    } catch (_) {
      // Sin conexión: se deja como estaba.
    } finally {
      if (mounted) setState(() => _revisandoCorreo = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _comprobanteCtrl.addListener(_onComprobanteCambio);
    _cargarSucursal();
    _cargarAlergenos();
    _cargarFactura();
  }

  String get _claveFactura => 'factura_$_uid';

  /// Los datos de factura se recuerdan en este dispositivo.
  Future<void> _cargarFactura() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final datos = prefs.getStringList(_claveFactura);
      if (datos != null && datos.length == 2 && mounted) {
        setState(() {
          _nitCtrl.text = datos[0];
          _razonSocialCtrl.text = datos[1];
        });
      }
    } catch (_) {}
  }

  Future<void> _guardarFactura() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_claveFactura, [_nitCtrl.text.trim(), _razonSocialCtrl.text.trim()]);
    } catch (_) {}
  }

  double get _subtotal => CarritoService.instancia.calcularTotal(widget.items);
  double get _descuento => _cupon?.descuentoPara(_subtotal) ?? 0;
  double get _propinaAplicada => _modalidad == PedidoModalidad.delivery ? _propina : 0;
  bool get _cobraEnvio => _modalidad == PedidoModalidad.delivery && (_sucursal?.cobraEnvio ?? false);
  double get _costoEnvio => _cobraEnvio ? (_sucursal!.zonasDelivery[_zona] ?? 0) : 0;

  Future<void> _aplicarCupon() async {
    // El cupón es opcional: sin código no se muestra ningún error.
    if (_cuponCtrl.text.trim().isEmpty) {
      setState(() => _errorCupon = null);
      return;
    }
    setState(() {
      _validandoCupon = true;
      _errorCupon = null;
    });
    try {
      final c = await CuponService.instancia.validar(widget.negocio.idNegocio, _cuponCtrl.text, _subtotal);
      if (mounted) setState(() => _cupon = c);
    } catch (e) {
      if (mounted) {
        setState(() {
          _cupon = null;
          _errorCupon = e is CuponException ? e.mensaje : tr('No se pudo comprobar el cupón. Intenta de nuevo.');
        });
      }
    } finally {
      if (mounted) setState(() => _validandoCupon = false);
    }
  }

  bool get _esProgramado => _programar && _modalidad != PedidoModalidad.mesa;

  /// Mensaje de error de la hora programada, o null si está bien.
  String? get _errorProgramado {
    if (!_esProgramado) return null;
    final h = _programadoPara;
    if (h == null) return tr('Elige la hora.');
    if (h.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      return tr('Elige una hora con al menos 30 minutos de anticipación.');
    }
    final s = _sucursal;
    if (s != null && !s.estadoApertura(h).abierta) {
      return tr('El local está cerrado a esa hora. Elige otra.');
    }
    return null;
  }

  Future<void> _elegirHora({required bool manana}) async {
    final ahora = DateTime.now();
    final base = _programadoPara ?? ahora.add(const Duration(minutes: 60));
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: (base.minute ~/ 15) * 15),
      helpText: tr('¿A qué hora lo quieres?'),
    );
    if (hora == null || !mounted) return;
    final dia = manana ? ahora.add(const Duration(days: 1)) : ahora;
    setState(() => _programadoPara = DateTime(dia.year, dia.month, dia.day, hora.hour, hora.minute));
  }

  Future<void> _cargarAlergenos() async {
    try {
      final productos = await CatalogoService.instancia.streamProductos(widget.negocio.idNegocio).first;
      if (!mounted) return;
      setState(() {
        _alergenosProducto = {for (final p in productos) p.id: p.alergenos};
        final porId = {for (final p in productos) p.id: p};
        _agotados = [
          for (final item in widget.items)
            if (porId[item.idProducto] case final p? when p.agotado || !p.disponible || !p.estado)
              item.nombreProducto,
        ];
      });
    } catch (_) {
      // Sin datos de alérgenos igual se puede pedir; la cocina ve las alergias.
    }
  }

  /// Productos del carrito que contienen algo a lo que el cliente es alérgico.
  List<({String producto, List<String> conflicto})> get _conflictos => [
        for (final item in widget.items)
          if (Alergenos.enComun(_alergenosProducto[item.idProducto] ?? const [], _alergias)
              case final c when c.isNotEmpty)
            (producto: item.nombreProducto, conflicto: c),
      ];

  bool get _alergiasCambiaron {
    final cuenta = SesionActual.instancia.actual?.alergias ?? const <String>[];
    return cuenta.join(',') != _alergias.join(',');
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
    _cuponCtrl.dispose();
    _nitCtrl.dispose();
    _razonSocialCtrl.dispose();
    super.dispose();
  }

  /// Lo que paga el cliente: productos − descuento + envío + propina.
  double get _total => _subtotal - _descuento + _costoEnvio + _propinaAplicada;

  bool get _puedeConfirmar => _motivoNoConfirmar == null;

  /// Qué le falta al pedido para poder confirmarlo (se muestra debajo del
  /// botón), o null si está todo listo. El cupón es opcional.
  String? get _motivoNoConfirmar {
    if (!_correoVerificado) return tr('Verifica tu correo para hacer pedidos.');
    if (_agotados.isNotEmpty) return tr('Quita del carrito los productos agotados.');
    if (_esProgramado && _errorProgramado != null) return _errorProgramado;
    // Si está cerrado ahora, solo se puede programar para cuando abra.
    if (!_esProgramado && _apertura != null && !_apertura!.abierta) {
      return tr('El local está cerrado. Programa tu pedido para cuando abra.');
    }
    if (_modalidad == PedidoModalidad.mesa && _idMesa == null) return tr('Elige tu mesa.');
    if (_modalidad == PedidoModalidad.delivery && _direccionElegida == null) {
      return tr('Elige la dirección de entrega.');
    }
    if (_cobraEnvio && !_sucursal!.zonasDelivery.containsKey(_zona)) {
      return tr('Elige la zona de entrega.');
    }
    if (_modalidad == PedidoModalidad.delivery &&
        (_sucursal?.pedidoMinimoDelivery ?? 0) > 0 &&
        _subtotal - _descuento < _sucursal!.pedidoMinimoDelivery) {
      return tr('El pedido mínimo para delivery es Bs {monto}.',
          {'monto': _sucursal!.pedidoMinimoDelivery.toStringAsFixed(2)});
    }
    // HU-26/27: para Transferencia y QR el comprobante ya no es opcional
    // — sin eso el negocio no tiene forma de verificar que se pagó.
    if (_metodoPago != MetodoPago.efectivo && _comprobanteCtrl.text.trim().isEmpty) {
      return tr('Sube el comprobante de pago.');
    }
    if (_subtotal - _descuento <= 0) {
      return tr('El cupón no puede cubrir todo el pedido. Agrega más productos o quita el cupón.');
    }
    if (_quiereFactura && _nitCtrl.text.trim().length < 5) {
      return tr('Escribe tu NIT o CI para la factura.');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Confirmar pedido'))),
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
                        '${tr('No se pueden hacer pedidos ahora. {mensaje}', {'mensaje': _apertura!.mensaje})} '
                        '${tr('Puedes programarlo para cuando abra.')}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (!_correoVerificado) ...[
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mark_email_unread_outlined),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(tr('Verifica tu correo'),
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(tr('Para tu primer pedido necesitamos confirmar que {correo} es tuyo. Abre el enlace que te enviamos y vuelve aquí.',
                        {'correo': FirebaseAuth.instance.currentUser?.email ?? ''})),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        FilledButton.icon(
                          onPressed: _revisandoCorreo ? null : _comprobarCorreo,
                          icon: const Icon(Icons.check),
                          label: Text(tr('Ya lo verifiqué')),
                        ),
                        OutlinedButton.icon(
                          onPressed: _reenviarVerificacion,
                          icon: const Icon(Icons.send_outlined),
                          label: Text(tr('Reenviar correo')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(tr('1. ¿Cómo quieres tu pedido?'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(tr('Recoger')),
                selected: _modalidad == PedidoModalidad.recoger,
                onSelected: (_) => setState(() => _modalidad = PedidoModalidad.recoger),
              ),
              ChoiceChip(
                label: Text(tr('Mesa')),
                selected: _modalidad == PedidoModalidad.mesa,
                onSelected: (_) => setState(() => _modalidad = PedidoModalidad.mesa),
              ),
              ChoiceChip(
                label: Text(tr('Delivery')),
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
            if (_sucursal?.cobraEnvio ?? false) ...[
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: _sucursal!.zonasDelivery.containsKey(_zona) ? _zona : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('Zona de entrega *'),
                  prefixIcon: const Icon(Icons.map_outlined),
                  helperText: tr('El costo de envío depende de la zona.'),
                ),
                items: [
                  for (final z in _sucursal!.zonasOrdenadas)
                    DropdownMenuItem(
                      value: z.key,
                      child: Text('${z.key} · Bs ${z.value.toStringAsFixed(2)}'),
                    ),
                ],
                onChanged: (z) => setState(() => _zona = z),
              ),
            ],
          ],
          if (_modalidad != PedidoModalidad.mesa) ...[
            const SizedBox(height: AppSpacing.md),
            Text(tr('¿Para cuándo?'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.bolt_outlined, size: 18),
                  label: Text(tr('Lo antes posible')),
                  selected: !_programar,
                  onSelected: (_) => setState(() => _programar = false),
                ),
                ChoiceChip(
                  avatar: const Icon(Icons.schedule, size: 18),
                  label: Text(tr('Programar')),
                  selected: _programar,
                  onSelected: (_) => setState(() => _programar = true),
                ),
              ],
            ),
            if (_programar) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _elegirHora(manana: false),
                    icon: const Icon(Icons.today_outlined),
                    label: Text(tr('Hoy')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _elegirHora(manana: true),
                    icon: const Icon(Icons.event_outlined),
                    label: Text(tr('Mañana')),
                  ),
                  if (_programadoPara != null)
                    Chip(
                      avatar: const Icon(Icons.alarm_on_outlined, size: 18),
                      label: Text(formatoProgramado(_programadoPara!),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              if (_errorProgramado != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _errorProgramado!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
            ],
          ],
          const Divider(height: AppSpacing.xl),
          Text(tr('2. ¿Cómo vas a pagar?'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final m in MetodoPago.todos)
                ChoiceChip(
                  label: Text(tr(m)),
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
              etiqueta: tr('Comprobante de pago (obligatorio)'),
              controller: _comprobanteCtrl,
              rutaStorage:
                  'negocios/${widget.negocio.idNegocio}/comprobantes/${_uid}_${DateTime.now().millisecondsSinceEpoch}',
            ),
            if (_comprobanteCtrl.text.trim().isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr('Sube tu comprobante o pega el link para poder confirmar el pedido.'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
          const Divider(height: AppSpacing.xl),
          Text(tr('3. ¿Tienes alguna alergia?'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('Marca lo que no puedes comer. El local lo verá en su idioma, sin errores de traducción.'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectorAlergias(
            seleccionadas: _alergias,
            onChanged: (v) => setState(() => _alergias = v),
          ),
          if (_alergiasCambiaron)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _recordarAlergias,
              onChanged: (v) => setState(() => _recordarAlergias = v ?? false),
              title: Text(tr('Recordar mis alergias para los próximos pedidos')),
            ),
          if (_conflictos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _AvisoConflictos(conflictos: _conflictos),
          ],
          const Divider(height: AppSpacing.xl),
          Text(tr('4. ¿Alguna nota para tu pedido?'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notasCtrl,
            maxLines: 2,
            maxLength: 250,
            decoration: InputDecoration(
              hintText: tr('Ej. bien cocido, tocar el timbre, etc. (opcional)'),
              helperText: tr('Puedes escribir en tu idioma: el local verá la nota traducida.'),
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _SeccionCupon(
            controller: _cuponCtrl,
            cupon: _cupon,
            error: _errorCupon,
            validando: _validandoCupon,
            onAplicar: _aplicarCupon,
            onQuitar: () => setState(() {
              _cupon = null;
              _cuponCtrl.clear();
            }),
            onEscribir: () {
              if (_errorCupon != null) setState(() => _errorCupon = null);
            },
          ),
          if (_modalidad == PedidoModalidad.delivery) ...[
            const SizedBox(height: AppSpacing.md),
            Text(tr('Propina para el repartidor (opcional)'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final p in const [0.0, 2.0, 5.0, 10.0])
                  ChoiceChip(
                    label: Text(p == 0 ? tr('Sin propina') : 'Bs ${p.toStringAsFixed(0)}'),
                    selected: _propina == p,
                    onSelected: (_) => setState(() => _propina = p),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _quiereFactura,
            onChanged: (v) => setState(() => _quiereFactura = v ?? false),
            title: Text(tr('Quiero factura')),
          ),
          if (_quiereFactura) ...[
            TextField(
              controller: _nitCtrl,
              keyboardType: TextInputType.number,
              maxLength: 20,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('NIT o CI *')),
            ),
            TextField(
              controller: _razonSocialCtrl,
              maxLength: 80,
              decoration: InputDecoration(labelText: tr('Nombre o razón social')),
            ),
          ],
          if (_agotados.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: AppRadius.mdAll,
              ),
              child: Text(
                tr('Ya no quedan: {lista}. Quítalos del carrito para continuar.', {'lista': _agotados.join(', ')}),
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
          const Divider(height: AppSpacing.xl),
          _FilaResumen(etiqueta: tr('Productos'), valor: _subtotal),
          if (_descuento > 0)
            _FilaResumen(
              etiqueta: tr('Descuento ({codigo})', {'codigo': _cupon!.codigo}),
              valor: -_descuento,
              resaltar: true,
            ),
          if (_costoEnvio > 0)
            _FilaResumen(etiqueta: tr('Envío ({zona})', {'zona': _zona ?? ''}), valor: _costoEnvio),
          if (_propinaAplicada > 0) _FilaResumen(etiqueta: tr('Propina'), valor: _propinaAplicada),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('Total'), style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                tr('Bs {total}', {'total': _total.toStringAsFixed(2)}),
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
                : Text(tr('Confirmar pedido')),
          ),
          if (_motivoNoConfirmar != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      _motivoNoConfirmar!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      )),
    );
  }

  /// Si hay productos con algo a lo que el cliente es alérgico, pide que lo
  /// confirme antes de enviar el pedido.
  Future<bool> _aceptaConflictos() async {
    final conflictos = _conflictos;
    if (conflictos.isEmpty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 36),
        title: Text(tr('Revisa tu pedido')),
        content: SizedBox(
          width: 420,
          child: _AvisoConflictos(conflictos: conflictos),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cambiar pedido'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Entiendo, enviar'))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _guardarAlergiasEnCuenta() async {
    if (!_recordarAlergias || !_alergiasCambiaron) return;
    final error = await AuthService.instancia.actualizarAlergias(_alergias);
    final u = SesionActual.instancia.actual;
    if (error == null && u != null) {
      SesionActual.instancia.usuario.value = u.conAlergias(_alergias);
    }
  }

  Future<void> _confirmar() async {
    if (!await _aceptaConflictos() || !mounted) return;
    setState(() => _confirmando = true);
    try {
      // Comprobación final con datos frescos: el horario pudo cambiar o la
      // sucursal cerrar mientras el cliente armaba el pedido.
      final fresca = await SucursalService.instancia.obtener(widget.idSucursal);
      if (fresca != null) {
        final ap = fresca.estadoApertura(_esProgramado ? _programadoPara : null);
        if (!ap.abierta) {
          if (mounted) setState(() => _sucursal = fresca);
          throw Exception(tr('No se pueden hacer pedidos ahora. {mensaje}', {'mensaje': ap.mensaje}));
        }
      }
      final idPedido = await PedidoService.instancia.confirmarPedido(
        idCliente: _uid,
        idNegocio: widget.negocio.idNegocio,
        idSucursal: widget.idSucursal,
        modalidad: _modalidad,
        // Si el cliente eligió una mesa o una dirección y después cambió de
        // modalidad (o subió un comprobante y cambió a Efectivo), esos datos
        // ya no corresponden y no se guardan en el pedido.
        idMesa: _modalidad == PedidoModalidad.mesa ? _idMesa : null,
        direccionEntrega: _modalidad == PedidoModalidad.delivery
            ? _direccionElegida?.toSnapshotMap()
            : null,
        metodoPago: _metodoPago,
        comprobantePagoUrl: _metodoPago == MetodoPago.efectivo || _comprobanteCtrl.text.trim().isEmpty
            ? null
            : _comprobanteCtrl.text.trim(),
        itemsCarrito: widget.items,
        notas: _notasCtrl.text.trim(),
        alergias: _alergias,
        codigoCupon: _cupon?.codigo,
        propina: _propinaAplicada,
        programadoPara: _esProgramado ? _programadoPara : null,
        facturaNit: _quiereFactura ? _nitCtrl.text.trim() : null,
        facturaRazonSocial: _quiereFactura ? _razonSocialCtrl.text.trim() : null,
        zonaEntrega: _modalidad == PedidoModalidad.delivery ? _zona : null,
      );
      if (_quiereFactura) await _guardarFactura();
      // Si falla, el pedido igual ya se envió con las alergias.
      await _guardarAlergiasEnCuenta().catchError((_) {});
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

/// Campo para escribir y aplicar un cupón de descuento.
class _SeccionCupon extends StatelessWidget {
  final TextEditingController controller;
  final CuponModel? cupon;
  final String? error;
  final bool validando;
  final VoidCallback onAplicar;
  final VoidCallback onQuitar;
  final VoidCallback onEscribir;

  const _SeccionCupon({
    required this.onEscribir,
    required this.controller,
    required this.cupon,
    required this.error,
    required this.validando,
    required this.onAplicar,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (cupon != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer, color: scheme.onPrimaryContainer),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                tr('Cupón {codigo} aplicado: −{valor}', {'codigo': cupon!.codigo, 'valor': cupon!.etiquetaValor}),
                style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: tr('Quitar cupón'),
              icon: Icon(Icons.close, color: scheme.onPrimaryContainer),
              onPressed: onQuitar,
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            onSubmitted: (_) => onAplicar(),
            onChanged: (_) => onEscribir(),
            decoration: InputDecoration(
              labelText: tr('¿Tienes un cupón? (opcional)'),
              prefixIcon: const Icon(Icons.local_offer_outlined),
              errorText: error,
              errorMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton(
            onPressed: validando ? null : onAplicar,
            child: validando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(tr('Aplicar')),
          ),
        ),
      ],
    );
  }
}

class _FilaResumen extends StatelessWidget {
  final String etiqueta;
  final double valor;
  final bool resaltar;
  const _FilaResumen({required this.etiqueta, required this.valor, this.resaltar = false});

  @override
  Widget build(BuildContext context) {
    final color = resaltar ? Theme.of(context).colorScheme.primary : null;
    final texto = valor < 0
        ? '−Bs ${(-valor).toStringAsFixed(2)}'
        : 'Bs ${valor.toStringAsFixed(2)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: TextStyle(color: color)),
          Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Lista de productos del carrito que contienen algo a lo que el cliente
/// es alérgico.
class _AvisoConflictos extends StatelessWidget {
  final List<({String producto, List<String> conflicto})> conflictos;
  const _AvisoConflictos({required this.conflictos});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: AppRadius.mdAll),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: scheme.onErrorContainer),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Estos productos contienen algo a lo que eres alérgico:'),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final c in conflictos)
              Text('• ${c.producto}: ${Alergenos.nombres(c.conflicto)}'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('Le avisaremos a la cocina. Si el ingrediente no se puede quitar, el local cancelará el pedido y te dirá el motivo.'),
            ),
          ],
        ),
      ),
    );
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
            tr('Este negocio todavía no subió su QR de pago. Coordina el pago directamente con el negocio antes de confirmar.'),
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
              tr('Escanea este código para pagar, luego sube tu comprobante.'),
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
          return Text(tr('Este local todavía no tiene mesas registradas.'));
        }
        return DropdownButtonFormField<String>(
          value: seleccionada,
          decoration: InputDecoration(labelText: tr('Elige tu mesa')),
          items: mesas
              .map((m) => DropdownMenuItem(
                    value: m.id,
                    child: Text(tr('Mesa {numero} ({estado})', {'numero': m.numero, 'estado': tr(m.estado)})),
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
          title: Text(tr('Nueva dirección')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: etiquetaCtrl,
                    decoration: InputDecoration(labelText: tr('Etiqueta (ej. Casa, Trabajo)')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    icon: Icon(
                      ubicacion == null ? Icons.add_location_alt_outlined : Icons.check_circle,
                    ),
                    label: Text(
                      ubicacion == null
                          ? tr('Marcar ubicación en el mapa *')
                          : tr('Ubicación marcada (tocar para cambiar)'),
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
                    decoration: InputDecoration(
                      labelText: tr('Dirección *'),
                      helperText: tr('Calle, número, edificio o zona. Puedes corregirla.'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: referenciaCtrl,
                    decoration: InputDecoration(
                      labelText: tr('Referencia (opcional)'),
                      helperText: tr('Ej. portón verde, piso 3, depto B'),
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
              child: Text(tr('Cancelar')),
            ),
            FilledButton(
              onPressed: () {
                if (ubicacion == null) {
                  setState(() => error = tr('Marca tu ubicación en el mapa para que el repartidor te encuentre.'));
                  return;
                }
                if (direccionCtrl.text.trim().isEmpty) {
                  setState(() => error = tr('Escribe la dirección.'));
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(tr('Guardar')),
            ),
          ],
        ),
      ),
    );
    if (guardar != true || ubicacion == null || direccionCtrl.text.trim().isEmpty) return;
    final nueva = DireccionEntregaModel(
      id: '',
      etiqueta: etiquetaCtrl.text.trim().isEmpty ? tr('Dirección') : etiquetaCtrl.text.trim(),
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
            Text(tr('Dirección de entrega'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (direcciones.isEmpty)
              Text(tr('Todavía no tienes direcciones guardadas.'))
            else
              ...direcciones.map((d) => RadioListTile<String>(
                    value: d.id,
                    groupValue: seleccionada?.id,
                    title: Text(d.etiqueta),
                    subtitle: Text(
                      d.tieneUbicacion
                          ? d.direccion
                          : tr('{direccion}\n(Sin ubicación en el mapa: agrega una dirección nueva)', {'direccion': d.direccion}),
                    ),
                    onChanged: (_) => onChanged(d),
                  )),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(tr('Agregar dirección')),
              onPressed: () => _agregarDireccion(context),
            ),
          ],
        );
      },
    );
  }
}
