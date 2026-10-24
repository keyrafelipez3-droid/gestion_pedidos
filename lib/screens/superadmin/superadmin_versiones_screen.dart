import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/version_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/errores.dart';
import '../../widgets/app_cargando.dart';
import '../../widgets/etiqueta_version.dart';

/// SuperAdmin: avisa a todos los usuarios que hay una versión nueva.
///
/// Pasos al publicar una versión:
/// 1. Subir `version:` en pubspec.yaml (ej. 1.1.0+2).
/// 2. Compilar y desplegar la web y/o la APK.
/// 3. Aquí: escribir la versión, el número de compilación y el enlace de la
///    APK, y pulsar "Publicar aviso". Las apps abiertas lo ven al instante.
class SuperAdminVersionesScreen extends StatefulWidget {
  final bool incrustada;
  const SuperAdminVersionesScreen({super.key, this.incrustada = false});

  @override
  State<SuperAdminVersionesScreen> createState() => _SuperAdminVersionesScreenState();
}

class _SuperAdminVersionesScreenState extends State<SuperAdminVersionesScreen> {
  final _form = GlobalKey<FormState>();
  final _version = TextEditingController();
  final _build = TextEditingController();
  final _minimo = TextEditingController(text: '0');
  final _url = TextEditingController();
  final _notas = TextEditingController();
  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final publicada = await VersionService.instancia.leer();
      final info = await VersionService.instancia.info();
      _version.text = publicada?.version ?? info.version;
      _build.text = '${publicada?.build ?? (int.tryParse(info.buildNumber) ?? 1)}';
      _minimo.text = '${publicada?.buildMinimo ?? 0}';
      _url.text = publicada?.urlApk ?? '';
      _notas.text = publicada?.notas ?? '';
    } catch (_) {
      // Sin datos previos: el formulario queda con valores por defecto.
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    for (final c in [_version, _build, _minimo, _url, _notas]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _entero(String? v) {
    final n = int.tryParse((v ?? '').trim());
    if (n == null || n < 0) return 'Escribe un número entero';
    return null;
  }

  Future<void> _publicar() async {
    if (!_form.currentState!.validate()) return;
    final build = int.parse(_build.text.trim());
    final minimo = int.parse(_minimo.text.trim());
    if (minimo > build) {
      _mensaje('El mínimo obligatorio no puede ser mayor que la versión publicada.');
      return;
    }
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Publicar aviso?'),
        content: Text(
          minimo > 0
              ? 'Todas las instalaciones con compilación menor a $minimo dejarán de '
                  'funcionar hasta que se actualicen. Las menores a $build verán el aviso.'
              : 'Las instalaciones con compilación menor a $build verán el aviso de '
                  'actualización (pueden posponerlo).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publicar')),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _guardando = true);
    try {
      await VersionService.instancia.publicar(
        VersionPublicada(
          version: _version.text.trim(),
          build: build,
          buildMinimo: minimo,
          urlApk: _url.text.trim(),
          notas: _notas.text.trim(),
        ),
        uid: FirebaseAuth.instance.currentUser?.uid ?? '',
      );
      _mensaje('Aviso publicado. Las apps abiertas lo verán al instante.');
    } catch (e) {
      _mensaje(textoError(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.incrustada,
        title: const Text('Versiones de la app'),
      ),
      body: _cargando
          ? const AppCargando()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('Esta instalación'),
                            subtitle: const EtiquetaVersion(textAlign: TextAlign.start),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Cuando publiques una versión nueva (web o APK), completa estos '
                          'datos. Quienes tengan una versión anterior verán un aviso con el '
                          'botón "Actualizar".',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _version,
                          decoration: const InputDecoration(
                            labelText: 'Versión *',
                            helperText: 'Como en pubspec.yaml, antes del "+". Ej.: 1.1.0',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe la versión' : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _build,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Número de compilación *',
                            helperText: 'El número después del "+" en pubspec.yaml. Ej.: 2',
                          ),
                          validator: _entero,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _minimo,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Compilación mínima obligatoria',
                            helperText: 'Las anteriores a este número quedan bloqueadas. 0 = ninguna.',
                          ),
                          validator: _entero,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _url,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Enlace de descarga de la APK',
                            helperText: 'Google Drive, Play Store, etc. Vacío si solo cambió la web.',
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return null;
                            final uri = Uri.tryParse(t);
                            return (uri == null || uri.scheme != 'https') ? 'Debe empezar con https://' : null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _notas,
                          maxLines: 3,
                          maxLength: 300,
                          decoration: const InputDecoration(labelText: 'Novedades (opcional)'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: _guardando ? null : _publicar,
                          icon: const Icon(Icons.campaign_outlined),
                          label: Text(_guardando ? 'Publicando…' : 'Publicar aviso'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
