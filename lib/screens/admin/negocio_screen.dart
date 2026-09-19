import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/negocio_service.dart';

/// HU-07 — Pantalla para que el Administrador configure la información
/// general del negocio (nombre, descripción, teléfono, colores).
/// El logo se guarda como URL de imagen por ahora — subir el archivo
/// directamente a Firebase Storage queda para cuando se trabaje la
/// pantalla de catálogo/imágenes.
class NegocioScreen extends StatefulWidget {
  const NegocioScreen({super.key});

  @override
  State<NegocioScreen> createState() => _NegocioScreenState();
}

class _NegocioScreenState extends State<NegocioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  Color _colorPrimario = const Color(0xFFE65100);
  Color _colorSecundario = const Color(0xFFFFF3E0);
  bool _activo = true;

  bool _cargando = true;
  bool _guardando = false;

  static const List<Color> _paletaSugerida = [
    Color(0xFFE65100), // naranja (color base del proyecto)
    Color(0xFFD32F2F), // rojo
    Color(0xFF2E7D32), // verde
    Color(0xFF1565C0), // azul
    Color(0xFF6A1B9A), // morado
    Color(0xFF37474F), // gris oscuro
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await NegocioService.instancia.obtenerNegocio();
    _nombreCtrl.text = negocio.nombre;
    _descripcionCtrl.text = negocio.descripcion;
    _telefonoCtrl.text = negocio.telefono;
    _logoUrlCtrl.text = negocio.logoUrl;
    _colorPrimario = _colorDesdeHex(negocio.colorPrimario) ?? _colorPrimario;
    _colorSecundario =
        _colorDesdeHex(negocio.colorSecundario) ?? _colorSecundario;
    _activo = negocio.estado;
    if (mounted) setState(() => _cargando = false);
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

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    final negocio = NegocioModel(
      idNegocio: NegocioService.idNegocioPrincipal,
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      logoUrl: _logoUrlCtrl.text.trim(),
      colorPrimario: _hexDesdeColor(_colorPrimario),
      colorSecundario: _hexDesdeColor(_colorSecundario),
      estado: _activo,
    );

    try {
      await NegocioService.instancia.guardarNegocio(negocio);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos del negocio guardados.'),
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

  Future<void> _elegirColor({required bool esPrimario}) async {
    final actual = esPrimario ? _colorPrimario : _colorSecundario;
    final elegido = await showDialog<Color>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(esPrimario ? 'Color primario' : 'Color secundario'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _paletaSugerida.map((c) {
                final seleccionado = c.toARGB32() == actual.toARGB32();
                return GestureDetector(
                  onTap: () => Navigator.of(context).pop(c),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: seleccionado
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );

    if (elegido != null) {
      setState(() {
        if (esPrimario) {
          _colorPrimario = elegido;
        } else {
          _colorSecundario = elegido;
        }
      });
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _telefonoCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Datos del negocio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del negocio',
                    prefixIcon: Icon(Icons.storefront_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Ingresa el nombre del negocio'
                      : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descripcionCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de contacto',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _logoUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL del logo (opcional)',
                    helperText: 'Por ahora se guarda como link a una imagen',
                    prefixIcon: Icon(Icons.image_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Personalización visual',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SelectorColor(
                        etiqueta: 'Color primario',
                        color: _colorPrimario,
                        onTap: () => _elegirColor(esPrimario: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SelectorColor(
                        etiqueta: 'Color secundario',
                        color: _colorSecundario,
                        onTap: () => _elegirColor(esPrimario: false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Negocio activo'),
                  subtitle: const Text(
                    'Si lo desactivas, el catálogo deja de mostrarse a los clientes',
                  ),
                  value: _activo,
                  onChanged: (v) => setState(() => _activo = v),
                ),
                const SizedBox(height: 24),

                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectorColor extends StatelessWidget {
  final String etiqueta;
  final Color color;
  final VoidCallback onTap;

  const _SelectorColor({
    required this.etiqueta,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                etiqueta,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
