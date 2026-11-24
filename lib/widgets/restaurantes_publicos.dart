import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../services/negocio_service.dart';
import '../theme/brand_style.dart';
import '../theme/design_tokens.dart';
import '../utils/colores.dart';
import 'app_imagen_red.dart';

/// "Restaurantes en Nami": logo, nombre y ciudad de los restaurantes
/// activos, en la pantalla de inicio de sesión, para que un cliente nuevo
/// sepa dónde puede pedir antes de crear su cuenta. Se leen una sola vez de
/// la lista pública (`directorio`), que no lleva datos sensibles. Si no hay
/// restaurantes o no se pueden leer, no se muestra nada.
class RestaurantesPublicos extends StatefulWidget {
  const RestaurantesPublicos({super.key});

  @override
  State<RestaurantesPublicos> createState() => _RestaurantesPublicosState();
}

class _RestaurantesPublicosState extends State<RestaurantesPublicos> {
  late final Future<List<Map<String, String>>> _lista = NegocioService.instancia.directorioPublico();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, String>>>(
      future: _lista,
      builder: (context, snap) {
        final lista = snap.data ?? const <Map<String, String>>[];
        if (lista.isEmpty) return const SizedBox.shrink();
        final textos = Theme.of(context).textTheme;
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                tr('Restaurantes donde puedes pedir'),
                textAlign: TextAlign.center,
                style: textos.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr('Inicia sesión o crea tu cuenta y elige uno. No necesitas código.'),
                textAlign: TextAlign.center,
                style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [for (final r in lista) _Restaurante(datos: r)],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Restaurante extends StatelessWidget {
  final Map<String, String> datos;

  const _Restaurante({required this.datos});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    final nombre = datos['nombre'] ?? '';
    final ciudad = datos['ciudad'] ?? '';
    final logo = datos['logoUrl'] ?? '';
    final color = colorDesdeHex(datos['colorPrimario'], scheme.primary);
    return Semantics(
      container: true,
      label: ciudad.isEmpty ? nombre : '$nombre, $ciudad',
      excludeSemantics: true,
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        decoration: context.brand.decoracionTarjeta(scheme),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: ClipOval(
                child: logo.isNotEmpty
                    ? AppImagenRed(url: logo, icono: Icons.storefront_outlined)
                    : Container(
                        color: color,
                        alignment: Alignment.center,
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                          style: textos.titleLarge?.copyWith(color: textoSobreColor(color)),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              nombre,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textos.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (ciudad.isNotEmpty)
              Text(
                ciudad,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textos.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
