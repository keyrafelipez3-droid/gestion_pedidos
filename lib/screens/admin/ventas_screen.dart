import 'package:flutter/material.dart';

import '../../models/caja_models.dart' show redondearDinero;
import '../../models/pedido_models.dart';
import '../../models/sucursal_model.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/reporte_excel.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../cliente/pedido_detalle_screen.dart';

enum _Periodo { hoy, sieteDias, mes, personalizado }

/// HU-42: el Administrador consulta el historial de ventas de su negocio.
///
/// Una venta es un pedido en estado Entregado (los cancelados no cuentan).
/// El periodo se filtra en Firestore; sucursal, modalidad y método de pago
/// se filtran en pantalla sobre ese resultado. La fecha que se muestra es
/// la del pedido.
class VentasScreen extends StatefulWidget {
  final bool incrustada;

  const VentasScreen({super.key, this.incrustada = false});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  _Periodo _periodo = _Periodo.hoy;
  DateTimeRange? _rangoPersonalizado;
  String? _idSucursal;
  String? _modalidad;
  String? _metodo;

  late Stream<List<PedidoModel>> _ventas;

  String get _idNegocio => SesionActual.instancia.idNegocio ?? '';

  @override
  void initState() {
    super.initState();
    _ventas = _crearStream();
  }

  /// Límites del periodo elegido: desde (incluido) y hasta (excluido).
  ({DateTime desde, DateTime hasta}) _limites() {
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    switch (_periodo) {
      case _Periodo.hoy:
        return (desde: hoy, hasta: hoy.add(const Duration(days: 1)));
      case _Periodo.sieteDias:
        return (
          desde: hoy.subtract(const Duration(days: 6)),
          hasta: hoy.add(const Duration(days: 1)),
        );
      case _Periodo.mes:
        return (
          desde: DateTime(ahora.year, ahora.month, 1),
          hasta: DateTime(ahora.year, ahora.month + 1, 1),
        );
      case _Periodo.personalizado:
        final r = _rangoPersonalizado ?? DateTimeRange(start: hoy, end: hoy);
        return (
          desde: DateTime(r.start.year, r.start.month, r.start.day),
          hasta: DateTime(r.end.year, r.end.month, r.end.day).add(const Duration(days: 1)),
        );
    }
  }

  Stream<List<PedidoModel>> _crearStream() {
    final l = _limites();
    return PedidoService.instancia.streamVentas(
      idNegocio: _idNegocio,
      desde: l.desde,
      hasta: l.hasta,
    );
  }

  Future<void> _elegirPeriodo(_Periodo p) async {
    if (p == _Periodo.personalizado) {
      final ahora = DateTime.now();
      final hoy = DateTime(ahora.year, ahora.month, ahora.day);
      final rango = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2024),
        lastDate: hoy,
        initialDateRange: _rangoPersonalizado ??
            DateTimeRange(start: hoy.subtract(const Duration(days: 6)), end: hoy),
      );
      if (rango == null || !mounted) return;
      setState(() {
        _periodo = p;
        _rangoPersonalizado = rango;
        _ventas = _crearStream();
      });
      return;
    }
    setState(() {
      _periodo = p;
      _ventas = _crearStream();
    });
  }

  String _etiquetaPersonalizado() {
    final r = _rangoPersonalizado;
    if (_periodo != _Periodo.personalizado || r == null) return 'Fechas...';
    return '${_fecha(r.start)} - ${_fecha(r.end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Ventas'),
      ),
      body: _idNegocio.isEmpty
          ? const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'No se pudo identificar el negocio',
            )
          : AppContenidoCentrado(
              maxWidth: 900,
              child: StreamBuilder<List<SucursalModel>>(
                stream: SucursalService.instancia.streamSucursales(_idNegocio),
                builder: (context, snapSucursales) {
                  final sucursales = snapSucursales.data ?? const <SucursalModel>[];
                  final nombres = {for (final s in sucursales) s.id: s.nombre};
                  return StreamBuilder<List<PedidoModel>>(
                    stream: _ventas,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            'No se pudieron cargar las ventas. Si es la primera vez, '
                            'Firestore puede pedir crear un índice (el enlace aparece '
                            'en la consola).\n\n${snapshot.error}',
                          ),
                        );
                      }
                      if (!snapshot.hasData) return const AppCargando();
                      return _contenido(context, snapshot.data!, sucursales, nombres);
                    },
                  );
                },
              ),
            ),
    );
  }

  Widget _contenido(
    BuildContext context,
    List<PedidoModel> ventas,
    List<SucursalModel> sucursales,
    Map<String, String> nombres,
  ) {
    final theme = Theme.of(context);
    final filtradas = ventas
        .where((p) =>
            (_idSucursal == null || p.idSucursal == _idSucursal) &&
            (_modalidad == null || p.modalidad == _modalidad) &&
            (_metodo == null || p.metodoPago == _metodo))
        .toList();
    final total = redondearDinero(filtradas.fold<double>(0, (acc, p) => acc + p.montoNegocio));
    final promedio = filtradas.isEmpty ? 0.0 : redondearDinero(total / filtradas.length);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: const Text('Hoy'),
              selected: _periodo == _Periodo.hoy,
              onSelected: (_) => _elegirPeriodo(_Periodo.hoy),
            ),
            ChoiceChip(
              label: const Text('Últimos 7 días'),
              selected: _periodo == _Periodo.sieteDias,
              onSelected: (_) => _elegirPeriodo(_Periodo.sieteDias),
            ),
            ChoiceChip(
              label: const Text('Este mes'),
              selected: _periodo == _Periodo.mes,
              onSelected: (_) => _elegirPeriodo(_Periodo.mes),
            ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range, size: 18),
              label: Text(_etiquetaPersonalizado()),
              selected: _periodo == _Periodo.personalizado,
              onSelected: (_) => _elegirPeriodo(_Periodo.personalizado),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _FiltroDropdown(
              etiqueta: 'Sucursal',
              valor: _idSucursal,
              opciones: {for (final s in sucursales) s.id: s.nombre},
              onChanged: (v) => setState(() => _idSucursal = v),
            ),
            _FiltroDropdown(
              etiqueta: 'Modalidad',
              valor: _modalidad,
              opciones: {for (final m in PedidoModalidad.todas) m: m},
              onChanged: (v) => setState(() => _modalidad = v),
            ),
            _FiltroDropdown(
              etiqueta: 'Método de pago',
              valor: _metodo,
              opciones: {for (final m in MetodoPago.todos) m: m},
              onChanged: (v) => setState(() => _metodo = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                _Metrica(etiqueta: 'Ventas', valor: '${filtradas.length}'),
                _Metrica(etiqueta: 'Total', valor: _bs(total)),
                _Metrica(etiqueta: 'Ticket promedio', valor: _bs(promedio)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: filtradas.isEmpty
                ? null
                : () {
                    final l = _limites();
                    String f(DateTime d) =>
                        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                    String d(DateTime x) =>
                        '${x.day.toString().padLeft(2, '0')}/${x.month.toString().padLeft(2, '0')}/${x.year}';
                    final hasta = l.hasta.subtract(const Duration(days: 1));
                    exportarExcel(
                      context,
                      nombreArchivo: 'ventas_${f(l.desde)}_a_${f(hasta)}.xlsx',
                      pedidos: filtradas,
                      nombresSucursal: nombres,
                      periodo: 'Del ${d(l.desde)} al ${d(hasta)}',
                    );
                  },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Exportar a Excel'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (filtradas.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: AppEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No hay ventas en este periodo',
              message: 'Cambia el periodo o los filtros para ver otras ventas.',
            ),
          )
        else
          for (final p in filtradas)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${p.etiquetaModalidad} · #${p.id.substring(0, 6)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${_fechaHora(p.fechaCreacion)} · ${p.metodoPago} · '
                '${nombres[p.idSucursal] ?? 'Sucursal'}',
              ),
              trailing: Text(
                _bs(p.montoNegocio),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PedidoDetalleScreen(idPedido: p.id, esPersonal: true),
                ),
              ),
            ),
      ],
    );
  }
}

String _bs(double v) => 'Bs ${v.toStringAsFixed(2)}';

String _dos(int n) => n.toString().padLeft(2, '0');

String _fecha(DateTime d) => '${_dos(d.day)}/${_dos(d.month)}/${d.year}';

String _fechaHora(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${_fecha(l)} ${_dos(l.hour)}:${_dos(l.minute)}';
}

class _Metrica extends StatelessWidget {
  final String etiqueta;
  final String valor;

  const _Metrica({required this.etiqueta, required this.valor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Selector de filtro con la opción "Todas" (valor null).
class _FiltroDropdown extends StatelessWidget {
  final String etiqueta;
  final String? valor;
  final Map<String, String> opciones; // valor -> texto
  final ValueChanged<String?> onChanged;

  const _FiltroDropdown({
    required this.etiqueta,
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Si la sucursal elegida ya no existe en la lista, se vuelve a "Todas".
    final actual = opciones.containsKey(valor) ? valor : null;
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<String?>(
        initialValue: actual,
        isExpanded: true,
        decoration: InputDecoration(labelText: etiqueta),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
          for (final e in opciones.entries)
            DropdownMenuItem<String?>(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
