import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/negocio_service.dart';
import '../../theme/brand_style.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_fotos_comida.dart';
import '../../widgets/selector_imagen.dart';

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
  /// Corrección pedida por el docente: la personalización ahora es
  /// exclusiva del SuperAdmin y se hace POR negocio, no de forma global.
  final String idNegocio;
  final bool incrustada;
  const PersonalizacionScreen({super.key, required this.idNegocio, this.incrustada = false});

  @override
  State<PersonalizacionScreen> createState() => _PersonalizacionScreenState();
}

enum _TipoColor { primario, secundario, fondo }

class _PresetEstilo {
  final String nombre;
  final Color primario;
  final Color secundario;
  final String estilo;
  final String tipografia;
  final String forma;
  final Color? fondo;
  final bool oscuro;
  const _PresetEstilo(
    this.nombre,
    this.primario,
    this.secundario, {
    required this.estilo,
    required this.tipografia,
    required this.forma,
    this.fondo,
    this.oscuro = false,
  });
}

class _PersonalizacionScreenState extends State<PersonalizacionScreen> {
  // Nombres tal como los pidió Susan: nunca nombres de tipo de comida.
  // Cada preset es un punto de partida COMPLETO (color, tipografía, forma,
  // estilo de tarjetas y fondo); después el SuperAdmin ajusta lo que quiera.
  static const List<_PresetEstilo> _presets = [
    _PresetEstilo('Moderno', Color(0xFF1565C0), Color(0xFFE3F2FD),
        estilo: 'moderno', tipografia: 'sans', forma: 'redondeado'),
    _PresetEstilo('Minimal', Color(0xFFC8281A), Color(0xFFF5F5F5),
        estilo: 'minimal', tipografia: 'sans', forma: 'cuadrado'),
    _PresetEstilo('Premium', Color(0xFFC9A45C), Color(0xFF173A30),
        estilo: 'premium',
        tipografia: 'serif',
        forma: 'cuadrado',
        fondo: Color(0xFF0F2A22),
        oscuro: true),
    _PresetEstilo('Natural', Color(0xFF0E7C7B), Color(0xFFF28A3C),
        estilo: 'natural',
        tipografia: 'redondeada',
        forma: 'redondeado',
        fondo: Color(0xFFF2FAF9)),
    _PresetEstilo('Vibrante', Color(0xFFF4511E), Color(0xFFFFE08A),
        estilo: 'vibrante', tipografia: 'gruesa', forma: 'pildora'),
    _PresetEstilo('Industrial', Color(0xFFE8702A), Color(0xFF2A211B),
        estilo: 'industrial',
        tipografia: 'condensada',
        forma: 'cuadrado',
        fondo: Color(0xFF15110E),
        oscuro: true),
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
  String _estiloBase = 'moderno';
  String _tipografia = 'sans';
  String _forma = 'redondeado';

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await NegocioService.instancia.obtenerNegocioPorId(widget.idNegocio);
    _logoUrlCtrl.text = negocio.logoUrl;
    _bannerUrlCtrl.text = negocio.bannerUrl;
    _colorPrimario = _colorDesdeHex(negocio.colorPrimario) ?? _colorPrimario;
    _colorSecundario =
        _colorDesdeHex(negocio.colorSecundario) ?? _colorSecundario;
    _colorFondo = _colorDesdeHex(negocio.colorFondo);
    _modoOscuro = negocio.modoOscuro;
    _estiloBase = negocio.estiloBase;
    _tipografia = negocio.tipografia;
    _forma = negocio.formaBotones;
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
          p.secundario.toARGB32() == _colorSecundario.toARGB32() &&
          p.estilo == _estiloBase &&
          p.tipografia == _tipografia &&
          p.forma == _forma) {
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
      _colorFondo = preset.fondo;
      _modoOscuro = preset.oscuro;
      _estiloBase = preset.estilo;
      _tipografia = preset.tipografia;
      _forma = preset.forma;
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
      estiloBase: _estiloBase,
      tipografia: _tipografia,
      formaBotones: _forma,
    );

    try {
      await NegocioService.instancia.guardarNegocio(negocio);
      AppThemeController.instancia.actualizar(negocio);
      if (!mounted) return;
      setState(() => _negocioActual = negocio);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Personalización guardada.'),
          backgroundColor: context.semanticColors.success,
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
      idNegocio: widget.idNegocio,
      logoUrlCtrl: _logoUrlCtrl,
      bannerUrlCtrl: _bannerUrlCtrl,
      modoOscuro: _modoOscuro,
      onModoOscuro: (v) => setState(() => _modoOscuro = v),
      estiloBase: _estiloBase,
      onEstilo: (v) => setState(() {
        _estiloBase = v;
        _presetSeleccionado = _presetQueCoincide();
      }),
      tipografia: _tipografia,
      onTipografia: (v) => setState(() {
        _tipografia = v;
        _presetSeleccionado = _presetQueCoincide();
      }),
      forma: _forma,
      onForma: (v) => setState(() {
        _forma = v;
        _presetSeleccionado = _presetQueCoincide();
      }),
    );

    final borrador = (_negocioActual ?? const NegocioModel(idNegocio: '', nombre: 'Mi negocio'))
        .copyWith(
      logoUrl: _logoUrlCtrl.text.trim(),
      bannerUrl: _bannerUrlCtrl.text.trim(),
      colorPrimario: _hexDesdeColor(_colorPrimario),
      colorSecundario: _hexDesdeColor(_colorSecundario),
      colorFondo: _colorFondo != null ? _hexDesdeColor(_colorFondo!) : '',
      modoOscuro: _modoOscuro,
      estiloBase: _estiloBase,
      tipografia: _tipografia,
      formaBotones: _forma,
    );
    final vistaPrevia = _VistaPrevia(negocio: borrador);

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
                    child: SingleChildScrollView(
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
  final String idNegocio;
  final TextEditingController logoUrlCtrl;
  final TextEditingController bannerUrlCtrl;
  final bool modoOscuro;
  final ValueChanged<bool> onModoOscuro;
  final String estiloBase;
  final ValueChanged<String> onEstilo;
  final String tipografia;
  final ValueChanged<String> onTipografia;
  final String forma;
  final ValueChanged<String> onForma;

  const _FormularioPersonalizacion({
    required this.presets,
    required this.presetSeleccionado,
    required this.onPreset,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.colorFondo,
    required this.onElegirColor,
    required this.idNegocio,
    required this.logoUrlCtrl,
    required this.bannerUrlCtrl,
    required this.modoOscuro,
    required this.onModoOscuro,
    required this.estiloBase,
    required this.onEstilo,
    required this.tipografia,
    required this.onTipografia,
    required this.forma,
    required this.onForma,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Punto de partida', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Elige un estilo completo y luego ajusta cada detalle.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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

        Text('Tipografía', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in BrandOpciones.tipografias)
              _OpcionTipografia(
                opcion: o,
                seleccionada: o.id == tipografia,
                onTap: () => onTipografia(o.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('Forma de botones y tarjetas',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in BrandOpciones.formas)
              _OpcionForma(
                opcion: o,
                seleccionada: o.id == forma,
                onTap: () => onForma(o.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        Text('Estilo de detalles', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Sombras, bordes y títulos de las tarjetas.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in BrandOpciones.estilos)
              ChoiceChip(
                label: Text(o.nombre),
                selected: o.id == estiloBase,
                onSelected: (_) => onEstilo(o.id),
              ),
          ],
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
        SelectorImagen(
          etiqueta: 'Logo',
          controller: logoUrlCtrl,
          rutaStorage: 'negocios/$idNegocio/logo',
        ),
        const SizedBox(height: AppSpacing.md),
        SelectorImagen(
          etiqueta: 'Imagen principal / banner',
          controller: bannerUrlCtrl,
          rutaStorage: 'negocios/$idNegocio/banner',
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
              'O elige el color exacto en la paleta:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            ColorPicker(
              // Mientras no haya un color válido (ej. recién se tocó
              // "Automático" en fondo), la rueda arranca en un gris neutro;
              // no afecta nada hasta que el usuario la toque.
              pickerColor: hexValido ?? const Color(0xFF9E9E9E),
              onColorChanged: (color) {
                setState(() {
                  _hexCtrl.text = (color.toARGB32() & 0xFFFFFF)
                      .toRadixString(16)
                      .padLeft(6, '0')
                      .toUpperCase();
                });
              },
              enableAlpha: false,
              displayThumbColor: true,
              labelTypes: const [],
              pickerAreaHeightPercent: 0.6,
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

class _OpcionTipografia extends StatelessWidget {
  final EstiloOpcion opcion;
  final bool seleccionada;
  final VoidCallback onTap;

  const _OpcionTipografia({
    required this.opcion,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (titulares, _) = BrandOpciones.familias(opcion.id);
    TextStyle muestra;
    try {
      muestra = GoogleFonts.getFont(titulares, fontSize: 28, color: scheme.onSurface);
    } catch (_) {
      muestra = TextStyle(fontSize: 28, color: scheme.onSurface);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: seleccionada ? scheme.primary : scheme.outlineVariant,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aa', style: muestra),
            const SizedBox(height: 2),
            Text(opcion.nombre, style: Theme.of(context).textTheme.labelLarge),
            Text(opcion.descripcion, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _OpcionForma extends StatelessWidget {
  final EstiloOpcion opcion;
  final bool seleccionada;
  final VoidCallback onTap;

  const _OpcionForma({
    required this.opcion,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radio = switch (opcion.id) {
      'cuadrado' => 6.0,
      'pildora' => 18.0,
      _ => 12.0,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: seleccionada ? scheme.primary : scheme.outlineVariant,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(radio),
              ),
              child: Text(
                'Pedir',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(opcion.nombre, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

/// Maqueta del menú del cliente pintada con un Theme REAL construido a
/// partir de lo que el SuperAdmin está eligiendo (aún sin guardar). Como usa
/// los mismos widgets y el mismo `buildThemeFor` que la app, lo que se ve
/// acá es lo que verá el cliente.
class _VistaPrevia extends StatelessWidget {
  final NegocioModel negocio;

  const _VistaPrevia({required this.negocio});

  @override
  Widget build(BuildContext context) {
    final tema = AppThemeController.instancia.buildThemeFor(
      negocio,
      negocio.modoOscuro ? Brightness.dark : Brightness.light,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Vista previa en vivo', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Theme(data: tema, child: _MaquetaMenu(negocio: negocio)),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaquetaMenu extends StatelessWidget {
  final NegocioModel negocio;
  const _MaquetaMenu({required this.negocio});

  static const _platos = [
    ('Costilla BBQ', 'Glaseada con salsa de la casa', 78.0),
    ('Hamburguesa clásica', 'Queso fundido y papas', 52.0),
    ('Papas y ensalada', 'Para compartir', 24.0),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = context.brand;
    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.primary,
                child: Text(
                  negocio.nombre.isNotEmpty ? negocio.nombre[0].toUpperCase() : '?',
                  style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  brand.titulo(negocio.nombre),
                  style: theme.textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.person_outline, color: scheme.onSurface),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: brand.card,
            child: SizedBox(
              height: 130,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  negocio.bannerUrl.isNotEmpty
                      ? Image.network(
                          negocio.bannerUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Image.asset(fotosComida[5], fit: BoxFit.cover),
                        )
                      : Image.asset(fotosComida[5], fit: BoxFit.cover),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    bottom: AppSpacing.sm,
                    child: Text(
                      brand.titulo('Cena con vista'),
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              ChoiceChip(label: const Text('Todas'), selected: true, onSelected: (_) {}),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(label: const Text('Parrilla'), selected: false, onSelected: (_) {}),
              const SizedBox(width: AppSpacing.xs),
              ChoiceChip(label: const Text('Postres'), selected: false, onSelected: (_) {}),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _platos.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: brand.decoracionTarjeta(scheme),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: brand.pequeno,
                    child: Image.asset(
                      fotosComida[(i + 1) % fotosComida.length],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_platos[i].$1, style: theme.textTheme.titleMedium),
                        Text(
                          _platos[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bs ${_platos[i].$3.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: scheme.primary,
                    borderRadius: brand.pequeno,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.add, color: scheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton(
            onPressed: () {},
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Ver carrito (2)'), Text('Bs 130.00')],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: () {}, child: const Text('Seguir viendo el menú')),
        ],
      ),
    );
  }
}
