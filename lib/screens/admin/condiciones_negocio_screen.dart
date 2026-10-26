import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../legal/textos_legales.dart';
import '../../models/condiciones_negocio.dart';
import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/condiciones_service.dart';
import '../../services/negocio_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/documento_legal.dart';

/// El Administrador personaliza:
/// - las condiciones que acepta cada cliente al pedir en su restaurante
///   (devoluciones, tiempo de entrega, contacto para reclamos, reglas
///   propias), y
/// - las reglas internas que se agregan al acuerdo de su personal.
/// Al guardar, sube la versión: los clientes aceptan de nuevo antes de su
/// próximo pedido y el personal firma de nuevo al entrar.
class CondicionesNegocioScreen extends StatefulWidget {
  final bool incrustada;
  const CondicionesNegocioScreen({super.key, this.incrustada = false});

  @override
  State<CondicionesNegocioScreen> createState() => _CondicionesNegocioScreenState();
}

class _CondicionesNegocioScreenState extends State<CondicionesNegocioScreen> {
  NegocioModel? _negocio;
  bool _guardando = false;

  String _reembolso = CondicionesNegocio.reembolsoMismoMedio;
  final _dias = TextEditingController();
  final _tiempo = TextEditingController();
  final _contacto = TextEditingController();
  final _notas = TextEditingController();
  final List<TextEditingController> _reglas = [];

  String? get _idNegocio => SesionActual.instancia.idNegocio;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final id = _idNegocio;
    if (id == null) return;
    final n = await NegocioService.instancia.obtenerNegocioPorId(id);
    if (!mounted) return;
    final c = n.condiciones;
    setState(() {
      _negocio = n;
      _reembolso = CondicionesNegocio.opcionesReembolso.containsKey(c.reembolso)
          ? c.reembolso
          : CondicionesNegocio.reembolsoMismoMedio;
      _dias.text = c.diasReembolso.toString();
      _tiempo.text = c.tiempoEntrega;
      _contacto.text = c.contactoReclamos;
      _notas.text = c.notas;
      for (final r in _reglas) {
        r.dispose();
      }
      _reglas
        ..clear()
        ..addAll([for (final r in n.reglasPersonal.reglas) TextEditingController(text: r)]);
    });
  }

  @override
  void dispose() {
    for (final c in [_dias, _tiempo, _contacto, _notas, ..._reglas]) {
      c.dispose();
    }
    super.dispose();
  }

  CondicionesNegocio _leer({String version = ''}) => CondicionesNegocio(
        version: version,
        reembolso: _reembolso,
        diasReembolso: (int.tryParse(_dias.text.trim()) ?? 5).clamp(1, 60),
        tiempoEntrega: _tiempo.text.trim(),
        contactoReclamos: _contacto.text.trim(),
        notas: _notas.text.trim(),
      );

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<bool> _confirmar(String titulo, String detalle) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titulo),
          content: Text(detalle),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Cancelar'))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Guardar'))),
          ],
        ),
      ) ??
      false;

  Future<void> _guardarCondiciones() async {
    final id = _idNegocio;
    if (id == null) return;
    final ok = await _confirmar(
      tr('¿Guardar las condiciones?'),
      tr('Tus clientes tendrán que leerlas y aceptarlas de nuevo antes de su próximo pedido.'),
    );
    if (!ok) return;
    setState(() => _guardando = true);
    try {
      await CondicionesService.instancia.guardarCondiciones(id, _leer());
      await AppThemeController.instancia.cargar(idNegocio: id);
      await _cargar();
      _mensaje(tr('Condiciones guardadas. Tus clientes las aceptarán en su próximo pedido.'));
    } catch (e) {
      _mensaje(textoError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardarReglas() async {
    final id = _idNegocio;
    if (id == null) return;
    final ok = await _confirmar(
      tr('¿Guardar las reglas del personal?'),
      tr('Todo tu personal (también tú) tendrá que firmar de nuevo su acuerdo al entrar a la app.'),
    );
    if (!ok) return;
    setState(() => _guardando = true);
    try {
      await CondicionesService.instancia.guardarReglas(id, [for (final r in _reglas) r.text]);
      await AppThemeController.instancia.cargar(idNegocio: id);
      await _cargar();
      _mensaje(tr('Reglas guardadas. Tu personal firmará el acuerdo actualizado.'));
    } catch (e) {
      _mensaje(textoError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _vistaPrevia() {
    final n = _negocio;
    if (n == null) return;
    final vista = n.copyWith(condiciones: _leer(version: n.condiciones.version));
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: VistaDocumentoLegal(
              titulo: TextosLegales.tituloCondiciones(vista),
              subtitulo: tr('Así lo verán tus clientes'),
              resumen: TextosLegales.resumenCondiciones(vista),
              secciones: TextosLegales.condicionesRestaurante(vista),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Cerrar')))],
      ),
    );
  }

  Widget _tarjeta(String titulo, String detalle, List<Widget> hijos) {
    final textos = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titulo, style: textos.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(detalle, style: textos.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            ...hijos,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _negocio;
    const espacio = SizedBox(height: AppSpacing.md);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: Text(tr('Condiciones y reglas')),
      ),
      body: n == null
          ? const AppCargando()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _tarjeta(
                          tr('Condiciones para tus clientes'),
                          '${tr('Cada cliente las acepta antes de pedir.')} '
                              '${n.condiciones.version.isEmpty ? tr('Todavía usas las condiciones de base.') : '${tr('Versión vigente')}: ${n.condiciones.version}'}',
                          [
                            DropdownButtonFormField<String>(
                              initialValue: _reembolso,
                              isExpanded: true,
                              decoration: InputDecoration(labelText: tr('Cómo devuelves el dinero')),
                              items: [
                                for (final e in CondicionesNegocio.opcionesReembolso.entries)
                                  DropdownMenuItem(value: e.key, child: Text(tr(e.value))),
                              ],
                              onChanged: (v) => setState(() => _reembolso = v ?? _reembolso),
                            ),
                            espacio,
                            TextField(
                              controller: _dias,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: tr('Días hábiles para devolver el dinero'),
                                helperText: tr('Entre 1 y 60.'),
                              ),
                            ),
                            espacio,
                            TextField(
                              controller: _tiempo,
                              decoration: InputDecoration(
                                labelText: tr('Tiempo aproximado de entrega'),
                                hintText: tr('Ej. 30 a 45 minutos'),
                              ),
                            ),
                            espacio,
                            TextField(
                              controller: _contacto,
                              decoration: InputDecoration(
                                labelText: tr('Contacto para reclamos'),
                                hintText: tr('Teléfono o correo. Si lo dejas vacío, se usa el del negocio.'),
                              ),
                            ),
                            espacio,
                            TextField(
                              controller: _notas,
                              minLines: 3,
                              maxLines: 6,
                              maxLength: 1500,
                              decoration: InputDecoration(
                                labelText: tr('Reglas propias del restaurante (opcional)'),
                                hintText: tr('Ej. Los pedidos de más de 10 platos se hacen con un día de anticipación.'),
                                alignLabelWithHint: true,
                              ),
                            ),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _vistaPrevia,
                                  icon: const Icon(Icons.visibility_outlined),
                                  label: Text(tr('Vista previa')),
                                ),
                                FilledButton.icon(
                                  onPressed: _guardando ? null : _guardarCondiciones,
                                  icon: const Icon(Icons.save_outlined),
                                  label: Text(tr('Guardar condiciones')),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _tarjeta(
                          tr('Reglas internas para tu personal'),
                          '${tr('Se agregan al acuerdo que firma cada empleado.')} '
                              '${n.reglasPersonal.version.isEmpty ? '' : '${tr('Versión vigente')}: ${n.reglasPersonal.version}'}',
                          [
                            for (var i = 0; i < _reglas.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: TextField(
                                  controller: _reglas[i],
                                  maxLength: 300,
                                  decoration: InputDecoration(
                                    labelText: '${tr('Regla')} ${i + 1}',
                                    suffixIcon: IconButton(
                                      tooltip: tr('Quitar'),
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => setState(() => _reglas.removeAt(i).dispose()),
                                    ),
                                  ),
                                ),
                              ),
                            if (_reglas.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: Text(tr('Todavía no agregaste reglas. Ej. "Usar gorro y barbijo en cocina".')),
                              ),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _reglas.length >= 15
                                      ? null
                                      : () => setState(() => _reglas.add(TextEditingController())),
                                  icon: const Icon(Icons.add),
                                  label: Text(tr('Agregar regla')),
                                ),
                                FilledButton.icon(
                                  onPressed: _guardando ? null : _guardarReglas,
                                  icon: const Icon(Icons.save_outlined),
                                  label: Text(tr('Guardar reglas')),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          tr('Antes de usar estos textos en un negocio real, conviene que los revise un abogado.'),
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
