import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/app_empty_state.dart';

/// SuperAdmin: errores inesperados que tuvieron los usuarios (ver
/// RegistroErrores). Sirven para encontrar y corregir fallas.
class SuperAdminErroresScreen extends StatelessWidget {
  final bool incrustada;
  const SuperAdminErroresScreen({super.key, this.incrustada = false});

  static final _col = FirebaseFirestore.instance.collection('erroresApp');

  Future<void> _ver(BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final d = doc.data();
    final texto = 'Mensaje: ${d['mensaje']}\n'
        'Plataforma: ${d['plataforma']} · Versión: ${d['version']} · Rol: ${d['rol']}\n'
        '${(d['contexto'] as String? ?? '').isEmpty ? '' : 'Contexto: ${d['contexto']}\n'}'
        '\n${d['pila'] ?? ''}';
    final borrar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalle del error'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: SelectableText(texto, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: texto)),
            icon: const Icon(Icons.copy),
            label: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Marcar como resuelto'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cerrar')),
        ],
      ),
    );
    if (borrar == true) await doc.reference.delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !incrustada,
        title: const Text('Errores de la app'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _col.orderBy('fecha', descending: true).limit(100).snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('No se pudieron cargar: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const AppEmptyState(
              icon: Icons.verified_outlined,
              title: 'Sin errores registrados',
              message: 'Si alguna persona tiene una falla inesperada en la app, aparecerá aquí '
                  'con los datos para corregirla.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final fecha = (d['fecha'] as Timestamp?)?.toDate();
              return Card(
                child: ListTile(
                  leading: Icon(
                    d['plataforma'] == 'web' ? Icons.language : Icons.phone_android,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    d['mensaje'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${fecha == null ? '' : '${formatoFechaHora(fecha)} · '}'
                    '${d['version'] ?? ''} · ${d['rol'] ?? ''}',
                  ),
                  onTap: () => _ver(context, docs[i]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
