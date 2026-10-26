import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../legal/textos_legales.dart';
import '../../models/negocio_model.dart';
import '../../services/condiciones_service.dart';
import '../../services/negocio_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/documento_imprimible.dart';
import '../../utils/errores.dart';
import '../../widgets/documento_legal.dart';
import 'cliente_menu_screen.dart';

/// Comprueba que el cliente aceptó las condiciones VIGENTES de este
/// restaurante. Si no (primera vez, o el restaurante las cambió), se las
/// muestra para que las lea y acepte. Devuelve true si puede pedir.
Future<bool> asegurarCondiciones(BuildContext context, NegocioModel negocio) async {
  final uid = SesionActual.instancia.actual?.idUsuario;
  if (uid == null) return false;
  NegocioModel fresco = negocio;
  String? aceptada;
  try {
    fresco = await NegocioService.instancia.obtenerNegocioPorId(negocio.idNegocio);
    aceptada = await CondicionesService.instancia.versionAceptada(uid, negocio.idNegocio);
  } catch (_) {
    // Sin conexión: se intenta de todos modos; las reglas de la base de
    // datos no dejan pedir sin haber aceptado.
    return true;
  }
  if (aceptada == fresco.condiciones.version) return true;
  if (!context.mounted) return false;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => CondicionesRestauranteScreen(negocio: fresco, cambiaron: aceptada != null),
  ));
  return ok == true;
}

/// Abre el menú del restaurante, pidiendo antes aceptar sus condiciones si
/// hace falta.
Future<void> abrirRestaurante(BuildContext context, NegocioModel negocio, {String? fotoRespaldo}) async {
  if (!await asegurarCondiciones(context, negocio) || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => ClienteMenuScreen(negocio: negocio, fotoRespaldo: fotoRespaldo),
  ));
}

/// "Condiciones de [restaurante]": quién vende, pagos, entregas,
/// devoluciones, reclamos y las reglas propias del restaurante. Con
/// [soloLectura] se muestra solo para consultar (desde la información del
/// restaurante o Mi cuenta), sin botón de aceptar.
class CondicionesRestauranteScreen extends StatefulWidget {
  final NegocioModel negocio;
  final bool soloLectura;
  final bool cambiaron;

  const CondicionesRestauranteScreen({
    super.key,
    required this.negocio,
    this.soloLectura = false,
    this.cambiaron = false,
  });

  @override
  State<CondicionesRestauranteScreen> createState() => _CondicionesRestauranteScreenState();
}

class _CondicionesRestauranteScreenState extends State<CondicionesRestauranteScreen> {
  bool _leido = false;
  bool _enviando = false;

  NegocioModel get _n => widget.negocio;

  String get _version => _n.condiciones.version.isEmpty
      ? tr('Condiciones de base de la plataforma')
      : tr('Versión {version}', {'version': _n.condiciones.version});

  Future<void> _imprimir() async {
    final ok = await imprimirDocumentoLegal(
      titulo: TextosLegales.tituloCondiciones(_n),
      subtitulo: _version,
      resumen: TextosLegales.resumenCondiciones(_n),
      secciones: TextosLegales.condicionesRestaurante(_n),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('Para imprimir o guardar en PDF, abre la app en el navegador.')),
      ));
    }
  }

  Future<void> _aceptar() async {
    final uid = SesionActual.instancia.actual?.idUsuario;
    if (uid == null) return;
    setState(() => _enviando = true);
    try {
      await CondicionesService.instancia.aceptarCondiciones(uid, _n.idNegocio, _n.condiciones.version);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(textoError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textos = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Condiciones del restaurante')),
        actions: [
          IconButton(
            tooltip: tr('Imprimir o guardar como PDF'),
            icon: const Icon(Icons.print_outlined),
            onPressed: _imprimir,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (!widget.soloLectura) ...[
                  Card(
                    color: scheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: scheme.onSecondaryContainer),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              widget.cambiaron
                                  ? tr('{restaurante} actualizó sus condiciones. Léelas y acéptalas para seguir pidiendo.', {'restaurante': _n.nombre})
                                  : tr('Antes de tu primer pedido en {restaurante}, lee y acepta sus condiciones.', {'restaurante': _n.nombre}),
                              style: textos.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                VistaDocumentoLegal(
                  titulo: TextosLegales.tituloCondiciones(_n),
                  subtitulo: _version,
                  resumen: TextosLegales.resumenCondiciones(_n),
                  secciones: TextosLegales.condicionesRestaurante(_n),
                ),
                if (!widget.soloLectura) ...[
                  CheckboxListTile(
                    value: _leido,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _leido = v ?? false),
                    title: Text(tr('Leí y acepto las condiciones de {restaurante}.', {'restaurante': _n.nombre})),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: !_leido || _enviando ? null : _aceptar,
                    icon: const Icon(Icons.check),
                    label: Text(tr('Aceptar y continuar')),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr('Ahora no')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
