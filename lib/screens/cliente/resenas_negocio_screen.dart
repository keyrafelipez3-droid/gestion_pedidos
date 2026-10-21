import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/negocio_model.dart';
import '../../models/resena_model.dart';
import '../../services/resena_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/estrellas.dart';

String formatoFecha(DateTime f) =>
    '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';

/// Reseñas visibles de un negocio, con su promedio.
class ResenasNegocioScreen extends StatelessWidget {
  final NegocioModel negocio;
  const ResenasNegocioScreen({super.key, required this.negocio});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Reseñas de {nombre}', {'nombre': negocio.nombre}))),
      body: StreamBuilder<List<ResenaModel>>(
        stream: ResenaService.instancia.streamVisibles(negocio.idNegocio),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(tr('No se pudieron cargar las reseñas: {error}', {'error': snapshot.error})));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final resenas = snapshot.data!;
          if (resenas.isEmpty) {
            return AppEmptyState(
              icon: Icons.star_outline_rounded,
              title: tr('Todavía no hay reseñas'),
              message: tr('Cuando los clientes califiquen sus pedidos, aparecerán acá.'),
            );
          }
          final promedio =
              resenas.fold<int>(0, (suma, r) => suma + r.calificacion) / resenas.length;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Text(promedio.toStringAsFixed(1),
                              style: textos.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Estrellas(valor: promedio, tamano: 22),
                              Text('${resenas.length} '
                                  '${resenas.length == 1 ? 'reseña' : 'reseñas'}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final r in resenas)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(r.nombreCliente,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                if (r.fecha != null)
                                  Text(formatoFecha(r.fecha!), style: textos.bodySmall),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Estrellas(valor: r.calificacion.toDouble()),
                            if (r.comentario.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Text(r.comentario),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
