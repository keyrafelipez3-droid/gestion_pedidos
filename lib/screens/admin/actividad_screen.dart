import 'package:flutter/material.dart';

import '../../models/actividad_model.dart';
import '../../services/actividad_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/app_empty_state.dart';

/// Registro de actividad del negocio: inicios y cierres de sesión, cambios
/// en el personal, apertura y cierre de cajas, pedidos cancelados, cambios
/// en el catálogo y cupones, firma del acuerdo y activación de la
/// verificación en dos pasos. Solo lectura: nadie puede borrar ni editar.
class ActividadScreen extends StatefulWidget {
  final bool incrustada;
  const ActividadScreen({super.key, this.incrustada = false});

  @override
  State<ActividadScreen> createState() => _ActividadScreenState();
}

class _ActividadScreenState extends State<ActividadScreen> {
  String? _tipo; // null = todos
  final _buscar = TextEditingController();
  String _texto = '';
  Stream<List<ActividadModel>>? _stream;

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  static IconData _icono(String tipo) => switch (tipo) {
        ActividadTipo.sesion => Icons.login,
        ActividadTipo.empleado => Icons.badge_outlined,
        ActividadTipo.caja => Icons.point_of_sale_outlined,
        ActividadTipo.pedido => Icons.receipt_long_outlined,
        ActividadTipo.catalogo => Icons.restaurant_menu_outlined,
        ActividadTipo.seguridad => Icons.shield_outlined,
        _ => Icons.history,
      };

  @override
  Widget build(BuildContext context) {
    final idNegocio = SesionActual.instancia.idNegocio;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Registro de actividad'),
      ),
      body: idNegocio == null
          ? const AppEmptyState(icon: Icons.storefront_outlined, title: 'Sin negocio asignado')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                  child: TextField(
                    controller: _buscar,
                    onChanged: (v) => setState(() => _texto = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por persona o acción',
                    ),
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ChoiceChip(
                          label: const Text('Todo'),
                          selected: _tipo == null,
                          onSelected: (_) => setState(() => _tipo = null),
                        ),
                      ),
                      for (final e in ActividadTipo.nombres.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: ChoiceChip(
                            avatar: Icon(_icono(e.key), size: 16),
                            label: Text(e.value),
                            selected: _tipo == e.key,
                            onSelected: (_) => setState(() => _tipo = e.key),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ActividadModel>>(
                    stream: _stream ??= ActividadService.instancia.stream(idNegocio),
                    builder: (context, s) {
                      if (s.hasError) {
                        return const Center(child: Text('No se pudo cargar el registro.'));
                      }
                      if (!s.hasData) return const AppCargando();
                      final lista = s.data!
                          .where((a) => _tipo == null || a.tipo == _tipo)
                          .where((a) =>
                              _texto.isEmpty ||
                              a.descripcion.toLowerCase().contains(_texto) ||
                              a.nombreUsuario.toLowerCase().contains(_texto))
                          .toList();
                      if (lista.isEmpty) {
                        return const AppEmptyState(
                          icon: Icons.history,
                          title: 'Sin actividad registrada',
                          message: 'Aquí aparecerá quién inicia sesión, abre o cierra caja, cancela pedidos o cambia al personal.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final a = lista[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer,
                              child: Icon(_icono(a.tipo), size: 20, color: scheme.onPrimaryContainer),
                            ),
                            title: Text(a.descripcion),
                            subtitle: Text('${a.nombreUsuario} · ${a.rol}'),
                            trailing: Text(
                              a.fecha == null ? 'ahora' : formatoFechaHora(a.fecha!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
