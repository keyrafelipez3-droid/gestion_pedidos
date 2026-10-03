import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import 'cliente_menu_screen.dart';

/// HU-16 (parte 1): el Cliente elige de qué negocio quiere ver el menú.
/// Es la puerta de entrada a todo el flujo de Cliente (menú → carrito →
/// checkout).
class ClienteNegociosScreen extends StatelessWidget {
  const ClienteNegociosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('¿Dónde quieres pedir?')),
      body: StreamBuilder<List<NegocioModel>>(
        stream: NegocioService.instancia.streamNegocios(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final negocios = snapshot.data!.where((n) => n.estado).toList();
          if (negocios.isEmpty) {
            return const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Todavía no hay negocios disponibles',
              message: 'Vuelve a intentarlo más tarde.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: negocios.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final negocio = negocios[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        negocio.logoUrl.isNotEmpty ? NetworkImage(negocio.logoUrl) : null,
                    child: negocio.logoUrl.isEmpty
                        ? Text(negocio.nombre.isNotEmpty ? negocio.nombre[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(negocio.nombre),
                  subtitle: negocio.descripcion.isEmpty ? null : Text(negocio.descripcion),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ClienteMenuScreen(negocio: negocio),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
