import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../l10n/idioma.dart';
import '../../services/sesion_actual.dart';
import '../../services/solicitudes_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_contenido_centrado.dart';

/// Un cliente con restaurante pide unirse a la plataforma. El SuperAdmin
/// revisa la solicitud; si la aprueba, la cuenta pasa a ser la del
/// Administrador del negocio nuevo.
class RegistrarNegocioScreen extends StatefulWidget {
  const RegistrarNegocioScreen({super.key});

  @override
  State<RegistrarNegocioScreen> createState() => _RegistrarNegocioScreenState();
}

class _RegistrarNegocioScreenState extends State<RegistrarNegocioScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _ciudad = TextEditingController();
  final _telefono = TextEditingController();
  final _nit = TextEditingController();
  final _mensaje = TextEditingController();
  late final String _uid = SesionActual.instancia.actual?.idUsuario ?? '';
  late final Stream<SolicitudNegocio?> _stream = SolicitudesService.instancia.streamMia(_uid);
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _telefono.text = SesionActual.instancia.actual?.telefono ?? '';
  }

  @override
  void dispose() {
    for (final c in [_nombre, _ciudad, _telefono, _nit, _mensaje]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    final u = SesionActual.instancia.actual;
    if (u == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _enviando = true);
    try {
      await SolicitudesService.instancia.enviar(SolicitudNegocio(
        idUsuario: u.idUsuario,
        nombreNegocio: _nombre.text.trim(),
        ciudad: _ciudad.text.trim(),
        telefono: _telefono.text.trim(),
        nit: _nit.text.trim(),
        mensaje: _mensaje.text.trim(),
        nombreSolicitante: u.nombre,
        correo: u.email,
      ));
      messenger.showSnackBar(SnackBar(content: Text(tr('Solicitud enviada. Te avisaremos cuando la revisemos.'))));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(tr('No se pudo enviar la solicitud. Intenta de nuevo.'))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _irAlPanel() async {
    // Se vuelve a leer la cuenta: ahora es Administrador del negocio.
    await SesionActual.instancia.cargar();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  String? _requerido(String? v, String mensaje) => (v ?? '').trim().isEmpty ? mensaje : null;

  Widget _formulario() {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Únete a {app} y recibe pedidos de tus clientes.', {'app': AppConfig.nombrePlataforma}),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            tr('Al aprobarse, tu cuenta pasará a ser la del Administrador del negocio.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _nombre,
            maxLength: 80,
            decoration: InputDecoration(labelText: tr('Nombre del negocio *')),
            validator: (v) => (v ?? '').trim().length < 3 ? tr('Escribe el nombre del negocio') : null,
          ),
          TextFormField(
            controller: _ciudad,
            maxLength: 60,
            decoration: InputDecoration(labelText: tr('Ciudad *')),
            validator: (v) => _requerido(v, tr('Escribe la ciudad')),
          ),
          TextFormField(
            controller: _telefono,
            maxLength: 20,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: tr('Teléfono de contacto *')),
            validator: (v) => _requerido(v, tr('Escribe un teléfono')),
          ),
          TextFormField(
            controller: _nit,
            maxLength: 20,
            decoration: InputDecoration(labelText: tr('NIT (opcional)')),
          ),
          TextFormField(
            controller: _mensaje,
            maxLength: 500,
            maxLines: 3,
            decoration: InputDecoration(labelText: tr('Cuéntanos sobre tu negocio (opcional)')),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: const Icon(Icons.send),
            label: Text(tr('Enviar solicitud')),
          ),
        ],
      ),
    );
  }

  Widget _estado(SolicitudNegocio s) {
    final scheme = Theme.of(context).colorScheme;
    final (icono, color, titulo) = switch (s.estado) {
      SolicitudNegocio.aprobada => (Icons.verified, Colors.green, tr('¡Tu negocio fue aprobado!')),
      SolicitudNegocio.rechazada => (Icons.info_outline, scheme.error, tr('Tu solicitud no fue aprobada')),
      _ => (Icons.hourglass_top, scheme.primary, tr('Tu solicitud está en revisión')),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icono, size: 64, color: color),
        const SizedBox(height: AppSpacing.md),
        Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(tr('Negocio: {nombre}', {'nombre': s.nombreNegocio}), textAlign: TextAlign.center),
        if (s.estado == SolicitudNegocio.aprobada) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            tr('Ya eres Administrador de {nombre}. Entra a tu panel para configurarlo.', {'nombre': s.nombreNegocio}),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _irAlPanel,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(tr('Ir a mi panel')),
          ),
        ],
        if (s.estado == SolicitudNegocio.rechazada) ...[
          if (s.motivo.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(tr('Motivo: {motivo}', {'motivo': s.motivo}), textAlign: TextAlign.center),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => SolicitudesService.instancia.retirar(_uid),
            child: Text(tr('Enviar otra solicitud')),
          ),
        ],
        if (s.estado == SolicitudNegocio.pendiente) ...[
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(
            onPressed: () => SolicitudesService.instancia.retirar(_uid),
            child: Text(tr('Cancelar solicitud')),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Registrar mi negocio'))),
      body: AppContenidoCentrado(
        child: StreamBuilder<SolicitudNegocio?>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [snap.data == null ? _formulario() : _estado(snap.data!)],
            );
          },
        ),
      ),
    );
  }
}
