import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/idioma.dart';
import '../services/codigo_negocio_service.dart';
import '../services/negocio_service.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';
import '../screens/admin/qr_restaurante_screen.dart';
import 'app_imagen_red.dart';

/// Código de acceso y enlace de un restaurante, con botones para copiarlos.
/// El SuperAdmin además puede crearlo o cambiarlo ([puedeCambiar]).
class TarjetaCodigoNegocio extends StatelessWidget {
  final String idNegocio;
  final bool puedeCambiar;

  const TarjetaCodigoNegocio({super.key, required this.idNegocio, this.puedeCambiar = false});

  Future<void> _copiar(BuildContext context, String texto, String aviso) async {
    await Clipboard.setData(ClipboardData(text: texto));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
    }
  }

  Future<void> _abrirQr(BuildContext context, String codigo) async {
    final navigator = Navigator.of(context);
    final negocio = await NegocioService.instancia.obtenerNegocioPorId(idNegocio);
    navigator.push(MaterialPageRoute(
      builder: (_) => QrRestauranteScreen(negocio: negocio, codigo: codigo),
    ));
  }

  Future<void> _asignar(BuildContext context, bool cambiar) async {
    final messenger = ScaffoldMessenger.of(context);
    if (cambiar) {
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cambiar el código'),
              content: const Text(
                'El código y el enlace actuales dejarán de servir para entrar. '
                'Los clientes que ya entraron siguen teniendo acceso.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cambiar')),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    try {
      final negocio = await NegocioService.instancia.obtenerNegocioPorId(idNegocio);
      final codigo = await CodigoNegocioService.instancia.asignarCodigo(negocio);
      messenger.showSnackBar(SnackBar(content: Text('Código del restaurante: $codigo')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo crear el código: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: StreamBuilder<String?>(
          stream: CodigoNegocioService.instancia.streamCodigo(idNegocio),
          builder: (context, s) {
            final codigo = s.data ?? '';
            final tiene = codigo.isNotEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, color: scheme.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Acceso de clientes',
                          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Los clientes entran SOLO a este restaurante con este código, o con su enlace. '
                  'No ven a los demás restaurantes.',
                  style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!s.hasData && !s.hasError)
                  const LinearProgressIndicator()
                else if (!tiene)
                  Text(
                    puedeCambiar
                        ? 'Este restaurante todavía no tiene código.'
                        : 'Tu restaurante todavía no tiene código. Pídeselo al administrador de la plataforma.',
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: context.brand.pequeno,
                    ),
                    child: SelectableText(
                      codigo,
                      textAlign: TextAlign.center,
                      style: textos.headlineMedium?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SelectableText(
                    CodigoNegocioService.enlace(codigo),
                    style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _copiar(context, codigo, 'Código copiado'),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Copiar código'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _copiar(context, CodigoNegocioService.enlace(codigo), 'Enlace copiado'),
                        icon: const Icon(Icons.link),
                        label: const Text('Copiar enlace'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _abrirQr(context, codigo),
                        icon: const Icon(Icons.qr_code_2),
                        label: const Text('QR para las mesas'),
                      ),
                    ],
                  ),
                ],
                if (puedeCambiar) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: tiene
                        ? TextButton.icon(
                            onPressed: () => _asignar(context, true),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Cambiar código'),
                          )
                        : FilledButton.icon(
                            onPressed: () => _asignar(context, false),
                            icon: const Icon(Icons.add),
                            label: const Text('Crear código'),
                          ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Vas a pedir en …": nombre y logo del restaurante del enlace, en las
/// pantallas de inicio de sesión y registro.
class BannerInvitacion extends StatelessWidget {
  final String codigo;
  final Color? colorTexto;
  const BannerInvitacion({super.key, required this.codigo, this.colorTexto});

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return FutureBuilder<InvitacionNegocio?>(
      future: CodigoNegocioService.instancia.buscar(codigo),
      builder: (context, s) {
        final inv = s.data;
        if (inv == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            children: [
              if (inv.logoUrl.isNotEmpty)
                ClipOval(
                  child: SizedBox(width: 44, height: 44, child: AppImagenRed(url: inv.logoUrl)),
                ),
              if (inv.logoUrl.isNotEmpty) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  tr('Vas a pedir en {nombre}', {'nombre': inv.nombre}),
                  style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: colorTexto),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Pide el código de un restaurante y deja al cliente entrar a él.
/// Devuelve true si entró.
Future<bool> pedirCodigoRestaurante(BuildContext context, String uid) async {
  final ctrl = TextEditingController();
  String? error;
  var buscando = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> confirmar() async {
          setState(() {
            buscando = true;
            error = null;
          });
          final inv = await CodigoNegocioService.instancia.buscar(ctrl.text);
          if (inv == null) {
            setState(() {
              buscando = false;
              error = tr('Ese código no existe. Revisa que esté bien escrito.');
            });
            return;
          }
          try {
            await CodigoNegocioService.instancia.unirse(uid, inv);
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (_) {
            setState(() {
              buscando = false;
              error = tr('No se pudo entrar al restaurante. Intenta de nuevo.');
            });
          }
        }

        return AlertDialog(
          title: Text(tr('Código del restaurante')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('Te lo da el restaurante donde quieres pedir.')),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: tr('Código'),
                  hintText: 'ABC123',
                  errorText: error,
                ),
                onSubmitted: (_) => buscando ? null : confirmar(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
            FilledButton(
              onPressed: buscando ? null : confirmar,
              child: Text(tr('Entrar')),
            ),
          ],
        );
      },
    ),
  );
  return ok ?? false;
}
