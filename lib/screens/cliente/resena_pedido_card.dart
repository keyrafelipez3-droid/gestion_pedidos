import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../models/pedido_models.dart';
import '../../models/resena_model.dart';
import '../../services/resena_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/estrellas.dart';

/// Tarjeta del detalle del pedido para que el cliente califique un pedido
/// entregado: muestra el formulario, o su reseña ya publicada.
class ResenaPedidoCard extends StatefulWidget {
  final PedidoModel pedido;

  const ResenaPedidoCard({super.key, required this.pedido});

  @override
  State<ResenaPedidoCard> createState() => _ResenaPedidoCardState();
}

class _ResenaPedidoCardState extends State<ResenaPedidoCard> {
  final _comentarioCtrl = TextEditingController();
  int _estrellas = 0;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _comentarioCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_estrellas == 0) {
      setState(() => _error = tr('Elige de 1 a 5 estrellas.'));
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ResenaService.instancia.crear(
        pedido: widget.pedido,
        calificacion: _estrellas,
        comentario: _comentarioCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('¡Gracias por tu reseña!'))));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Eliminar mi reseña')),
        content: Text(tr('Se borrará tu reseña de este pedido. ¿Continuar?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Eliminar')),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await ResenaService.instancia.eliminar(widget.pedido.idNegocio, widget.pedido.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('No se pudo eliminar: {e}', {'e': e}))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<ResenaModel?>(
      stream: ResenaService.instancia.streamDePedido(widget.pedido.idNegocio, widget.pedido.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final resena = snapshot.data;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: resena != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Tu reseña'),
                          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xs),
                      Estrellas(valor: resena.calificacion.toDouble()),
                      if (resena.comentario.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(resena.comentario),
                      ],
                      if (resena.oculta) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          tr('El negocio ocultó esta reseña.'),
                          style: textos.bodySmall?.copyWith(color: scheme.error),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        onPressed: _eliminar,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(tr('Eliminar mi reseña')),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('¿Cómo estuvo tu pedido?'),
                          style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: AppSpacing.xs),
                      SelectorEstrellas(
                        valor: _estrellas,
                        onChanged: (v) => setState(() {
                          _estrellas = v;
                          _error = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextField(
                        controller: _comentarioCtrl,
                        maxLines: 3,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: tr('Comentario (opcional)'),
                          helperText: tr('Sé respetuoso: el negocio puede ocultar comentarios ofensivos.'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(_error!, style: TextStyle(color: scheme.error)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton(
                        onPressed: _enviando ? null : _enviar,
                        child: Text(_enviando ? tr('Enviando…') : tr('Publicar reseña')),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
