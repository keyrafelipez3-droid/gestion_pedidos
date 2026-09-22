// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

import '../../models/catalogo_models.dart';
import '../../services/catalogo_service.dart';

class CatalogoScreen extends StatelessWidget {
  const CatalogoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catálogo'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Categorías'),
              Tab(text: 'Productos'),
              Tab(text: 'Extras'),
              Tab(text: 'Variantes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoriasTab(),
            _ProductosTab(),
            _ComplementosTab(),
            _VariantesTab(),
          ],
        ),
      ),
    );
  }
}

class _CategoriasTab extends StatelessWidget {
  const _CategoriasTab();

  Future<void> _editar(BuildContext context, {CategoriaModel? item}) async {
    final nombre = TextEditingController(text: item?.nombre ?? '');
    final descripcion = TextEditingController(text: item?.descripcion ?? '');
    final key = GlobalKey<FormState>();
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
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
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
                    id: item?.id ?? '',
                    nombre: nombre.text.trim(),
                    descripcion: descripcion.text.trim(),
                    estado: item?.estado ?? true,
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
    nombre.dispose();
    descripcion.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: StreamBuilder<List<CategoriaModel>>(
          stream: CatalogoService.instancia.streamCategorias(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const Center(child: Text('No hay categorías.'));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.category_outlined)),
                    title: Text(item.nombre),
                    subtitle: Text(item.descripcion.isEmpty ? 'Sin descripción' : item.descripcion),
                    onTap: () => _editar(context, item: item),
                    trailing: Switch(
                      value: item.estado,
                      onChanged: (v) => CatalogoService.instancia.cambiarEstadoCategoria(item.id, v),
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
          label: const Text('Nueva categoría'),
        ),
      );
}

class _ProductosTab extends StatelessWidget {
  const _ProductosTab();

  Future<void> _editar(BuildContext context, {ProductoModel? item}) async {
    final categorias = await CatalogoService.instancia.streamCategorias().first;
    final nombre = TextEditingController(text: item?.nombre ?? '');
    final descripcion = TextEditingController(text: item?.descripcion ?? '');
    final precio = TextEditingController(
      text: item == null ? '' : item.precio.toStringAsFixed(2),
    );
    final imagen = TextEditingController(text: item?.imagenUrl ?? '');
    final key = GlobalKey<FormState>();
    var idCategoria = item?.idCategoria ?? '';
    var estado = item?.estado ?? true;
    var disponible = item?.disponible ?? true;

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
                        labelText: 'Nombre',
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
                        labelText: 'Precio',
                        prefixText: 'Bs ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null
                          ? 'Precio no válido'
                          : null,
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
                    TextFormField(
                      controller: imagen,
                      decoration: const InputDecoration(
                        labelText: 'URL de imagen (opcional)',
                        border: OutlineInputBorder(),
                      ),
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
                try {
                  await CatalogoService.instancia.guardarProducto(
                    ProductoModel(
                      id: item?.id ?? '',
                      nombre: nombre.text.trim(),
                      descripcion: descripcion.text.trim(),
                      precio: valor,
                      idCategoria: idCategoria,
                      imagenUrl: imagen.text.trim(),
                      estado: estado,
                      disponible: disponible,
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
    nombre.dispose();
    descripcion.dispose();
    precio.dispose();
    imagen.dispose();
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
          stream: CatalogoService.instancia.streamProductos(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            final items = snapshot.data ?? [];
            if (items.isEmpty) return const Center(child: Text('No hay productos.'));
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(item.disponible ? Icons.fastfood_outlined : Icons.visibility_off_outlined),
                    ),
                    title: Text(item.nombre),
                    subtitle: Text(
                      'Bs ${item.precio.toStringAsFixed(2)}${item.disponible ? ' · Disponible' : ' · No disponible'}',
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
                          onChanged: (v) => CatalogoService.instancia.cambiarDisponibilidadProducto(item.id, v),
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
          label: const Text('Nuevo producto'),
        ),
      );
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
                    labelText: 'Nombre',
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
                    labelText: 'Precio adicional',
                    prefixText: 'Bs ',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null
                      ? 'Precio no válido'
                      : null,
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
    nombre.dispose();
    descripcion.dispose();
    precio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<ComplementoModel>>(
        stream: CatalogoService.instancia.streamComplementos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No hay complementos o extras.'));
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
                  trailing: Switch(
                    value: item.estado,
                    onChanged: (v) => CatalogoService.instancia.cambiarEstadoComplemento(item.id, v),
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
    final productos = await CatalogoService.instancia.streamProductos().first;
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
                      labelText: 'Nombre de variante',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Precio adicional',
                      prefixText: 'Bs ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => double.tryParse((v ?? '').replaceAll(',', '.')) == null
                        ? 'Precio no válido'
                        : null,
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
    nombre.dispose();
    precio.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<VarianteModel>>(
        stream: CatalogoService.instancia.streamVariantes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final items = snapshot.data ?? [];

          return StreamBuilder<List<ProductoModel>>(
            stream: CatalogoService.instancia.streamProductos(),
            builder: (context, productSnapshot) {
              final products = productSnapshot.data ?? [];
              final names = {for (final p in products) p.id: p.nombre};
              if (items.isEmpty) return const Center(child: Text('No hay variantes.'));

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
                      trailing: Switch(
                        value: item.estado,
                        onChanged: (v) => CatalogoService.instancia.cambiarEstadoVariante(item.id, v),
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
