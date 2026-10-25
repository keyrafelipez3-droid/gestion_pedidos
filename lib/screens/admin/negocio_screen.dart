import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/negocio_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/selector_imagen.dart';
import '../../widgets/campo_telefono.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/codigo_restaurante.dart';

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
  final _qrPagoUrlCtrl = TextEditingController();
  final _razonSocialCtrl = TextEditingController();
  final _nitCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _ciudadCtrl = TextEditingController();
  final _correoContactoCtrl = TextEditingController();

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
    _qrPagoUrlCtrl.text = negocio.qrPagoUrl;
    _razonSocialCtrl.text = negocio.razonSocial;
    _nitCtrl.text = negocio.nit;
    _direccionCtrl.text = negocio.direccion;
    _ciudadCtrl.text = negocio.ciudad;
    _correoContactoCtrl.text = negocio.correoContacto;
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
      qrPagoUrl: _qrPagoUrlCtrl.text.trim(),
      razonSocial: _razonSocialCtrl.text.trim(),
      nit: _nitCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      ciudad: _ciudadCtrl.text.trim(),
      correoContacto: _correoContactoCtrl.text.trim(),
      estado: _activo,
    );

    try {
      await NegocioService.instancia.guardarNegocio(negocio);
      AppThemeController.instancia.actualizar(negocio);
      if (!mounted) return;
      setState(() => _negocioActual = negocio);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Datos del negocio guardados.'),
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
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _telefonoCtrl.dispose();
    _qrPagoUrlCtrl.dispose();
    _razonSocialCtrl.dispose();
    _nitCtrl.dispose();
    _direccionCtrl.dispose();
    _ciudadCtrl.dispose();
    _correoContactoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(
        body: AppCargando(),
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
                    // Código y enlace para compartir con los clientes.
                    TarjetaCodigoNegocio(idNegocio: widget.idNegocio),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del negocio *',
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

                    CampoTelefono(
                      controller: _telefonoCtrl,
                      etiqueta: 'Teléfono de contacto',
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      'Datos legales y de contacto',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tus clientes los verán en la ficha del negocio, junto '
                      'con la forma de presentar un reclamo. Completa solo '
                      'lo que corresponda a tu negocio.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextFormField(
                      controller: _razonSocialCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Razón social',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _nitCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'NIT',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _direccionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _ciudadCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _correoContactoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo de contacto',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)
                            ? null
                            : 'Correo no válido';
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    Text(
                      'QR de pago',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Los clientes lo verán en el checkout al elegir pagar '
                      'con QR, para escanearlo antes de subir su comprobante.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SelectorImagen(
                      etiqueta: 'QR de pago (opcional)',
                      controller: _qrPagoUrlCtrl,
                      rutaStorage: 'negocios/${widget.idNegocio}/qrPago',
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Solo el SuperAdmin activa o desactiva un negocio (las
                    // reglas de Firestore no se lo permiten al Administrador).
                    if (SesionActual.instancia.esSuperAdmin) ...[
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
                    ],

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
