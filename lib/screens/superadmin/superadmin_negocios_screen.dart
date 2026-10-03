import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_status_badge.dart';
import 'superadmin_negocio_detalle_screen.dart';

/// Corrección pedida por el docente: pantalla exclusiva del SuperAdmin
/// para crear negocios y entrar a personalizar/gestionar cada uno. Es el
/// punto de entrada del multi-tenant — antes existía un solo negocio fijo
/// (`negocios/principal`); ahora puede haber varios.
class SuperAdminNegociosScreen extends StatelessWidget {
  final bool incrustada;
  const SuperAdminNegociosScreen({super.key, this.incrustada = false});

  Future<void> _crearNegocio(BuildContext context) async {
    final nombreCtrl = TextEditingController();
    final key = GlobalKey<FormState>();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo negocio'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: nombreCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nombre del negocio'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(ctx, nombreCtrl.text.trim());
              }
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nombreCtrl.dispose();
    });

    if (nombre == null || nombre.isEmpty) return;
    final idNegocio = await NegocioService.instancia.crearNegocio(
      NegocioModel(idNegocio: '', nombre: nombre),
    );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SuperAdminNegocioDetalleScreen(
          negocio: NegocioModel(idNegocio: idNegocio, nombre: nombre),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Negocios'),
      ),
      body: StreamBuilder<List<NegocioModel>>(
        stream: NegocioService.instancia.streamNegocios(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final negocios = snapshot.data ?? [];
          if (negocios.isEmpty) {
            return AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Todavía no hay negocios',
              message: 'Crea el primer negocio para empezar a personalizarlo '
                  'y asignarle un Administrador.',
              actionLabel: 'Nuevo negocio',
              onAction: () => _crearNegocio(context),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: negocios.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final n = negocios[i];
              final tieneLogo = n.logoUrl.trim().isNotEmpty;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: tieneLogo ? NetworkImage(n.logoUrl.trim()) : null,
                    child: tieneLogo ? null : const Icon(Icons.storefront_outlined),
                  ),
                  title: Text(n.nombre.isEmpty ? '(sin nombre)' : n.nombre),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AppStatusBadge(
                      label: n.estado ? 'Activo' : 'Inactivo',
                      tone: n.estado ? AppStatusTone.success : AppStatusTone.neutral,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SuperAdminNegocioDetalleScreen(negocio: n),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _crearNegocio(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo negocio'),
      ),
    );
  }
}
