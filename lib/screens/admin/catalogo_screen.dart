// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../models/catalogo_models.dart';
import '../../services/catalogo_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/alergias.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/app_status_badge.dart';
import '../../services/sesion_actual.dart';
import '../../widgets/selector_imagen.dart';
import '../../widgets/app_cargando.dart';

class CatalogoScreen extends StatefulWidget {
  /// Pestaña con la que se abre la pantalla (0=Categorías, 1=Productos,
  /// 2=Complementos/Extras, 3=Variantes). Se usa para que el sidebar del
  /// panel de administración pueda llevar directo a la sección elegida
  /// (ver AdminHomeScreen) sin cambiar en nada la lógica de cada pestaña.
  final int indiceInicial;

  /// true cuando la pantalla vive incrustada dentro del panel de
  /// administración (escritorio, con el sidebar siempre visible) en vez de
  /// abrirse en pantalla completa — así no muestra una flecha de "atrás"
  /// que cerraría todo el panel en vez de solo esta sección.
  final bool incrustada;

  const CatalogoScreen({super.key, this.indiceInicial = 0, this.incrustada = false});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.indiceInicial.clamp(0, 3),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Catálogo'),
        bottom: TabBar(
          controller: _controller,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Categorías'),
            Tab(text: 'Productos'),
            Tab(text: 'Extras'),
            Tab(text: 'Variantes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: const [
          _CategoriasTab(),
          _ProductosTab(),
          _ComplementosTab(),
          _VariantesTab(),
        ],
      ),
    );
  }
}

class _CategoriasTab extends StatelessWidget {
  const _CategoriasTab();

  Future<void> _editar(BuildContext context, {CategoriaModel? item}) async {
    final nombre = TextEditingController(text: item?.nombre ?? '');
    final descripcion = TextEditingController(text: item?.descripcion ?? '');
    final imagen = TextEditingController(text: item?.imagenUrl ?? '');
    final key = GlobalKey<FormState>();
    final idEfectivo = item?.id ?? CatalogoService.instancia.nuevaIdCategoria();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Nueva categoría' : 'Editar categoría'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: descripcion,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectorImagen(
                  etiqueta: 'Imagen de la categoría (opcional)',
                  controller: imagen,
                  rutaStorage:
                      'negocios/${SesionActual.instancia.idNegocio}/categorias/$idEfectivo',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              try {
                await CatalogoService.instancia.guardarCategoria(
                  CategoriaModel(
                    id: idEfectivo,
                    nombre: nombre.text.trim(),
                    descripcion: descripcion.text.trim(),
                    imagenUrl: imagen.text.trim(),
                    estado: item?.estado ?? true,
                    idNegocio: SesionActual.instancia.idNegocio,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombre.dispose();
      descripcion.dispose();
      imagen.dispose();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StreamBuilder<List<CategoriaModel>>(
          stream: CatalogoService.instancia.streamCategorias(SesionActual.instancia.idNegocio!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCargando();
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return AppEmptyState(
                icon: Icons.category_outlined,
                title: 'No hay categorías todavía',
                message: 'Crea la primera categoría para empezar a organizar el menú.',
                actionLabel: 'Nueva categoría',
                onAction: () => _editar(context),
              );
            }
            // El conteo de productos por categoría sale de streamProductos(),
            // que ya existe — no se inventa ningún número.
            return StreamBuilder<List<ProductoModel>>(
              stream: CatalogoService.instancia.streamProductos(SesionActual.instancia.idNegocio!),
              builder: (context, productosSnapshot) {
                final productos = productosSnapshot.data ?? [];
                final conteo = <String, int>{};
                for (final p in productos) {
                  conteo[p.idCategoria] = (conteo[p.idCategoria] ?? 0) + 1;
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final cantidad = conteo[item.id] ?? 0;
                    return Card(
                      child: ListTile(
                        leading: AvatarImagen(
                          url: item.imagenUrl,
                          icono: Icons.category_outlined,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        title: Text(item.nombre),
                        subtitle: Text(cantidad == 1 ? '1 producto' : '$cantidad productos'),
                        onTap: () => _editar(context, item: item),
                        trailing: Wrap(
                          spacing: AppSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AppStatusBadge(
                              label: item.estado ? 'Activa' : 'Inactiva',
                              tone: item.estado ? AppStatusTone.success : AppStatusTone.neutral,
                            ),
                            Switch(
                              value: item.estado,
                              onChanged: (v) =>
                                  CatalogoService.instancia.cambiarEstadoCategoria(item.id, v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editar(context),
          icon: const Icon(Icons.add),
          label: const Text('Nueva categoría'),
        ),
      );
}

enum _FiltroDisponibilidad { todos, disponibles, noDisponibles }

class _ProductosTab extends StatefulWidget {
  const _ProductosTab();

  @override
  State<_ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<_ProductosTab> {
  final _busqueda = TextEditingController();
  // Se guarda una sola vez el stream (no se crea de nuevo en cada build),
  // así escribir en el buscador no reinicia la lista ni pierde el foco.
  late final _streamProductos = CatalogoService.instancia.streamProductos(SesionActual.instancia.idNegocio!);
  String _filtroTexto = '';
  _FiltroDisponibilidad _filtro = _FiltroDisponibilidad.todos;

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _editar(BuildContext context, {ProductoModel? item}) async {
    final categorias = await CatalogoService.instancia.streamCategorias(SesionActual.instancia.idNegocio!).first;
    final nombre = TextEditingController(text: item?.nombre ?? '');
    final descripcion = TextEditingController(text: item?.descripcion ?? '');
    final precio = TextEditingController(
      text: item == null ? '' : item.precio.toStringAsFixed(2),
    );
    final imagen = TextEditingController(text: item?.imagenUrl ?? '');
    final key = GlobalKey<FormState>();
    final idEfectivo = item?.id ?? CatalogoService.instancia.nuevaIdProducto();
    var idCategoria = item?.idCategoria ?? '';
    var estado = item?.estado ?? true;
    var disponible = item?.disponible ?? true;
    var alergenos = <String>[...?item?.alergenos];
    var controlarStock = item?.controlaStock ?? false;
    final stock = TextEditingController(text: item?.stock?.toString() ?? '');
    final stockMinimo = TextEditingController(text: (item?.stockMinimo ?? 5).toString());

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'Nuevo producto' : 'Editar producto'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Form(
                key: key,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nombre,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descripcion,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: precio,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Precio *',
                        prefixText: 'Bs ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                        if (parsed == null) return 'Precio no válido';
                        if (parsed < 0) return 'El precio no puede ser negativo';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: idCategoria.isEmpty ? null : idCategoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                      items: categorias
                          .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre)))
                          .toList(),
                      onChanged: (v) => setState(() => idCategoria = v ?? ''),
                    ),
                    const SizedBox(height: 12),
                    SelectorImagen(
                      etiqueta: 'Imagen del producto (opcional)',
                      controller: imagen,
                      rutaStorage:
                          'negocios/${SesionActual.instancia.idNegocio}/productos/$idEfectivo',
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¿Qué alérgenos contiene?',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Los clientes con esa alergia verán un aviso antes de pedirlo.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SelectorAlergias(
                      seleccionadas: alergenos,
                      onChanged: (v) => setState(() => alergenos = v),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Controlar stock'),
                      subtitle: const Text('Se descuenta cuando la cocina empieza a preparar. En 0 queda agotado.'),
                      value: controlarStock,
                      onChanged: (v) => setState(() => controlarStock = v),
                    ),
                    if (controlarStock)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: stock,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cantidad disponible *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (!controlarStock) return null;
                                final n = int.tryParse((v ?? '').trim());
                                return n == null || n < 0 ? 'Número entero (0 o más)' : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: stockMinimo,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Avisar con menos de',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (!controlarStock) return null;
                                final n = int.tryParse((v ?? '').trim());
                                return n == null || n < 0 ? 'Número entero' : null;
                              },
                            ),
                          ),
                        ],
                      ),
                    SwitchListTile(
                      title: const Text('Activo'),
                      value: estado,
                      onChanged: (v) => setState(() => estado = v),
                    ),
                    SwitchListTile(
                      title: const Text('Disponible para venta'),
                      value: disponible,
                      onChanged: (v) => setState(() => disponible = v),
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
                final valor = double.parse(precio.text.replaceAll(',', '.'));
                final cantidad = controlarStock ? int.parse(stock.text.trim()) : null;
                try {
                  await CatalogoService.instancia.guardarProducto(
                    ProductoModel(
                      id: idEfectivo,
                      nombre: nombre.text.trim(),
                      descripcion: descripcion.text.trim(),
                      precio: valor,
                      idCategoria: idCategoria,
                      imagenUrl: imagen.text.trim(),
                      estado: estado,
                      // Si se repone stock, vuelve a estar disponible.
                      disponible: cantidad == null
                          ? disponible
                          : cantidad == 0
                              ? false
                              : ((item?.agotado ?? false) ? true : disponible),
                      idNegocio: SesionActual.instancia.idNegocio,
                      alergenos: alergenos,
                      stock: cantidad,
                      stockMinimo: int.tryParse(stockMinimo.text.trim()) ?? 5,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
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
      nombre.dispose();
      descripcion.dispose();
      precio.dispose();
      imagen.dispose();
      stock.dispose();
      stockMinimo.dispose();
    });
  }

  Future<void> _eliminar(BuildContext context, ProductoModel item) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar producto'),
            content: Text('¿Eliminar "${item.nombre}"? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await CatalogoService.instancia.eliminarProducto(item.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StreamBuilder<List<ProductoModel>>(
          stream: _streamProductos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCargando();
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            final todos = snapshot.data ?? [];
            if (todos.isEmpty) {
              return AppEmptyState(
                icon: Icons.fastfood_outlined,
                title: 'No hay productos todavía',
                message: 'Agrega tu primer producto para completar el menú.',
                actionLabel: 'Nuevo producto',
                onAction: () => _editar(context),
              );
            }

            final texto = _filtroTexto.trim().toLowerCase();
            final items = todos.where((p) {
              if (texto.isNotEmpty && !p.nombre.toLowerCase().contains(texto)) return false;
              return switch (_filtro) {
                _FiltroDisponibilidad.todos => true,
                _FiltroDisponibilidad.disponibles => p.disponible,
                _FiltroDisponibilidad.noDisponibles => !p.disponible,
              };
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
                  ),
                  child: AppSearchField(
                    controller: _busqueda,
                    hint: 'Buscar productos...',
                    onChanged: (v) => setState(() => _filtroTexto = v),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Row(
                    children: [
                      _ChipFiltro(
                        label: 'Todos',
                        seleccionado: _filtro == _FiltroDisponibilidad.todos,
                        onTap: () => setState(() => _filtro = _FiltroDisponibilidad.todos),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ChipFiltro(
                        label: 'Disponibles',
                        seleccionado: _filtro == _FiltroDisponibilidad.disponibles,
                        onTap: () => setState(() => _filtro = _FiltroDisponibilidad.disponibles),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _ChipFiltro(
                        label: 'No disponibles',
                        seleccionado: _filtro == _FiltroDisponibilidad.noDisponibles,
                        onTap: () =>
                            setState(() => _filtro = _FiltroDisponibilidad.noDisponibles),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: items.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.search_off,
                          title: 'Ningún producto coincide con el filtro',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final item = items[i];
                            return Card(
                              child: ListTile(
                                leading: AvatarImagen(
                                  url: item.imagenUrl,
                                  icono: item.disponible
                                      ? Icons.fastfood_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                title: Text(item.nombre),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(
                                    spacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text('Bs ${item.precio.toStringAsFixed(2)}'),
                                      AppStatusBadge(
                                        label:
                                            item.disponible ? 'Disponible' : 'No disponible',
                                        tone: item.disponible
                                            ? AppStatusTone.success
                                            : AppStatusTone.neutral,
                                      ),
                                      if (item.agotado)
                                        const AppStatusBadge(label: 'Agotado', tone: AppStatusTone.danger)
                                      else if (item.pocoStock)
                                        AppStatusBadge(label: 'Quedan ${item.stock}', tone: AppStatusTone.warning)
                                      else if (item.controlaStock)
                                        Text('Stock: ${item.stock}'),
                                      ContieneAlergenos(alergenos: item.alergenos),
                                    ],
                                  ),
                                ),
                                onTap: () => _editar(context, item: item),
                                trailing: Wrap(
                                  spacing: 0,
                                  children: [
                                    IconButton(
                                      tooltip: 'Eliminar',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _eliminar(context, item),
                                    ),
                                    Switch(
                                      value: item.disponible,
                                      onChanged: (v) => CatalogoService.instancia
                                          .cambiarDisponibilidadProducto(item.id, v),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _editar(context),
          icon: const Icon(Icons.add),
          label: const Text('Nuevo producto'),
        ),
      );
}

class _ChipFiltro extends StatelessWidget {
  final String label;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ChipFiltro({
    required this.label,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: seleccionado,
      onSelected: (_) => onTap(),
    );
  }
}

class _ComplementosTab extends StatelessWidget {
  const _ComplementosTab();

  Future<void> _editar(BuildContext context, {ComplementoModel? item}) async {
    final nombre = TextEditingController(text: item?.nombre ?? '');
    final descripcion = TextEditingController(text: item?.descripcion ?? '');
    final precio = TextEditingController(
      text: item == null ? '' : item.precio.toStringAsFixed(2),
    );
    final key = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item == null ? 'Nuevo extra' : 'Editar extra'),
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
                    labelText: 'Nombre *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descripcion,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: precio,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Precio adicional *',
                    prefixText: 'Bs ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (parsed == null) return 'Precio no válido';
                    if (parsed < 0) return 'El precio no puede ser negativo';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!key.currentState!.validate()) return;
              try {
                await CatalogoService.instancia.guardarComplemento(
                  ComplementoModel(
                    id: item?.id ?? '',
                    nombre: nombre.text.trim(),
                    descripcion: descripcion.text.trim(),
                    precio: double.parse(precio.text.replaceAll(',', '.')),
                    estado: item?.estado ?? true,
                    idNegocio: SesionActual.instancia.idNegocio,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombre.dispose();
      descripcion.dispose();
      precio.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ComplementoModel>>(
        stream: CatalogoService.instancia.streamComplementos(SesionActual.instancia.idNegocio!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppCargando();
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.add_circle_outline,
              title: 'No hay complementos todavía',
              message: 'Agrega extras que tus clientes puedan sumar a sus productos.',
              actionLabel: 'Nuevo extra',
              onAction: () => _editar(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = items[i];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.add_circle_outline)),
                  title: Text(item.nombre),
                  subtitle: Text(
                    'Bs ${item.precio.toStringAsFixed(2)} · '
                    '${item.descripcion.isEmpty ? 'Sin descripción' : item.descripcion}',
                  ),
                  onTap: () => _editar(context, item: item),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(
                        label: item.estado ? 'Activo' : 'Inactivo',
                        tone: item.estado ? AppStatusTone.success : AppStatusTone.neutral,
                      ),
                      Switch(
                        value: item.estado,
                        onChanged: (v) =>
                            CatalogoService.instancia.cambiarEstadoComplemento(item.id, v),
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
        label: const Text('Nuevo extra'),
      ),
    );
  }
}

class _VariantesTab extends StatelessWidget {
  const _VariantesTab();

  Future<void> _editar(BuildContext context, {VarianteModel? item}) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final productos = await CatalogoService.instancia.streamProductos(SesionActual.instancia.idNegocio!).first;
    if (!navigator.mounted) return;
    if (productos.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Primero crea al menos un producto.')),
      );
      return;
    }

    final nombre = TextEditingController(text: item?.nombre ?? '');
    final precio = TextEditingController(
      text: item == null ? '' : item.precioAdicional.toStringAsFixed(2),
    );
    final key = GlobalKey<FormState>();
    var idProducto = item?.idProducto.isNotEmpty == true ? item!.idProducto : productos.first.id;
    var estado = item?.estado ?? true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? 'Nueva variante' : 'Editar variante'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: idProducto,
                    decoration: const InputDecoration(
                      labelText: 'Producto',
                      border: OutlineInputBorder(),
                    ),
                    items: productos
                        .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
                        .toList(),
                    onChanged: (v) => setState(() => idProducto = v ?? idProducto),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nombre,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de variante *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio adicional *',
                      prefixText: 'Bs ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').replaceAll(',', '.'));
                      if (parsed == null) return 'Precio no válido';
                      if (parsed < 0) return 'El precio no puede ser negativo';
                      return null;
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Activa'),
                    value: estado,
                    onChanged: (v) => setState(() => estado = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                if (!key.currentState!.validate()) return;
                try {
                  await CatalogoService.instancia.guardarVariante(
                    VarianteModel(
                      id: item?.id ?? '',
                      idProducto: idProducto,
                      nombre: nombre.text.trim(),
                      precioAdicional: double.parse(precio.text.replaceAll(',', '.')),
                      estado: estado,
                      idNegocio: SesionActual.instancia.idNegocio,
                    ),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
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
      nombre.dispose();
      precio.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<VarianteModel>>(
        stream: CatalogoService.instancia.streamVariantes(SesionActual.instancia.idNegocio!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppCargando();
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final items = snapshot.data ?? [];

          return StreamBuilder<List<ProductoModel>>(
            stream: CatalogoService.instancia.streamProductos(SesionActual.instancia.idNegocio!),
            builder: (context, productSnapshot) {
              final products = productSnapshot.data ?? [];
              final names = {for (final p in products) p.id: p.nombre};
              if (items.isEmpty) {
                return AppEmptyState(
                  icon: Icons.tune,
                  title: 'No hay variantes todavía',
                  message: 'Agrega variantes (tamaños, presentaciones) a tus productos.',
                  actionLabel: 'Nueva variante',
                  onAction: () => _editar(context),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final item = items[i];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.tune)),
                      title: Text(item.nombre),
                      subtitle: Text(
                        '${names[item.idProducto] ?? 'Producto'} · '
                        '+Bs ${item.precioAdicional.toStringAsFixed(2)}',
                      ),
                      onTap: () => _editar(context, item: item),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppStatusBadge(
                            label: item.estado ? 'Activa' : 'Inactiva',
                            tone: item.estado ? AppStatusTone.success : AppStatusTone.neutral,
                          ),
                          Switch(
                            value: item.estado,
                            onChanged: (v) =>
                                CatalogoService.instancia.cambiarEstadoVariante(item.id, v),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva variante'),
      ),
    );
  }
}
