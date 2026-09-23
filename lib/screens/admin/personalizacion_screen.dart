import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';

/// HU-10 — "Personalizar la apariencia del negocio" (Fase 5).
///
/// Antes vivía mezclada con los datos de contacto en `negocio_screen.dart`;
/// ahora tiene su propia pantalla con estilos predefinidos, selección de
/// colores, logo/banner (como URL, igual que antes) y modo claro/oscuro,
/// más una vista previa en vivo. Todo se sigue guardando en el mismo
/// documento `negocios/principal` de siempre, a través de
/// `NegocioService`/`AppThemeController` — no se creó ninguna colección ni
/// mecanismo nuevo, solo se ampliaron los campos ya explicados en
/// `negocio_model.dart`.
class PersonalizacionScreen extends StatefulWidget {
  final bool incrustada;
  const PersonalizacionScreen({super.key, this.incrustada = false});

  @override
  State<PersonalizacionScreen> createState() => _PersonalizacionScreenState();
}

enum _TipoColor { primario, secundario, fondo }

class _PresetEstilo {
  final String nombre;
  final Color primario;
  final Color secundario;
  const _PresetEstilo(this.nombre, this.primario, this.secundario);
}

class _PersonalizacionScreenState extends State<PersonalizacionScreen> {
  // Nombres tal como los pidió Susan: nunca nombres de tipo de comida.
  static const List<_PresetEstilo> _presets = [
    _PresetEstilo('Moderno', Color(0xFF1565C0), Color(0xFFE3F2FD)),
    _PresetEstilo('Minimal', Color(0xFF212121), Color(0xFFF5F5F5)),
    _PresetEstilo('Premium', Color(0xFF6A1B9A), Color(0xFFF3E5F5)),
    _PresetEstilo('Natural', Color(0xFF2E7D32), Color(0xFFE8F5E9)),
    _PresetEstilo('Vibrante', Color(0xFFF4511E), Color(0xFFFFF3E0)),
    _PresetEstilo('Industrial', Color(0xFF37474F), Color(0xFFECEFF1)),
  ];

  static const List<Color> _paletaColores = [
    Color(0xFFFF7A00),
    Color(0xFFD32F2F),
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF37474F),
    Color(0xFFF4511E),
    Color(0xFF212121),
  ];

  final _logoUrlCtrl = TextEditingController();
  final _bannerUrlCtrl = TextEditingController();

  NegocioModel? _negocioActual;
  Color _colorPrimario = const Color(0xFFFF7A00);
  Color _colorSecundario = const Color(0xFFFFF3E0);
  Color? _colorFondo; // null = usar el fondo automático del tema
  bool _modoOscuro = false;
  String? _presetSeleccionado;

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await NegocioService.instancia.obtenerNegocio();
    _logoUrlCtrl.text = negocio.logoUrl;
    _bannerUrlCtrl.text = negocio.bannerUrl;
    _colorPrimario = _colorDesdeHex(negocio.colorPrimario) ?? _colorPrimario;
    _colorSecundario =
        _colorDesdeHex(negocio.colorSecundario) ?? _colorSecundario;
    _colorFondo = _colorDesdeHex(negocio.colorFondo);
    _modoOscuro = negocio.modoOscuro;
    _presetSeleccionado = _presetQueCoincide();
    if (mounted) {
      setState(() {
        _negocioActual = negocio;
        _cargando = false;
      });
    }
  }

  String? _presetQueCoincide() {
    for (final p in _presets) {
      if (p.primario.toARGB32() == _colorPrimario.toARGB32() &&
          p.secundario.toARGB32() == _colorSecundario.toARGB32()) {
        return p.nombre;
      }
    }
    return null;
  }

  Color? _colorDesdeHex(String hex) {
    final limpio = hex.replaceAll('#', '');
    if (limpio.length != 6) return null;
    final valor = int.tryParse('FF$limpio', radix: 16);
    return valor != null ? Color(valor) : null;
  }

  String _hexDesdeColor(Color c) {
    return '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  void _aplicarPreset(_PresetEstilo preset) {
    setState(() {
      _colorPrimario = preset.primario;
      _colorSecundario = preset.secundario;
      _presetSeleccionado = preset.nombre;
    });
  }

  Future<void> _elegirColor(_TipoColor tipo) async {
    final actual = switch (tipo) {
      _TipoColor.primario => _colorPrimario,
      _TipoColor.secundario => _colorSecundario,
      _TipoColor.fondo => _colorFondo,
    };
    final titulo = switch (tipo) {
      _TipoColor.primario => 'Color primario',
      _TipoColor.secundario => 'Color secundario',
      _TipoColor.fondo => 'Color de fondo',
    };

    final elegido = await showDialog<Color?>(
      context: context,
      // Para "fondo", tocar afuera del diálogo debe CANCELAR (no tocar
      // nada), así que se desactiva el cierre por barrera y la única forma
      // de volver a "Automático" es tocando ese swatch a propósito.
      barrierDismissible: tipo != _TipoColor.fondo,
      builder: (context) => _DialogoColor(
        titulo: titulo,
        colorActual: actual,
        permitirAutomatico: tipo == _TipoColor.fondo,
        paleta: _paletaColores,
      ),
    );

    if (!mounted) return;
    // Con barrierDismissible=false para "fondo", un resultado null acá
    // solo puede venir de tocar el swatch "Automático" a propósito, nunca
    // de cerrar el diálogo sin elegir.
    if (tipo == _TipoColor.fondo) {
      setState(() {
        _colorFondo = elegido;
        _presetSeleccionado = null;
      });
    } else if (elegido != null) {
      setState(() {
        if (tipo == _TipoColor.primario) {
          _colorPrimario = elegido;
        } else {
          _colorSecundario = elegido;
        }
        _presetSeleccionado = _presetQueCoincide();
      });
    }
  }

  Future<void> _guardar() async {
    final actual = _negocioActual;
    if (actual == null) return;

    setState(() => _guardando = true);

    final negocio = actual.copyWith(
      logoUrl: _logoUrlCtrl.text.trim(),
      bannerUrl: _bannerUrlCtrl.text.trim(),
      colorPrimario: _hexDesdeColor(_colorPrimario),
      colorSecundario: _hexDesdeColor(_colorSecundario),
      colorFondo: _colorFondo != null ? _hexDesdeColor(_colorFondo!) : '',
      modoOscuro: _modoOscuro,
    );

    try {
      await NegocioService.instancia.guardarNegocio(negocio);
      AppThemeController.instancia.actualizar(negocio);
      if (!mounted) return;
      setState(() => _negocioActual = negocio);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personalización guardada.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _logoUrlCtrl.dispose();
    _bannerUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final esAmplio = AppBreakpoints.isExpanded(ancho);

    final formulario = _FormularioPersonalizacion(
      presets: _presets,
      presetSeleccionado: _presetSeleccionado,
      onPreset: _aplicarPreset,
      colorPrimario: _colorPrimario,
      colorSecundario: _colorSecundario,
      colorFondo: _colorFondo,
      onElegirColor: _elegirColor,
      logoUrlCtrl: _logoUrlCtrl,
      bannerUrlCtrl: _bannerUrlCtrl,
      modoOscuro: _modoOscuro,
      onModoOscuro: (v) => setState(() => _modoOscuro = v),
    );

    final vistaPrevia = _VistaPrevia(
      colorPrimario: _colorPrimario,
      colorSecundario: _colorSecundario,
      colorFondo: _colorFondo,
      modoOscuro: _modoOscuro,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Personalización'),
      ),
      body: SafeArea(
        child: esAmplio
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: formulario,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: vistaPrevia,
                    ),
                  ),
                ],
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    formulario,
                    const SizedBox(height: AppSpacing.lg),
                    vistaPrevia,
                  ],
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _guardando ? null : _guardar,
            child: _guardando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar cambios'),
          ),
        ),
      ),
    );
  }
}

class _FormularioPersonalizacion extends StatelessWidget {
  final List<_PresetEstilo> presets;
  final String? presetSeleccionado;
  final ValueChanged<_PresetEstilo> onPreset;
  final Color colorPrimario;
  final Color colorSecundario;
  final Color? colorFondo;
  final ValueChanged<_TipoColor> onElegirColor;
  final TextEditingController logoUrlCtrl;
  final TextEditingController bannerUrlCtrl;
  final bool modoOscuro;
  final ValueChanged<bool> onModoOscuro;

  const _FormularioPersonalizacion({
    required this.presets,
    required this.presetSeleccionado,
    required this.onPreset,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.colorFondo,
    required this.onElegirColor,
    required this.logoUrlCtrl,
    required this.bannerUrlCtrl,
    required this.modoOscuro,
    required this.onModoOscuro,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Estilo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: presets.map((p) {
            final seleccionado = p.nombre == presetSeleccionado;
            return _TarjetaPreset(
              preset: p,
              seleccionado: seleccionado,
              onTap: () => onPreset(p),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('Colores', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            _SelectorColor(
              etiqueta: 'Primario',
              color: colorPrimario,
              onTap: () => onElegirColor(_TipoColor.primario),
            ),
            _SelectorColor(
              etiqueta: 'Secundario',
              color: colorSecundario,
              onTap: () => onElegirColor(_TipoColor.secundario),
            ),
            _SelectorColor(
              etiqueta: 'Fondo',
              color: colorFondo,
              subtitulo: colorFondo == null ? 'Automático' : null,
              onTap: () => onElegirColor(_TipoColor.fondo),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('Imágenes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        TextFormField(
          controller: logoUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'Logo (URL de la imagen)',
            helperText: 'Por ahora se guarda como link a una imagen',
            prefixIcon: Icon(Icons.image_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: bannerUrlCtrl,
          decoration: const InputDecoration(
            labelText: 'Imagen principal / banner (URL)',
            helperText: 'Se usará como portada del negocio',
            prefixIcon: Icon(Icons.panorama_outlined),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('Modo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: SwitchListTile(
            secondary: Icon(
              modoOscuro ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            ),
            title: Text(modoOscuro ? 'Oscuro' : 'Claro'),
            subtitle: const Text('Modo de color de toda la aplicación'),
            value: modoOscuro,
            onChanged: onModoOscuro,
          ),
        ),
      ],
    );
  }
}

class _TarjetaPreset extends StatelessWidget {
  final _PresetEstilo preset;
  final bool seleccionado;
  final VoidCallback onTap;

  const _TarjetaPreset({
    required this.preset,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: seleccionado ? preset.primario : scheme.outlineVariant,
            width: seleccionado ? 2 : 1,
          ),
          color: seleccionado
              ? preset.primario.withValues(alpha: 0.08)
              : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Punto(color: preset.primario),
                const SizedBox(width: 4),
                _Punto(color: preset.secundario),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              preset.nombre,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            if (seleccionado)
              Icon(Icons.check_circle, size: 16, color: preset.primario),
          ],
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  final Color color;
  const _Punto({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}

class _SelectorColor extends StatelessWidget {
  final String etiqueta;
  final Color? color;
  final String? subtitulo;
  final VoidCallback onTap;

  const _SelectorColor({
    required this.etiqueta,
    required this.color,
    required this.onTap,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
              child: color == null
                  ? const Icon(Icons.block, size: 16, color: Colors.black38)
                  : null,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(etiqueta, style: Theme.of(context).textTheme.bodySmall),
                  if (subtitulo != null)
                    Text(
                      subtitulo!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de selección de color: paleta rápida de swatches + un campo de
/// hex para pegar el código EXACTO (ej. el que da Figma al copiar un
/// color), que es lo que en la práctica hace falta cuando el color de
/// marca tiene que calzar pixel a pixel con un diseño ya aprobado.
class _DialogoColor extends StatefulWidget {
  final String titulo;
  final Color? colorActual;
  final bool permitirAutomatico;
  final List<Color> paleta;

  const _DialogoColor({
    required this.titulo,
    required this.colorActual,
    required this.permitirAutomatico,
    required this.paleta,
  });

  @override
  State<_DialogoColor> createState() => _DialogoColorState();
}

class _DialogoColorState extends State<_DialogoColor> {
  late final TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.colorActual;
    _hexCtrl = TextEditingController(
      text: c == null
          ? ''
          : (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  Color? _colorDesdeTexto() {
    final limpio = _hexCtrl.text.trim().replaceAll('#', '');
    if (limpio.length != 6) return null;
    final valor = int.tryParse('FF$limpio', radix: 16);
    return valor == null ? null : Color(valor);
  }

  @override
  Widget build(BuildContext context) {
    final hexValido = _colorDesdeTexto();
    return AlertDialog(
      title: Text(widget.titulo),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (widget.permitirAutomatico)
                  _SwatchAutomatico(seleccionado: widget.colorActual == null),
                ...widget.paleta.map((c) {
                  final seleccionado = widget.colorActual != null &&
                      c.toARGB32() == widget.colorActual!.toARGB32();
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: seleccionado
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'O escribe el código exacto (ej. de Figma):',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _hexCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 7,
                    decoration: InputDecoration(
                      prefixText: '#',
                      counterText: '',
                      hintText: 'FF7A00',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: hexValido ?? Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black26),
                          ),
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (hexValido != null) Navigator.of(context).pop(hexValido);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: hexValido == null
                      ? null
                      : () => Navigator.of(context).pop(hexValido),
                  child: const Text('Usar'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(widget.colorActual),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

class _SwatchAutomatico extends StatelessWidget {
  final bool seleccionado;
  const _SwatchAutomatico({required this.seleccionado});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: seleccionado ? Colors.black : Colors.black26,
            width: seleccionado ? 3 : 1,
          ),
        ),
        child: const Icon(Icons.block, size: 20, color: Colors.black38),
      ),
    );
  }
}

/// Mini maqueta de la app con los colores todavía sin guardar, para que el
/// Administrador vea el efecto antes de tocar "Guardar cambios".
class _VistaPrevia extends StatelessWidget {
  final Color colorPrimario;
  final Color colorSecundario;
  final Color? colorFondo;
  final bool modoOscuro;

  const _VistaPrevia({
    required this.colorPrimario,
    required this.colorSecundario,
    required this.colorFondo,
    required this.modoOscuro,
  });

  @override
  Widget build(BuildContext context) {
    final fondoBase = modoOscuro ? const Color(0xFF1C1B1F) : Colors.white;
    final fondo = colorFondo ?? fondoBase;
    final textoSobreFondo = ThemeData.estimateBrightnessForColor(fondo) ==
            Brightness.dark
        ? Colors.white
        : Colors.black87;
    final textoSobrePrimario =
        ThemeData.estimateBrightnessForColor(colorPrimario) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Vista previa', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: AppRadius.mdAll,
                border: Border.all(color: Colors.black12),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colorPrimario,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storefront, color: textoSobrePrimario, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Mi negocio',
                          style: TextStyle(
                            color: textoSobrePrimario,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: colorSecundario,
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Text(
                      'Producto de ejemplo',
                      style: TextStyle(
                        color: ThemeData.estimateBrightnessForColor(
                                  colorSecundario,
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Así se vería un texto normal sobre el fondo elegido.',
                    style: TextStyle(color: textoSobreFondo),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colorPrimario,
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Text(
                        'Confirmar pedido',
                        style: TextStyle(
                          color: textoSobrePrimario,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              modoOscuro ? 'Modo oscuro' : 'Modo claro',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
