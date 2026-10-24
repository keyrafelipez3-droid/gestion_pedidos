import 'package:flutter/material.dart';

import '../../services/sesion_actual.dart';
import '../../services/solicitudes_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../utils/formato.dart';
import '../../widgets/app_empty_state.dart';

/// SuperAdmin: restaurantes que pidieron unirse. Al aprobar se crea el
/// negocio y quien lo pidió pasa a ser su Administrador.
class SuperAdminSolicitudesScreen extends StatefulWidget {
  final bool incrustada;
  const SuperAdminSolicitudesScreen({super.key, this.incrustada = false});

  @override
  State<SuperAdminSolicitudesScreen> createState() => _SuperAdminSolicitudesScreenState();
}

class _SuperAdminSolicitudesScreenState extends State<SuperAdminSolicitudesScreen> {
  late final Stream<List<SolicitudNegocio>> _stream = SolicitudesService.instancia.streamPendientes();
  String? _procesando;

  String get _idSuper => SesionActual.instancia.actual?.idUsuario ?? '';

  Future<void> _aprobar(SolicitudNegocio s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Aprobar "${s.nombreNegocio}"?'),
        content: Text(
          'Se creará el negocio y ${s.nombreSolicitante.isEmpty ? s.correo : s.nombreSolicitante} '
          'pasará a ser su Administrador. La próxima vez que entre deberá activar la '
          'verificación en dos pasos y firmar el acuerdo del personal.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aprobar')),
        ],
      ),
    );
    if (ok != true) return;
    await _ejecutar(s, () => SolicitudesService.instancia.aprobar(s, idSuperAdmin: _idSuper),
        'Negocio "${s.nombreNegocio}" creado.');
  }

  Future<void> _rechazar(SolicitudNegocio s) async {
    final motivo = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar "${s.nombreNegocio}"'),
        content: TextField(
          controller: motivo,
          maxLength: 300,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Motivo (lo verá quien la envió)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, motivo.text.trim()), child: const Text('Rechazar')),
        ],
      ),
    );
    motivo.dispose();
    if (texto == null) return;
    await _ejecutar(s, () => SolicitudesService.instancia.rechazar(s, motivo: texto, idSuperAdmin: _idSuper),
        'Solicitud rechazada.');
  }

  Future<void> _ejecutar(SolicitudNegocio s, Future<void> Function() accion, String exito) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _procesando = s.idUsuario);
    try {
      await accion();
      messenger.showSnackBar(SnackBar(content: Text(exito)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(textoError(e))));
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Solicitudes de negocios'),
      ),
      body: StreamBuilder<List<SolicitudNegocio>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(textoError(snap.error!)));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'Sin solicitudes pendientes',
              message: 'Cuando un restaurante pida unirse desde "Mi cuenta → Registrar mi negocio", '
                  'aparecerá aquí para que lo apruebes.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (final s in lista)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.nombreNegocio,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text('${s.ciudad} · Tel. ${s.telefono}${s.nit.isEmpty ? '' : ' · NIT ${s.nit}'}'),
                        Text('Solicitante: ${s.nombreSolicitante} (${s.correo})'),
                        if (s.fecha != null) Text('Enviada: ${formatoFechaHora(s.fecha!)}'),
                        if (s.mensaje.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text('"${s.mensaje}"', style: const TextStyle(fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _procesando == null ? () => _rechazar(s) : null,
                              child: const Text('Rechazar'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            FilledButton.icon(
                              onPressed: _procesando == null ? () => _aprobar(s) : null,
                              icon: const Icon(Icons.check),
                              label: const Text('Aprobar'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
