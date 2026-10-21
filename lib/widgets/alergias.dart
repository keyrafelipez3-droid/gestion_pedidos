import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../models/alergenos.dart';
import '../services/traduccion_service.dart';
import '../theme/design_tokens.dart';

const _rojoAlergia = Color(0xFFB3261E);

/// Recuadro rojo con las alergias del cliente. Se muestra en la cocina, la
/// caja, el detalle del pedido y el ticket. [compacta] es la versión de una
/// línea para las tarjetas de las listas.
class BandaAlergias extends StatelessWidget {
  final List<String> alergias;
  final bool compacta;

  /// false cuando la ve el propio cliente (cambian los textos).
  final bool paraPersonal;
  const BandaAlergias({
    super.key,
    required this.alergias,
    this.compacta = false,
    this.paraPersonal = true,
  });

  @override
  Widget build(BuildContext context) {
    final codigos = Alergenos.ordenar(alergias);
    if (codigos.isEmpty) return const SizedBox.shrink();
    final items = [for (final c in codigos) Alergenos.porCodigo(c)!];
    if (compacta) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(color: _rojoAlergia, borderRadius: AppRadius.smAll),
        child: Text(
          '⚠ ${tr('ALERGIA')}: ${items.map((a) => '${a.emoji} ${a.etiqueta}').join(' · ')}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
        ),
      );
    }
    return Semantics(
      label: tr('Alergias del cliente: {lista}', {'lista': Alergenos.nombres(codigos)}),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _rojoAlergia,
          borderRadius: AppRadius.mdAll,
          boxShadow: [
            BoxShadow(color: _rojoAlergia.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    paraPersonal ? tr('ALERGIA DEL CLIENTE') : tr('Tus alergias'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final a in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: AppRadius.smAll),
                    child: Text(
                      '${a.emoji} ${a.etiqueta.toUpperCase()}',
                      style: const TextStyle(color: _rojoAlergia, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              paraPersonal
                  ? tr('No usar estos ingredientes. Si no se pueden quitar, avisa al cliente antes de preparar.')
                  : tr('El local ya fue avisado y lo verá antes de preparar tu pedido.'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista de alérgenos para marcar (checkout, Mi cuenta, producto del
/// Administrador, pedido de mesa del Cajero).
class SelectorAlergias extends StatelessWidget {
  final List<String> seleccionadas;
  final ValueChanged<List<String>> onChanged;
  const SelectorAlergias({super.key, required this.seleccionadas, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final a in Alergenos.todos)
          FilterChip(
            label: Text('${a.emoji} ${a.etiqueta}'),
            selected: seleccionadas.contains(a.codigo),
            selectedColor: scheme.errorContainer,
            checkmarkColor: scheme.onErrorContainer,
            onSelected: (marcado) {
              final nuevas = {...seleccionadas};
              marcado ? nuevas.add(a.codigo) : nuevas.remove(a.codigo);
              onChanged(Alergenos.ordenar(nuevas));
            },
          ),
      ],
    );
  }
}

/// "Contiene: 🌾 🧅" en la tarjeta de un producto. Si alguno es alergia
/// del cliente ([alergiasCliente]), se muestra en rojo con su nombre.
class ContieneAlergenos extends StatelessWidget {
  final List<String> alergenos;
  final List<String> alergiasCliente;
  const ContieneAlergenos({super.key, required this.alergenos, this.alergiasCliente = const []});

  @override
  Widget build(BuildContext context) {
    if (alergenos.isEmpty) return const SizedBox.shrink();
    final conflicto = Alergenos.enComun(alergenos, alergiasCliente);
    final scheme = Theme.of(context).colorScheme;
    if (conflicto.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: AppRadius.smAll),
        child: Text(
          '⚠ ${tr('Contiene {lista} (tu alergia)', {'lista': Alergenos.nombres(conflicto).toLowerCase()})}',
          style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      );
    }
    final items = [for (final c in Alergenos.ordenar(alergenos)) Alergenos.porCodigo(c)!];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Tooltip(
        message: tr('Contiene: {lista}', {'lista': Alergenos.nombres(alergenos)}),
        child: Text(
          '${tr('Contiene:')} ${items.map((a) => a.emoji).join(' ')}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
        ),
      ),
    );
  }
}

/// Etiqueta "🌐 Inglés" para saber que el cliente es extranjero.
class ChipIdiomaCliente extends StatelessWidget {
  final String codigo;
  const ChipIdiomaCliente({super.key, required this.codigo});

  @override
  Widget build(BuildContext context) {
    if (codigo == 'es' || codigo.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final nombre = TraduccionService.nombresIdioma[codigo] ?? codigo.toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: scheme.tertiaryContainer, borderRadius: AppRadius.smAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.translate, size: 14, color: scheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            tr('Cliente habla {idioma}', {'idioma': tr(nombre)}),
            style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
