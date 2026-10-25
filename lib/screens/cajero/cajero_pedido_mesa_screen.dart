import 'package:flutter/material.dart';

import '../../models/carrito_models.dart';
import '../../models/catalogo_models.dart';
import '../../models/mesa_model.dart';
import '../../services/catalogo_service.dart';
import '../../services/pedido_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/alergias.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/app_search_field.dart';

/// HU-29 / HU-32: el Cajero registra un pedido para una mesa que ya
/// asignó a un grupo de clientes. Elige los productos del menú del negocio
/// (con cantidades) y lo envía: el pedido queda "Pendiente" para Cocina y
/// forma parte de la cuenta abierta de esa mesa.
class CajeroPedidoMesaScreen extends StatefulWidget {
  final MesaModel mesa;
  final String idSucursal;

  const CajeroPedidoMesaScreen({super.key, required this.mesa, required this.idSucursal});

  @override
  State<CajeroPedidoMesaScreen> createState() => _CajeroPedidoMesaScreenState();
}

class _CajeroPedidoMesaScreenState extends State<CajeroPedidoMesaScreen> {
  final _buscadorCtrl = TextEditingController();
  String _busqueda = '';
  String? _idCategoria; // null = "Todas"

  /// idProducto -> cantidad pedida. Vive solo en memoria hasta enviar.
  final Map<String, int> _cantidades = {};

  /// Últimos productos que llegaron del stream, para armar las líneas del
  /// pedido (nombre y precio) sin volver a consultar.
  Map<String, ProductoModel> _catalogo = {};

  bool _enviando = false;

  String get _idNegocio => SesionActual.instancia.idNegocio ?? '';

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  int get _totalProductos => _cantidades.values.fold(0, (a, b) => a + b);

  double get _total => _cantidades.entries.fold<double>(0, (acc, e) {
        final p = _catalogo[e.key];
        return p == null ? acc : acc + p.precioVigente() * e.value;
      });

  void _cambiar(String idProducto, int delta) {
    setState(() {
      final nueva = (_cantidades[idProducto] ?? 0) + delta;
      if (nueva <= 0) {
        _cantidades.remove(idProducto);
      } else {
        _cantidades[idProducto] = nueva;
      }
    });
  }

  Future<void> _enviar() async {
    final usuario = SesionActual.instancia.actual;
    if (usuario == null || _idNegocio.isEmpty || _cantidades.isEmpty) return;

    final items = <CarritoItemModel>[
      for (final e in _cantidades.entries)
        if (_catalogo[e.key] != null)
          CarritoItemModel(
            id: '',
            idProducto: e.key,
            nombreProducto: _catalogo[e.key]!.nombreParaPedido(_catalogo.values),
            imagenUrl: _catalogo[e.key]!.imagenUrl,
            precioUnitario: _catalogo[e.key]!.precioVigente(),
            cantidad: e.value,
            idNegocio: _idNegocio,
          ),
    ];
    if (items.isEmpty) return;

    final notasCtrl = TextEditingController();
    var alergias = <String>[];
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialog) => AlertDialog(
        title: Text('Enviar pedido · Mesa ${widget.mesa.numero}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${i.cantidad}x ${i.nombreProducto}'),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Total: Bs ${_total.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: notasCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Nota para cocina (opcional)',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                '¿Alguien de la mesa tiene alergias?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: 420,
                child: SelectorAlergias(
                  seleccionadas: alergias,
                  onChanged: (v) => setDialog(() => alergias = v),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enviar a cocina'),
          ),
        ],
      )),
    );
    if (confirmar != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _enviando = true);
    try {
      await PedidoService.instancia.registrarPedidoMesa(
        idCajero: usuario.idUsuario,
        idNegocio: _idNegocio,
        idSucursal: widget.idSucursal,
        mesa: widget.mesa,
        items: items,
        notas: notasCtrl.text.trim(),
        alergias: alergias,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Pedido de la mesa ${widget.mesa.numero} enviado a cocina.')),
      );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      messenger.showSnackBar(SnackBar(content: Text('No se pudo enviar el pedido: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Pedido · Mesa ${widget.mesa.numero}')),
      body: AppContenidoCentrado(
        maxWidth: 860,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: AppSearchField(
                controller: _buscadorCtrl,
                hint: 'Buscar en el menú...',
                onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
              ),
            ),
            _FiltroCategorias(
              idNegocio: _idNegocio,
              seleccionada: _idCategoria,
              onChanged: (id) => setState(() => _idCategoria = id),
            ),
            Expanded(
              child: StreamBuilder<List<ProductoModel>>(
                stream: CatalogoService.instancia.streamProductos(_idNegocio),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  _catalogo = {for (final p in snapshot.data!) p.id: p};
                  var productos =
                      snapshot.data!.where((p) => p.estado && p.disponible && p.comboDisponible(snapshot.data!)).toList();
                  if (_idCategoria != null) {
                    productos = productos.where((p) => p.idCategoria == _idCategoria).toList();
                  }
                  if (_busqueda.isNotEmpty) {
                    productos =
                        productos.where((p) => p.nombre.toLowerCase().contains(_busqueda)).toList();
                  }
                  if (productos.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.restaurant_menu_outlined,
                      title: 'No encontramos productos',
                      message: 'Prueba con otra búsqueda o categoría.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: productos.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = productos[i];
                      final cantidad = _cantidades[p.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: AppRadius.smAll,
                              child: AppImagenRed(url: p.imagenUrl, width: 56, height: 56),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.nombre,
                                    style: theme.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    p.promoActiva()
                                        ? 'Bs ${p.precioVigente().toStringAsFixed(2)} (promo, antes Bs ${p.precio.toStringAsFixed(2)})'
                                        : 'Bs ${p.precio.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            if (cantidad > 0) ...[
                              IconButton(
                                tooltip: 'Quitar uno',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _cambiar(p.id, -1),
                              ),
                              Text(
                                '$cantidad',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ],
                            IconButton(
                              tooltip: 'Agregar uno',
                              icon: Icon(
                                Icons.add_circle,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () => _cambiar(p.id, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (_totalProductos == 0 || _enviando) ? null : _enviar,
                icon: _enviando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _totalProductos == 0
                      ? 'Agrega productos al pedido'
                      : 'Enviar a cocina · $_totalProductos prod. · Bs ${_total.toStringAsFixed(2)}',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FiltroCategorias extends StatelessWidget {
  final String idNegocio;
  final String? seleccionada;
  final ValueChanged<String?> onChanged;

  const _FiltroCategorias({
    required this.idNegocio,
    required this.seleccionada,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoriaModel>>(
      stream: CatalogoService.instancia.streamCategorias(idNegocio),
      builder: (context, snapshot) {
        final categorias = (snapshot.data ?? []).where((c) => c.estado).toList();
        if (categorias.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: const Text('Todas'),
                  selected: seleccionada == null,
                  onSelected: (_) => onChanged(null),
                ),
              ),
              for (final c in categorias)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: ChoiceChip(
                    label: Text(c.nombre),
                    selected: seleccionada == c.id,
                    onSelected: (_) => onChanged(c.id),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
