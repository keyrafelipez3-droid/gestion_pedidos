import 'package:flutter/material.dart';

import '../../models/carrito_models.dart';
import '../../models/catalogo_models.dart';
import '../../models/negocio_model.dart';
import '../../models/sucursal_model.dart';
import '../../services/carrito_service.dart';
import '../../services/catalogo_service.dart';
import '../../services/favoritos_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_contenido_centrado.dart';
import '../../widgets/app_fotos_comida.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/app_search_field.dart';
import '../legal/info_negocio_screen.dart';
import 'carrito_screen.dart';

/// HU-16/17/18/19/20/21: menú digital de un negocio — ver, buscar,
/// filtrar por categoría, marcar favoritos y agregar al carrito.
class ClienteMenuScreen extends StatefulWidget {
  final NegocioModel negocio;

  /// Foto de respaldo para la cabecera cuando el negocio no tiene banner
  /// (la misma que se vio en su tarjeta). Si no llega, se elige una según
  /// el id del negocio.
  final String? fotoRespaldo;

  const ClienteMenuScreen({super.key, required this.negocio, this.fotoRespaldo});

  @override
  State<ClienteMenuScreen> createState() => _ClienteMenuScreenState();
}

class _ClienteMenuScreenState extends State<ClienteMenuScreen> {
  final _buscadorCtrl = TextEditingController();
  String _busqueda = '';
  String? _idCategoriaSeleccionada; // null = "Todas"
  String? _idSucursal;

  String get _uid => SesionActual.instancia.actual!.idUsuario;
  String get _idNegocio => widget.negocio.idNegocio;

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.negocio.nombre),
        actions: [
          IconButton(
            tooltip: 'Información del negocio',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => InfoNegocioScreen(negocio: widget.negocio),
              ),
            ),
          ),
        ],
      ),
      body: AppContenidoCentrado(
        maxWidth: 860,
        child: Column(
        children: [
          _CabeceraNegocio(
            negocio: widget.negocio,
            fotoRespaldo:
                widget.fotoRespaldo ?? fotoComidaPara(widget.negocio.idNegocio),
          ),
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
          _SelectorSucursalCompacto(
            idNegocio: _idNegocio,
            seleccionado: _idSucursal,
            onChanged: (id) => setState(() => _idSucursal = id),
          ),
          _FiltroCategorias(
            idNegocio: _idNegocio,
            seleccionada: _idCategoriaSeleccionada,
            onChanged: (id) => setState(() => _idCategoriaSeleccionada = id),
          ),
          Expanded(
            child: StreamBuilder<List<ProductoModel>>(
              stream: CatalogoService.instancia.streamProductos(_idNegocio),
              builder: (context, snapProductos) {
                if (!snapProductos.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var productos = snapProductos.data!
                    .where((p) => p.estado && p.disponible)
                    .toList();
                if (_idCategoriaSeleccionada != null) {
                  productos = productos
                      .where((p) => p.idCategoria == _idCategoriaSeleccionada)
                      .toList();
                }
                if (_busqueda.isNotEmpty) {
                  productos = productos
                      .where((p) => p.nombre.toLowerCase().contains(_busqueda))
                      .toList();
                }
                if (productos.isEmpty) {
                  return const AppEmptyState(
                    icon: Icons.restaurant_menu_outlined,
                    title: 'No encontramos productos',
                    message: 'Prueba con otra búsqueda o categoría.',
                  );
                }
                return StreamBuilder<Set<String>>(
                  stream: FavoritosService.instancia.streamIdsFavoritos(_uid),
                  builder: (context, snapFavoritos) {
                    final favoritos = snapFavoritos.data ?? {};
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        96, // deja espacio para la barra flotante del carrito
                      ),
                      itemCount: productos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _TarjetaProducto(
                        producto: productos[i],
                        esFavorito: favoritos.contains(productos[i].id),
                        onFavorito: () => FavoritosService.instancia.alternarFavorito(
                          uid: _uid,
                          idProducto: productos[i].id,
                          idNegocio: _idNegocio,
                          esFavoritoActual: favoritos.contains(productos[i].id),
                        ),
                        onAgregar: () => CarritoService.instancia.agregarAlCarrito(
                          _uid,
                          CarritoItemModel(
                            id: '',
                            idProducto: productos[i].id,
                            nombreProducto: productos[i].nombre,
                            imagenUrl: productos[i].imagenUrl,
                            precioUnitario: productos[i].precio,
                            idNegocio: _idNegocio,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      )),
      bottomSheet: _BarraCarrito(
        idNegocio: _idNegocio,
        uid: _uid,
        idSucursal: _idSucursal,
        negocio: widget.negocio,
      ),
    );
  }
}

class _SelectorSucursalCompacto extends StatelessWidget {
  final String idNegocio;
  final String? seleccionado;
  final ValueChanged<String?> onChanged;

  const _SelectorSucursalCompacto({
    required this.idNegocio,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SucursalModel>>(
      stream: SucursalService.instancia.streamSucursales(idNegocio),
      builder: (context, snapshot) {
        final sucursales = (snapshot.data ?? []).where((s) => s.estado).toList();
        if (sucursales.isEmpty) return const SizedBox.shrink();
        // Preselecciona la primera sucursal automáticamente si todavía
        // no hay ninguna elegida (caso más común: un solo local).
        if (seleccionado == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(sucursales.first.id));
        }
        if (sucursales.length == 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(sucursales.first.nombre, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
          child: DropdownButton<String>(
            isExpanded: true,
            value: seleccionado,
            hint: const Text('Elige una sucursal'),
            items: sucursales
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)))
                .toList(),
            onChanged: onChanged,
          ),
        );
      },
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

class _CabeceraNegocio extends StatelessWidget {
  final NegocioModel negocio;
  final String fotoRespaldo;

  const _CabeceraNegocio({required this.negocio, required this.fotoRespaldo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 0),
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: SizedBox(
          height: 120,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImagenRed(
                url: negocio.bannerUrl,
                icono: Icons.storefront_outlined,
                respaldoAsset: fotoRespaldo,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.md,
                right: AppSpacing.md,
                bottom: AppSpacing.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      negocio.nombre,
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    if (negocio.descripcion.isNotEmpty)
                      Text(
                        negocio.descripcion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de producto: texto a la izquierda y foto a la derecha con el
/// botón "+" flotando sobre la imagen y el corazón de favoritos arriba.
class _TarjetaProducto extends StatelessWidget {
  final ProductoModel producto;
  final bool esFavorito;
  final VoidCallback onFavorito;
  final VoidCallback onAgregar;

  const _TarjetaProducto({
    required this.producto,
    required this.esFavorito,
    required this.onFavorito,
    required this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bs ${producto.precio.toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (producto.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      producto.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: AppRadius.mdAll,
                    child: AppImagenRed(url: producto.imagenUrl),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onFavorito,
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          esFavorito ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: esFavorito ? theme.colorScheme.primary : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onAgregar,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.add, size: 22, color: Colors.black87),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraCarrito extends StatelessWidget {
  final String idNegocio;
  final String uid;
  final String? idSucursal;
  final NegocioModel negocio;

  const _BarraCarrito({
    required this.idNegocio,
    required this.uid,
    required this.idSucursal,
    required this.negocio,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CarritoItemModel>>(
      stream: CarritoService.instancia.streamCarrito(uid, idNegocio),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        final cantidad = items.fold<int>(0, (acc, i) => acc + i.cantidad);
        final total = CarritoService.instancia.calcularTotal(items);
        final scheme = Theme.of(context).colorScheme;
        return SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              onPressed: idSucursal == null
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CarritoScreen(
                            negocio: negocio,
                            idSucursal: idSucursal!,
                          ),
                        ),
                      ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_cart_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Ver carrito ($cantidad)'),
                    ],
                  ),
                  Text(
                    'Bs ${total.toStringAsFixed(2)}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onPrimary),
                  ),
                ],
              ),
            ),
          ),
            ),
          ),
        );
      },
    );
  }
}
