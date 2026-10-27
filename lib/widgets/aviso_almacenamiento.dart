import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/idioma.dart';
import '../screens/legal/legal_screen.dart';
import '../theme/design_tokens.dart';
import '../utils/navegacion.dart';

/// Aviso de cookies y almacenamiento: la primera vez que se abre la app se
/// avisa qué se guarda en el dispositivo. La app solo usa almacenamiento
/// necesario (sesión, idioma, preferencias) y nada de publicidad ni
/// seguimiento, así que no hay nada que aceptar o rechazar: es un aviso.
/// Se cierra con "Entendido" y no vuelve a aparecer en ese dispositivo.
class AvisoAlmacenamiento extends StatefulWidget {
  final Widget child;

  const AvisoAlmacenamiento({super.key, required this.child});

  static const clave = 'aviso_almacenamiento_v1';

  @override
  State<AvisoAlmacenamiento> createState() => _AvisoAlmacenamientoState();
}

class _AvisoAlmacenamientoState extends State<AvisoAlmacenamiento> {
  bool _mostrar = false;

  @override
  void initState() {
    super.initState();
    _leer();
  }

  Future<void> _leer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visto = prefs.getBool(AvisoAlmacenamiento.clave) ?? false;
      if (!visto && mounted) setState(() => _mostrar = true);
    } catch (_) {
      // Sin almacenamiento disponible no hay nada que avisar.
    }
  }

  Future<void> _cerrar() async {
    setState(() => _mostrar = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AvisoAlmacenamiento.clave, true);
    } catch (_) {}
  }

  void _verDetalles() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const LegalScreen(tipo: TipoTextoLegal.politicaPrivacidad)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_mostrar) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Semantics(
                  liveRegion: true,
                  container: true,
                  child: Material(
                    elevation: 8,
                    color: scheme.surfaceContainerHigh,
                    borderRadius: AppRadius.lgAll,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.cookie_outlined, color: scheme.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  tr('Usamos solo el almacenamiento necesario para que la app funcione: tu sesión, '
                                      'tu idioma y tus preferencias. No usamos cookies de publicidad ni de seguimiento.'),
                                  style: textos.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: AppSpacing.sm,
                            children: [
                              TextButton(onPressed: _verDetalles, child: Text(tr('Ver detalles'))),
                              FilledButton(onPressed: _cerrar, child: Text(tr('Entendido'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
