import 'package:flutter/material.dart';

import '../../models/sucursal_model.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/campo_telefono.dart';
import '../../widgets/app_search_field.dart';
import '../../widgets/app_imagen_red.dart';
import '../../widgets/app_status_badge.dart';
import '../../widgets/selector_imagen.dart';
import '../../services/sesion_actual.dart';
import '../../services/actividad_service.dart';
import '../../models/actividad_model.dart';
import 'horarios_screen.dart';
import 'zonas_delivery_screen.dart';
import '../../widgets/app_cargando.dart';

class SucursalesScreen extends StatefulWidget {
  /// true cuando la pantalla vive incrustada dentro del panel de
  /// administración (escritorio, con el sidebar siempre visible) en vez de
  /// abrirse en pantalla completa.
  final bool incrustada;

  const SucursalesScreen({super.key, this.incrustada = false});

  @override
  State<SucursalesScreen> createState() => _SucursalesScreenState();
}

class _SucursalesScreenState extends State<SucursalesScreen> {
  final _busqueda = TextEditingController();
  String _filtro = '';
  // Igual que en Productos: se guarda el stream una sola vez para que
  // el buscador no reinicie la lista con cada letra.
  late final _streamSucursales =
      SucursalService.instancia.streamSucursales(SesionActual.instancia.idNegocio!);

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  Future<void> _editar(BuildContext context, {SucursalModel? sucursal}) async {
    final nombre = TextEditingController(text: sucursal?.nombre ?? '');
    final direccion = TextEditingController(text: sucursal?.direccion ?? '');
    final telefono = TextEditingController(text: sucursal?.telefono ?? '');
    final imagen = TextEditingController(text: sucursal?.imagenUrl ?? '');
    final key = GlobalKey<FormState>();
    var guardando = false;
    // Id generado de una vez (aunque sea una sucursal nueva) para que la
    // foto se suba a una ruta de Storage estable, ligada a este registro.
    final idEfectivo = sucursal?.id ?? SucursalService.instancia.nuevoId();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(sucursal == null ? 'Nueva sucursal' : 'Editar sucursal'),
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
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: direccion,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CampoTelefono(controller: telefono),
                  const SizedBox(height: AppSpacing.md),
                  SelectorImagen(
                    etiqueta: 'Foto de la sucursal (opcional)',
                    controller: imagen,
                    rutaStorage:
                        'negocios/${SesionActual.instancia.idNegocio}/sucursales/$idEfectivo',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: guardando ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: guardando
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      setState(() => guardando = true);
                      final item = SucursalModel(
                        id: idEfectivo,
                        nombre: nombre.text.trim(),
                        direccion: direccion.text.trim(),
                        telefono: telefono.text.trim(),
                        imagenUrl: imagen.text.trim(),
                        estado: sucursal?.estado ?? true,
                        horarios: sucursal?.horarios ?? SucursalModel.horariosPorDefecto(),
                        idNegocio: sucursal?.idNegocio ?? SesionActual.instancia.idNegocio,
                      );
                      try {
                        await SucursalService.instancia.guardar(item);
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      } catch (e) {
                        if (dialogContext.mounted) {
                          ScaffoldMessenger.of(dialogContext)
                              .showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (dialogContext.mounted) setState(() => guardando = false);
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
      direccion.dispose();
      telefono.dispose();
      imagen.dispose();
    });
  }

  /// HU-47: pausa o reanuda los pedidos de la sucursal (con motivo
  /// opcional que ve el cliente).
  Future<void> _pausar(BuildContext context, SucursalModel s) async {
    final messenger = ScaffoldMessenger.of(context);
    if (s.pedidosPausados) {
      await SucursalService.instancia.pausarPedidos(s.id, pausar: false);
      ActividadService.instancia.registrar(
        ActividadTipo.pedido,
        'Reanudó los pedidos de la sucursal ${s.nombre}',
      );
      messenger.showSnackBar(SnackBar(content: Text('${s.nombre} vuelve a recibir pedidos.')));
      return;
    }
    final motivoCtrl = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Pausar pedidos'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mientras esté en pausa, los clientes no podrán hacer pedidos en ${s.nombre}. '
                    'Los pedidos que ya están en curso siguen normalmente.'),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: motivoCtrl,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (opcional, lo ve el cliente)',
                    hintText: 'Ej.: Cocina llena, volvemos en 30 minutos',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pausar')),
            ],
          ),
        ) ??
        false;
    // (El controlador no se libera aquí: el diálogo todavía se está
    // cerrando con su animación y lo sigue usando.)
    final motivo = motivoCtrl.text;
    if (!ok) return;
    await SucursalService.instancia.pausarPedidos(s.id, pausar: true, motivo: motivo);
    ActividadService.instancia.registrar(
      ActividadTipo.pedido,
      'Pausó los pedidos de la sucursal ${s.nombre}${motivo.trim().isEmpty ? '' : ': ${motivo.trim()}'}',
    );
    messenger.showSnackBar(SnackBar(content: Text('Pedidos en pausa en ${s.nombre}.')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Sucursales · HU-08'),
      ),
      body: StreamBuilder<List<SucursalModel>>(
        stream: _streamSucursales,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppCargando();
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final todas = snapshot.data ?? [];
          if (todas.isEmpty) {
            return AppEmptyState(
              icon: Icons.location_city_outlined,
              title: 'No hay sucursales todavía',
              message: 'Crea la primera sucursal para empezar a organizar tu negocio.',
              actionLabel: 'Nueva sucursal',
              onAction: () => _editar(context),
            );
          }

          final filtro = _filtro.trim().toLowerCase();
          final items = filtro.isEmpty
              ? todas
              : todas
                  .where((s) =>
                      s.nombre.toLowerCase().contains(filtro) ||
                      s.direccion.toLowerCase().contains(filtro))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm,
                ),
                child: AppSearchField(
                  controller: _busqueda,
                  hint: 'Buscar sucursal por nombre o dirección',
                  onChanged: (v) => setState(() => _filtro = v),
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? const AppEmptyState(
                        icon: Icons.search_off,
                        title: 'Ninguna sucursal coincide con la búsqueda',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, AppSpacing.md,
                        ),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final s = items[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  AvatarImagen(
                                    url: s.imagenUrl,
                                    icono: Icons.store_outlined,
                                    backgroundColor: scheme.primaryContainer,
                                    foregroundColor: scheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.nombre,
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                        if ([s.direccion, s.telefono].any((e) => e.isNotEmpty))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              [s.direccion, s.telefono]
                                                  .where((e) => e.isNotEmpty)
                                                  .join(' · '),
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    color: scheme.onSurfaceVariant,
                                                  ),
                                            ),
                                          ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Wrap(
                                          spacing: AppSpacing.xs,
                                          runSpacing: AppSpacing.xs,
                                          children: [
                                            AppStatusBadge(
                                              label: s.estado ? 'Activa' : 'Inactiva',
                                              tone: s.estado
                                                  ? AppStatusTone.success
                                                  : AppStatusTone.neutral,
                                            ),
                                            if (s.pedidosPausados)
                                              const AppStatusBadge(
                                                label: 'Pedidos en pausa',
                                                tone: AppStatusTone.warning,
                                              ),
                                          ],
                                        ),
                                        if (s.pedidosPausados && s.motivoPausa.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Text(
                                              'Motivo: ${s.motivoPausa}',
                                              style: Theme.of(context).textTheme.bodySmall,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (accion) {
                                      switch (accion) {
                                        case 'editar':
                                          _editar(context, sucursal: s);
                                          break;
                                        case 'horarios':
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => HorariosScreen(sucursal: s),
                                            ),
                                          );
                                          break;
                                        case 'delivery':
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ZonasDeliveryScreen(sucursal: s),
                                            ),
                                          );
                                          break;
                                        case 'estado':
                                          SucursalService.instancia
                                              .cambiarEstado(s.id, !s.estado);
                                          break;
                                        case 'pausa':
                                          _pausar(context, s);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'editar',
                                        child: Text('Editar'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'horarios',
                                        child: Text('Horarios'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delivery',
                                        child: Text('Zonas de delivery'),
                                      ),
                                      PopupMenuItem(
                                        value: 'pausa',
                                        child: Text(s.pedidosPausados
                                            ? 'Reanudar pedidos'
                                            : 'Pausar pedidos'),
                                      ),
                                      PopupMenuItem(
                                        value: 'estado',
                                        child: Text(s.estado ? 'Desactivar' : 'Activar'),
                                      ),
                                    ],
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
        label: const Text('Nueva sucursal'),
      ),
    );
  }
}
