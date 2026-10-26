import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../l10n/idioma.dart';
import '../../legal/textos_legales.dart';
import '../../models/negocio_model.dart';
import '../../models/usuario_model.dart';
import '../../models/actividad_model.dart';
import '../../services/actividad_service.dart';
import '../../services/app_theme_controller.dart';
import '../../services/negocio_service.dart';
import '../../services/sesion_actual.dart';
import '../../services/sucursal_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/formato.dart';
import '../../widgets/documento_legal.dart';
import '../legal/legal_screen.dart';

/// Antes de usar la app:
/// - El personal (Administrador, Cajero, Cocina, Repartidor) firma el
///   "Acuerdo de uso y confidencialidad del personal" (una vez por versión).
/// - El cliente acepta los términos y la política de privacidad vigentes
///   (los acepta al registrarse; si cambian, se le piden de nuevo).
/// El SuperAdmin (titular de la plataforma) no firma nada.
class PuertaAcuerdos extends StatelessWidget {
  final UsuarioModel usuario;
  final Widget child;
  const PuertaAcuerdos({super.key, required this.usuario, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UsuarioModel?>(
      valueListenable: SesionActual.instancia.usuario,
      builder: (context, enSesion, _) {
        final u = (enSesion != null && enSesion.idUsuario == usuario.idUsuario) ? enSesion : usuario;
        if (u.esSuperAdmin) return child;
        if (u.esCliente) {
          return u.terminosVersion == AppConfig.versionTerminos ? child : _AceptarTerminos(usuario: u);
        }
        // La versión que debe estar firmada depende también de las reglas
        // internas de SU restaurante: si el Administrador las cambia, todo
        // el personal firma de nuevo.
        return ValueListenableBuilder<NegocioModel?>(
          valueListenable: AppThemeController.instancia.negocio,
          builder: (context, negocio, _) {
            final mio = negocio != null && negocio.idNegocio == u.idNegocio ? negocio : null;
            final firmada = u.acuerdo?.version;
            final vigente = mio == null
                // Mientras carga el restaurante, alcanza con la versión de
                // la plataforma (se vuelve a revisar al cargar).
                ? firmada?.split('+').first == AppConfig.versionAcuerdoPersonal
                : firmada == TextosLegales.versionAcuerdo(mio);
            return vigente ? child : _FirmarAcuerdo(usuario: u);
          },
        );
      },
    );
  }
}

DocumentReference<Map<String, dynamic>> _doc(String uid) =>
    FirebaseFirestore.instance.collection('usuarios').doc(uid);

Future<void> _cerrarSesion() => ActividadService.instancia.cerrarSesion();

class _Marco extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final List<Widget> children;
  const _Marco({required this.icono, required this.titulo, required this.texto, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(icono, size: 30, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(titulo,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(texto, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: AppSpacing.lg),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- clientes

class _AceptarTerminos extends StatefulWidget {
  final UsuarioModel usuario;
  const _AceptarTerminos({required this.usuario});

  @override
  State<_AceptarTerminos> createState() => _AceptarTerminosState();
}

class _AceptarTerminosState extends State<_AceptarTerminos> {
  bool _acepta = false;
  bool _guardando = false;

  void _ver(TipoTextoLegal tipo) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(tipo: tipo)));

  Future<void> _aceptar() async {
    setState(() => _guardando = true);
    try {
      await _doc(widget.usuario.idUsuario).update({
        'terminosVersion': AppConfig.versionTerminos,
        'terminosAceptadosEn': FieldValue.serverTimestamp(),
      });
      SesionActual.instancia.usuario.value =
          widget.usuario.conAceptacion(terminosVersion: AppConfig.versionTerminos);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('No se pudo guardar. Revisa tu conexión e intenta de nuevo.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yaHabia = widget.usuario.terminosVersion != null;
    return _Marco(
      icono: Icons.gavel_outlined,
      titulo: yaHabia ? tr('Actualizamos nuestros términos') : tr('Términos y privacidad'),
      texto: yaHabia
          ? tr('Agregamos alergias, cupones, propinas, pedidos programados, datos de factura y traducción de notas. Revisa los cambios y acéptalos para seguir pidiendo.')
          : tr('Para usar la app necesitas aceptar los términos y la política de privacidad.'),
      children: [
        OutlinedButton.icon(
          onPressed: () => _ver(TipoTextoLegal.terminos),
          icon: const Icon(Icons.description_outlined),
          label: Text(tr('Leer los términos y condiciones')),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _ver(TipoTextoLegal.politicaPrivacidad),
          icon: const Icon(Icons.privacy_tip_outlined),
          label: Text(tr('Leer la política de privacidad')),
        ),
        const SizedBox(height: AppSpacing.md),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _acepta,
          onChanged: (v) => setState(() => _acepta = v ?? false),
          title: Text(tr('Leí y acepto los términos y la política de privacidad (versión {version}).',
              {'version': AppConfig.versionTerminos})),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton(
          onPressed: !_acepta || _guardando ? null : _aceptar,
          child: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('Aceptar y continuar')),
        ),
        TextButton(onPressed: _cerrarSesion, child: Text(tr('Cerrar sesión'))),
      ],
    );
  }
}

// ---------------------------------------------------------------- personal

class _FirmarAcuerdo extends StatefulWidget {
  final UsuarioModel usuario;
  const _FirmarAcuerdo({required this.usuario});

  @override
  State<_FirmarAcuerdo> createState() => _FirmarAcuerdoState();
}

class _FirmarAcuerdoState extends State<_FirmarAcuerdo> {
  late final Future<(NegocioModel?, String)> _datos = _cargarDatos();
  NegocioModel? _negocioCargado;

  /// Restaurante (con sus reglas internas) y nombre de la sucursal, para
  /// personalizar el acuerdo.
  Future<(NegocioModel?, String)> _cargarDatos() async {
    final u = widget.usuario;
    NegocioModel? negocio;
    var sucursal = '';
    try {
      if (u.idNegocio != null) {
        negocio = await NegocioService.instancia.obtenerNegocioPorId(u.idNegocio!);
      }
      if (u.idSucursal != null) {
        sucursal = (await SucursalService.instancia.obtener(u.idSucursal!))?.nombre ?? '';
      }
    } catch (_) {
      // Sin conexión: se muestra el acuerdo general.
    }
    _negocioCargado = negocio;
    return (negocio, sucursal);
  }

  String get _version => TextosLegales.versionAcuerdo(_negocioCargado);
  late final _nombre = TextEditingController(text: widget.usuario.nombre);
  final _ci = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _acepta = false;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _ci.dispose();
    super.dispose();
  }

  Future<void> _firmar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    final nombre = _nombre.text.trim();
    final ci = _ci.text.trim().toUpperCase();
    final version = _version;
    try {
      await _doc(widget.usuario.idUsuario).update({
        'acuerdoPersonal': {
          'version': version,
          'fecha': FieldValue.serverTimestamp(),
          'nombre': nombre,
          'ci': ci,
          'idNegocio': widget.usuario.idNegocio,
          'rol': widget.usuario.rol,
        },
      });
      ActividadService.instancia.registrar(
        ActividadTipo.seguridad,
        'Firmó el acuerdo del personal (versión $version, CI $ci)',
      );
      SesionActual.instancia.usuario.value = widget.usuario.conAceptacion(
        acuerdo: AcuerdoFirmado(
          version: version,
          fecha: DateTime.now(),
          nombre: nombre,
          ci: ci,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la firma. Revisa tu conexión e intenta de nuevo.')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final anterior = widget.usuario.acuerdo;
    return _Marco(
      icono: Icons.draw_outlined,
      titulo: TextosLegales.tituloAcuerdo,
      texto: anterior == null
          ? 'Antes de empezar a trabajar en la app, lee y firma este acuerdo. Solo se firma una vez.'
          : 'El acuerdo cambió desde que lo firmaste${anterior.fecha == null ? '' : ' el ${formatoFechaHora(anterior.fecha!)}'}. Léelo y fírmalo de nuevo.',
      children: [
        FutureBuilder<(NegocioModel?, String)>(
          future: _datos,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final (negocio, sucursal) = s.data ?? (null, '');
            return Container(
              constraints: const BoxConstraints(maxHeight: 420),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: AppRadius.mdAll,
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    VistaDocumentoLegal(
                      titulo: negocio == null ? 'Tu acuerdo' : 'Tu acuerdo con ${negocio.nombre}',
                      subtitulo: 'Versión ${TextosLegales.versionAcuerdo(negocio)}',
                      resumen: TextosLegales.resumenAcuerdo(negocio: negocio, rol: widget.usuario.rol),
                      secciones: TextosLegales.acuerdoPersonal(
                        negocio: negocio,
                        usuario: widget.usuario,
                        sucursal: sucursal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 3) return 'Escribe tu nombre completo';
                  if (t.length > 80) return 'Máximo 80 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _ci,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Carnet de identidad (CI) *',
                  hintText: 'Ej. 1234567 CB',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 4) return 'Escribe tu número de carnet';
                  if (t.length > 20) return 'Máximo 20 caracteres';
                  if (!RegExp(r'\d{4,}').hasMatch(t)) return 'El carnet debe tener al menos 4 números';
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _acepta,
          onChanged: (v) => setState(() => _acepta = v ?? false),
          title: const Text('Leí el acuerdo y acepto cumplirlo. Entiendo que esta firma electrónica queda registrada.'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: !_acepta || _guardando ? null : _firmar,
          icon: _guardando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.draw_outlined),
          label: const Text('Firmar y continuar'),
        ),
        TextButton(onPressed: _cerrarSesion, child: const Text('Cerrar sesión')),
      ],
    );
  }
}
