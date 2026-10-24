import 'package:flutter/material.dart';

import '../../models/actividad_model.dart';
import '../../models/caja_models.dart';
import '../../models/usuario_model.dart';
import '../../services/actividad_service.dart';
import '../../services/caja_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/confirmar_identidad.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';

/// HU-46: apertura, movimientos y cierre de caja del Cajero.
///
/// Una caja por Cajero y por turno. Durante el turno el Cajero ve lo que
/// cobró y los ingresos/egresos que registró, pero NO el efectivo que
/// "debería haber": ese dato aparece recién después de contar el
/// efectivo (cierre ciego), para que el conteo sea honesto.
class CajeroCajaScreen extends StatelessWidget {
  const CajeroCajaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = SesionActual.instancia.actual;
    return Scaffold(
      appBar: AppBar(title: const Text('Caja')),
      body: usuario == null
          ? const AppEmptyState(
              icon: Icons.point_of_sale,
              title: 'No se pudo identificar tu usuario',
            )
          : AppContenidoCentrado(
              child: StreamBuilder<CajaModel?>(
                stream: CajaService.instancia.streamCajaAbierta(usuario.idUsuario),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text('No se pudo cargar la caja: ${snapshot.error}'),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final caja = snapshot.data;
                  return ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      if (caja == null)
                        _SinCaja(usuario: usuario)
                      else
                        _CajaAbierta(caja: caja, usuario: usuario),
                      const SizedBox(height: AppSpacing.lg),
                      _Historial(idCajero: usuario.idUsuario),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

// ------------------------------------------------------------------ helpers

String _bs(double v) => 'Bs ${v.toStringAsFixed(2)}';

String _mensaje(Object e) => e.toString().replaceFirst('Exception: ', '');

String _dos(int n) => n.toString().padLeft(2, '0');

String _hora(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${_dos(l.hour)}:${_dos(l.minute)}';
}

String _fechaHora(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${_dos(l.day)}/${_dos(l.month)}/${l.year} ${_hora(l)}';
}

/// Texto y tono de la diferencia (contado − esperado).
({String texto, AppStatusTone tono}) _estadoDiferencia(double diferencia) {
  if (diferencia == 0) {
    return (texto: 'Cuadra', tono: AppStatusTone.success);
  }
  if (diferencia < 0) {
    return (texto: 'Falta ${_bs(-diferencia)}', tono: AppStatusTone.danger);
  }
  return (texto: 'Sobra ${_bs(diferencia)}', tono: AppStatusTone.warning);
}

class _Fila extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final bool destacada;

  const _Fila(this.etiqueta, this.valor, {this.destacada = false});

  @override
  Widget build(BuildContext context) {
    final estilo = destacada
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(etiqueta, style: estilo)),
          const SizedBox(width: AppSpacing.sm),
          Text(valor, style: estilo?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- sin caja

class _SinCaja extends StatelessWidget {
  final UsuarioModel usuario;

  const _SinCaja({required this.usuario});

  Future<void> _abrir(BuildContext context) async {
    final monto = await showDialog<double>(
      context: context,
      builder: (_) => const _MontoDialog(
        titulo: 'Abrir caja',
        etiqueta: 'Monto inicial',
        ayuda: 'Efectivo con el que empiezas el turno (por ejemplo, para dar '
            'cambio). Puede ser 0.',
        confirmar: 'Abrir caja',
        permiteCero: true,
      ),
    );
    if (monto == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CajaService.instancia.abrirCaja(cajero: usuario, montoInicial: monto);
      ActividadService.instancia.registrar(ActividadTipo.caja, 'Abrió su caja con ${_bs(monto)}');
      messenger.showSnackBar(SnackBar(content: Text('Caja abierta con ${_bs(monto)}.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensaje(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.point_of_sale, size: 44, color: theme.colorScheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No tienes una caja abierta',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              usuario.idSucursal == null
                  ? 'Tu usuario no tiene sucursal asignada. Pídele al '
                      'Administrador que te la asigne para poder abrir caja.'
                  : 'Ábrela para poder cobrar mesas y entregar pedidos.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (usuario.idSucursal != null) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () => _abrir(context),
                icon: const Icon(Icons.lock_open),
                label: const Text('Abrir caja'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- caja abierta

class _CajaAbierta extends StatelessWidget {
  final CajaModel caja;
  final UsuarioModel usuario;

  const _CajaAbierta({required this.caja, required this.usuario});

  Future<void> _registrar(BuildContext context, String tipo) async {
    final datos = await showDialog<_DatosMovimiento>(
      context: context,
      builder: (_) => _MovimientoDialog(tipo: tipo),
    );
    if (datos == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CajaService.instancia.registrarMovimientoManual(
        caja: caja,
        tipo: tipo,
        concepto: datos.concepto,
        monto: datos.monto,
        idUsuario: usuario.idUsuario,
      );
      messenger.showSnackBar(SnackBar(content: Text('$tipo registrado.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensaje(e))));
    }
  }

  Future<void> _iniciarCierre(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final mesas = await PedidoService.instancia.contarMesasConCuentaAbierta(
        idNegocio: caja.idNegocio,
        idSucursal: caja.idSucursal,
      );
      if (!context.mounted) return;
      if (mesas > 0) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hay mesas sin cobrar'),
            content: Text(
              mesas == 1
                  ? 'Hay 1 mesa con la cuenta abierta. Cóbrala (o ciérrala) '
                      'antes de cerrar la caja.'
                  : 'Hay $mesas mesas con la cuenta abierta. Cóbralas (o '
                      'ciérralas) antes de cerrar la caja.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
        return;
      }
      final monto = await showDialog<double>(
        context: context,
        builder: (_) => const _MontoDialog(
          titulo: 'Contar el efectivo',
          etiqueta: 'Efectivo contado',
          ayuda: 'Cuenta todo el efectivo que hay en el cajón. Todavía no verás '
              'cuánto debería haber. Después de confirmar no podrás cambiar '
              'este monto ni registrar más movimientos.',
          confirmar: 'Confirmar conteo',
          permiteCero: true,
        ),
      );
      if (monto == null) return;
      await CajaService.instancia.registrarConteo(caja, monto);
      ActividadService.instancia.registrar(ActividadTipo.caja, 'Registró el conteo de su caja: ${_bs(monto)}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensaje(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<List<MovimientoCajaModel>>(
      stream: CajaService.instancia.streamMovimientos(caja.id),
      builder: (context, snapshot) {
        final movimientos = snapshot.data ?? const <MovimientoCajaModel>[];
        final resumen = ResumenCaja.de(caja.montoInicial, movimientos);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Caja abierta',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        AppStatusBadge(
                          label: caja.contada ? 'En cierre' : 'Abierta',
                          tone: caja.contada ? AppStatusTone.warning : AppStatusTone.success,
                        ),
                      ],
                    ),
                    Text(
                      'Desde ${_fechaHora(caja.fechaApertura)} · ${caja.nombreCajero}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.sm),
                    _Fila('Monto inicial', _bs(resumen.montoInicial)),
                    _Fila('Cobros en efectivo', _bs(resumen.cobrosEfectivo)),
                    _Fila('Ingresos', _bs(resumen.ingresos)),
                    _Fila('Egresos', _bs(resumen.egresos)),
                    const SizedBox(height: AppSpacing.xs),
                    _Fila(
                      'Cobros por transferencia y QR (no van al cajón)',
                      _bs(resumen.cobrosTransferencia + resumen.cobrosQr),
                    ),
                    if (!caja.contada) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'El efectivo esperado se muestra al cerrar, después de '
                        'contar el efectivo del cajón.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (!caja.contada) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _registrar(context, MovimientoTipo.ingreso),
                      icon: const Icon(Icons.add),
                      label: const Text('Ingreso'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      // El Administrador puede quitarle este permiso al Cajero.
                      onPressed: SesionActual.instancia.permisos.cajeroRegistraEgresos
                          ? () => _registrar(context, MovimientoTipo.egreso)
                          : null,
                      icon: const Icon(Icons.remove),
                      label: const Text('Egreso'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _iniciarCierre(context),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Cerrar caja'),
                ),
              ),
            ] else
              _CierrePanel(caja: caja, resumen: resumen),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Movimientos',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (movimientos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Todavía no hay movimientos en esta caja.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final m in movimientos) _MovimientoTile(movimiento: m),
          ],
        );
      },
    );
  }
}

class _MovimientoTile extends StatelessWidget {
  final MovimientoCajaModel movimiento;

  const _MovimientoTile({required this.movimiento});

  @override
  Widget build(BuildContext context) {
    final esEgreso = movimiento.tipo == MovimientoTipo.egreso;
    final color = esEgreso ? Theme.of(context).colorScheme.error : context.semanticColors.success;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(esEgreso ? Icons.arrow_upward : Icons.arrow_downward, color: color),
      title: Text(
        movimiento.concepto,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${movimiento.tipo} · ${movimiento.metodoPago}'
        '${movimiento.fecha == null ? '' : ' · ${_hora(movimiento.fecha)}'}',
      ),
      trailing: Text(
        '${esEgreso ? '−' : '+'} ${_bs(movimiento.monto)}',
        style: TextStyle(fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

// -------------------------------------------------------------------- cierre

/// Paso 2 del cierre ciego: ya se registró el conteo, ahora se ve el
/// efectivo esperado y la diferencia, y se cierra la caja.
class _CierrePanel extends StatefulWidget {
  final CajaModel caja;
  final ResumenCaja resumen;

  const _CierrePanel({required this.caja, required this.resumen});

  @override
  State<_CierrePanel> createState() => _CierrePanelState();
}

class _CierrePanelState extends State<_CierrePanel> {
  final _obsCtrl = TextEditingController();
  bool _cerrando = false;

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _cerrar() async {
    // Acción sensible: se vuelve a pedir la contraseña (y el código).
    if (!await confirmarIdentidad(context, accion: 'cerrar tu caja') || !mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _cerrando = true);
    try {
      final cerrada = await CajaService.instancia
          .cerrarCaja(widget.caja, observacion: _obsCtrl.text);
      ActividadService.instancia.registrar(
        ActividadTipo.caja,
        'Cerró su caja. Diferencia: ${_bs(cerrada.diferencia ?? 0)}',
      );
      // Al cerrar, esta pantalla vuelve a "sin caja" y este panel se
      // destruye, así que el resultado se muestra desde el Navigator.
      // El Navigator sigue vivo aunque este panel ya no lo esté.
      await showDialog<void>(
        // ignore: use_build_context_synchronously
        context: navigator.context,
        builder: (_) => _ResultadoCierreDialog(caja: cerrada),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_mensaje(e))));
      if (mounted) setState(() => _cerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contado = widget.caja.montoContado ?? 0;
    final esperado = widget.resumen.esperado;
    final diferencia = redondearDinero(contado - esperado);
    final estado = _estadoDiferencia(diferencia);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resultado del conteo',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.sm),
            _Fila('Efectivo esperado', _bs(esperado)),
            _Fila('Efectivo contado', _bs(contado)),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: AppStatusBadge(label: estado.texto, tone: estado.tono),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _obsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: diferencia == 0
                    ? 'Observación (opcional)'
                    : 'Observación (obligatoria: hay diferencia)',
                hintText: 'Ej. di mal el cambio en un cobro',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _cerrando ? null : _cerrar,
                icon: const Icon(Icons.lock),
                label: Text(_cerrando ? 'Cerrando...' : 'Cerrar caja'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumen de una caja ya cerrada (al cerrar, y al tocar un cierre del
/// historial).
class _ResultadoCierreDialog extends StatelessWidget {
  final CajaModel caja;

  const _ResultadoCierreDialog({required this.caja});

  @override
  Widget build(BuildContext context) {
    final diferencia = caja.diferencia ?? 0;
    final estado = _estadoDiferencia(diferencia);
    return AlertDialog(
      title: const Text('Caja cerrada'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_fechaHora(caja.fechaApertura)} → ${_fechaHora(caja.fechaCierre)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _Fila('Monto inicial', _bs(caja.montoInicial)),
            _Fila('Cobros en efectivo', _bs(caja.totalEfectivo ?? 0)),
            _Fila('Ingresos', _bs(caja.totalIngresos ?? 0)),
            _Fila('Egresos', _bs(caja.totalEgresos ?? 0)),
            _Fila('Transferencia', _bs(caja.totalTransferencia ?? 0)),
            _Fila('QR', _bs(caja.totalQr ?? 0)),
            const Divider(),
            _Fila('Efectivo esperado', _bs(caja.montoEsperado ?? 0), destacada: true),
            _Fila('Efectivo contado', _bs(caja.montoContado ?? 0), destacada: true),
            const SizedBox(height: AppSpacing.xs),
            AppStatusBadge(label: estado.texto, tone: estado.tono),
            if (caja.observacionCierre.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Observación: ${caja.observacionCierre}'),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- historial

class _Historial extends StatelessWidget {
  final String idCajero;

  const _Historial({required this.idCajero});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cierres anteriores',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.xs),
        StreamBuilder<List<CajaModel>>(
          stream: CajaService.instancia.streamHistorial(idCajero),
          builder: (context, snapshot) {
            final cajas = (snapshot.data ?? const <CajaModel>[]).take(20).toList();
            if (cajas.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Todavía no tienes cierres anteriores.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final c in cajas)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _fechaHora(c.fechaCierre),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Esperado ${_bs(c.montoEsperado ?? 0)} · '
                      'Contado ${_bs(c.montoContado ?? 0)}',
                    ),
                    trailing: Builder(builder: (context) {
                      final e = _estadoDiferencia(c.diferencia ?? 0);
                      return AppStatusBadge(label: e.texto, tone: e.tono);
                    }),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => _ResultadoCierreDialog(caja: c),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ diálogos

/// Pide un monto en Bs (apertura de caja y conteo del cierre).
class _MontoDialog extends StatefulWidget {
  final String titulo;
  final String etiqueta;
  final String? ayuda;
  final String confirmar;
  final bool permiteCero;

  const _MontoDialog({
    required this.titulo,
    required this.etiqueta,
    this.ayuda,
    required this.confirmar,
    this.permiteCero = false,
  });

  @override
  State<_MontoDialog> createState() => _MontoDialogState();
}

class _MontoDialogState extends State<_MontoDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _aceptar() {
    final v = double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || (!widget.permiteCero && v == 0)) {
      setState(() => _error = 'Escribe un monto válido.');
      return;
    }
    Navigator.of(context).pop(redondearDinero(v));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.ayuda != null) ...[
            Text(widget.ayuda!),
            const SizedBox(height: AppSpacing.md),
          ],
          TextField(
            controller: _ctrl,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.etiqueta,
              prefixText: 'Bs ',
              errorText: _error,
            ),
            onSubmitted: (_) => _aceptar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: Text(widget.confirmar)),
      ],
    );
  }
}

class _DatosMovimiento {
  final String concepto;
  final double monto;

  const _DatosMovimiento(this.concepto, this.monto);
}

/// Pide concepto y monto de un ingreso o egreso manual.
class _MovimientoDialog extends StatefulWidget {
  final String tipo;

  const _MovimientoDialog({required this.tipo});

  @override
  State<_MovimientoDialog> createState() => _MovimientoDialogState();
}

class _MovimientoDialogState extends State<_MovimientoDialog> {
  final _conceptoCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  String? _errorConcepto;
  String? _errorMonto;

  @override
  void dispose() {
    _conceptoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  void _aceptar() {
    final concepto = _conceptoCtrl.text.trim();
    final monto = double.tryParse(_montoCtrl.text.trim().replaceAll(',', '.'));
    setState(() {
      _errorConcepto = concepto.isEmpty ? 'Escribe el concepto.' : null;
      _errorMonto = (monto == null || monto <= 0) ? 'Escribe un monto mayor a 0.' : null;
    });
    if (_errorConcepto != null || _errorMonto != null) return;
    Navigator.of(context).pop(_DatosMovimiento(concepto, redondearDinero(monto!)));
  }

  @override
  Widget build(BuildContext context) {
    final esEgreso = widget.tipo == MovimientoTipo.egreso;
    return AlertDialog(
      title: Text(esEgreso ? 'Registrar egreso' : 'Registrar ingreso'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            esEgreso
                ? 'Efectivo que sale del cajón (por ejemplo, comprar gas).'
                : 'Efectivo que se agrega al cajón (por ejemplo, más cambio).',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _conceptoCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Concepto', errorText: _errorConcepto),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: 'Bs ',
              errorText: _errorMonto,
            ),
            onSubmitted: (_) => _aceptar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Registrar')),
      ],
    );
  }
}
