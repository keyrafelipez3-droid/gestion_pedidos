import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/negocio_service.dart';
import '../../theme/design_tokens.dart';

/// HU-07 — Pantalla para que el Administrador configure la información
/// general del negocio (nombre, descripción, teléfono, si está activo).
///
/// Fase 5: la personalización visual (logo, banner, colores, modo
/// claro/oscuro — HU-10) se separó a su propia pantalla
/// (`personalizacion_screen.dart`). Esta pantalla solo toca los campos de
/// identidad/contacto, pero guarda usando `copyWith` sobre el negocio ya
/// cargado para no pisar los datos de personalización que vive en el
/// mismo documento de Firestore.
class NegocioScreen extends StatefulWidget {
  /// Corrección pedida por el docente: ya no hay un negocio único — esta
  /// pantalla (ahora exclusiva del SuperAdmin) opera sobre UN negocio en
  /// particular, elegido desde la lista de negocios.
  final String idNegocio;
  final bool incrustada;
  const NegocioScreen({super.key, required this.idNegocio, this.incrustada = false});

  @override
  State<NegocioScreen> createState() => _NegocioScreenState();
}

class _NegocioScreenState extends State<NegocioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();

  NegocioModel? _negocioActual;
  bool _activo = true;

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final negocio = await NegocioService.instancia.obtenerNegocioPorId(widget.idNegocio);
    _nombreCtrl.text = negocio.nombre;
    _descripcionCtrl.text = negocio.descripcion;
    _telefonoCtrl.text = negocio.telefono;
    _activo = negocio.estado;
    if (mounted) {
      setState(() {
        _negocioActual = negocio;
        _cargando = false;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final actual = _negocioActual;
    if (actual == null) return;

    setState(() => _guardando = true);

    // copyWith conserva logo, banner, colores y modo oscuro tal cual
    // estaban — esta pantalla no los toca.
    final negocio = actual.copyWith(
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descripcionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      estado: _activo,
    );

    try {
      await NegocioService.instancia.guardarNegocio(negocio);
      AppThemeController.instancia.actualizar(negocio);
      if (!mounted) return;
      setState(() => _negocioActual = negocio);
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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _telefonoCtrl.dispose();
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
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Datos del negocio'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa el nombre del negocio'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _descripcionCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        prefixIcon: Icon(Icons.description_outlined),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    TextFormField(
                      controller: _telefonoCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono de contacto',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Negocio activo'),
                      subtitle: const Text(
                        'Si lo desactivas, el catálogo deja de mostrarse a los clientes',
                      ),
                      value: _activo,
                      onChanged: (v) => setState(() => _activo = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    FilledButton(
                      onPressed: _guardando ? null : _guardar,
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
        ),
      ),
    );
  }
}
