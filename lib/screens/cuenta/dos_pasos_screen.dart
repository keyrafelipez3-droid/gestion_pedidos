import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/idioma.dart';
import '../../models/usuario_model.dart';
import '../../services/auth_service.dart';
import '../../services/dos_pasos_service.dart';
import '../../services/sesion_actual.dart';
import '../../theme/design_tokens.dart';

/// Diálogo que pide el código de 6 dígitos de la app autenticadora.
Future<String?> pedirCodigoDosPasos(BuildContext context, {String? error}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoCodigo(error: error),
  );
}

class _DialogoCodigo extends StatefulWidget {
  final String? error;
  const _DialogoCodigo({this.error});

  @override
  State<_DialogoCodigo> createState() => _DialogoCodigoState();
}

class _DialogoCodigoState extends State<_DialogoCodigo> {
  final _ctrl = TextEditingController();
  String? _aviso;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final codigo = _ctrl.text.trim();
    if (codigo.length != 6) {
      setState(() => _aviso = tr('El código tiene 6 dígitos.'));
      return;
    }
    Navigator.of(context).pop(codigo);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _aviso ?? widget.error;
    return AlertDialog(
      icon: Icon(Icons.verified_user_outlined, color: scheme.primary, size: 36),
      title: Text(tr('Verificación en dos pasos')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('Abre tu app autenticadora y escribe el código de 6 dígitos de {app}.',
                  {'app': AppBrand.nombre}),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            CampoCodigo(controller: _ctrl, onListo: _confirmar),
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(error, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(tr('Cancelar'))),
        FilledButton(onPressed: _confirmar, child: Text(tr('Verificar'))),
      ],
    );
  }
}

/// Campo grande para escribir el código de 6 dígitos.
class CampoCodigo extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onListo;
  const CampoCodigo({super.key, required this.controller, required this.onListo});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            letterSpacing: 10,
            fontWeight: FontWeight.w700,
          ),
      decoration: const InputDecoration(counterText: '', hintText: '000000'),
      onChanged: (v) {
        if (v.length == 6) onListo();
      },
      onSubmitted: (_) => onListo(),
    );
  }
}

/// Pantalla para activar la verificación en dos pasos (desde Mi cuenta).
class DosPasosScreen extends StatelessWidget {
  const DosPasosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Verificación en dos pasos'))),
      body: AsistenteDosPasos(onListo: (_) => Navigator.of(context).pop(true)),
    );
  }
}

enum _Paso { inicio, verificarCorreo, qr, listo, noDisponible }

/// Asistente paso a paso: explica, muestra el QR y confirma el código.
class AsistenteDosPasos extends StatefulWidget {
  /// Obligatoria (personal): no se puede saltar, salvo que el servidor
  /// todavía no tenga activada la función.
  final bool obligatoria;

  /// Se llama al terminar. `true` si quedó activada; `false` si se omitió
  /// porque el servidor todavía no la permite.
  final ValueChanged<bool> onListo;

  const AsistenteDosPasos({super.key, this.obligatoria = false, required this.onListo});

  @override
  State<AsistenteDosPasos> createState() => _AsistenteDosPasosState();
}

class _AsistenteDosPasosState extends State<AsistenteDosPasos> {
  final _svc = DosPasosService.instancia;
  final _codigoCtrl = TextEditingController();

  _Paso _paso = _Paso.inicio;
  bool _ocupado = false;
  String? _error;
  String? _detalle;
  TotpSecret? _secreto;
  String? _urlQr;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _empezar({bool reintento = false}) async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final secreto = await _svc.generarSecreto();
      final url = await _svc.urlQr(secreto);
      if (!mounted) return;
      setState(() {
        _secreto = secreto;
        _urlQr = url;
        _paso = _Paso.qr;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'unverified-email':
          setState(() => _paso = _Paso.verificarCorreo);
        case 'requires-recent-login':
          if (!reintento && await _confirmarPassword()) {
            return _empezar(reintento: true);
          }
          if (mounted) setState(() => _error = AuthService.instancia.mensajeError(e.code));
        case 'network-request-failed':
        case 'too-many-requests':
          setState(() => _error = AuthService.instancia.mensajeError(e.code));
        default:
          setState(() {
            _paso = _Paso.noDisponible;
            _detalle = e.code;
          });
      }
    } catch (e) {
      if (mounted) setState(() => _error = tr('Ocurrió un error inesperado. Intenta de nuevo.'));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  /// Firebase pide haber iniciado sesión hace poco: se vuelve a pedir la
  /// contraseña.
  Future<bool> _confirmarPassword() async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Confirma tu contraseña')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          obscuringCharacter: '*',
          decoration: InputDecoration(labelText: tr('Contraseña *')),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: Text(tr('Continuar')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (password == null || password.isEmpty || !mounted) return false;
    try {
      await AuthService.instancia.reautenticar(
        password,
        pedirCodigo: (error) => pedirCodigoDosPasos(context, error: error),
      );
      return true;
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.instancia.mensajeError(e.code));
      return false;
    }
  }

  Future<void> _activar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.length != 6 || _secreto == null || _ocupado) {
      setState(() => _error = tr('El código tiene 6 dígitos.'));
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await _svc.activar(_secreto!, codigo);
      if (mounted) setState(() => _paso = _Paso.listo);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _codigoCtrl.clear();
      setState(() => _error = AuthService.instancia.mensajeError(e.code));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _enviarCorreo() async {
    setState(() => _ocupado = true);
    try {
      await _svc.enviarVerificacionCorreo();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Te enviamos un correo. Abre el enlace y vuelve aquí.')),
        ));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = AuthService.instancia.mensajeError(e.code));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _yaVerifique() async {
    setState(() => _ocupado = true);
    final ok = await _svc.correoVerificado();
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (ok) {
      _empezar();
    } else {
      setState(() => _error = tr('Todavía no vemos tu correo verificado. Abre el enlace del correo e intenta de nuevo.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._contenido(context),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado(BuildContext context, IconData icono, String titulo, String texto) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primaryContainer,
          child: Icon(icono, size: 32, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(titulo,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.sm),
        Text(texto,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _boton(String texto, VoidCallback? onPressed) => FilledButton(
        onPressed: _ocupado ? null : onPressed,
        child: _ocupado
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(texto),
      );

  List<Widget> _contenido(BuildContext context) {
    switch (_paso) {
      case _Paso.inicio:
        return [
          _encabezado(
            context,
            Icons.shield_outlined,
            tr('Protege tu cuenta'),
            widget.obligatoria
                ? tr('Por seguridad, todo el personal debe activar la verificación en dos pasos. Al iniciar sesión, además de tu contraseña, te pediremos un código de tu teléfono.')
                : tr('Además de tu contraseña, te pediremos un código de tu teléfono al iniciar sesión. Así nadie puede entrar aunque conozca tu contraseña.'),
          ),
          _PasoNumerado(1, tr('Instala una app autenticadora en tu teléfono: Google Authenticator, Microsoft Authenticator o Authy (gratis).')),
          _PasoNumerado(2, tr('Escanea con esa app el código QR que te mostraremos.')),
          _PasoNumerado(3, tr('Escribe el código de 6 dígitos que aparece en la app.')),
          const SizedBox(height: AppSpacing.lg),
          _boton(tr('Empezar'), _empezar),
        ];
      case _Paso.verificarCorreo:
        return [
          _encabezado(
            context,
            Icons.mark_email_unread_outlined,
            tr('Verifica tu correo'),
            tr('Antes de activar la verificación en dos pasos, confirma que {correo} es tu correo.',
                {'correo': FirebaseAuth.instance.currentUser?.email ?? ''}),
          ),
          _boton(tr('Enviar correo de verificación'), _enviarCorreo),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: _ocupado ? null : _yaVerifique,
            child: Text(tr('Ya lo verifiqué')),
          ),
        ];
      case _Paso.qr:
        final clave = _secreto?.secretKey ?? '';
        final agrupada = [
          for (var i = 0; i < clave.length; i += 4)
            clave.substring(i, i + 4 > clave.length ? clave.length : i + 4),
        ].join(' ');
        return [
          _encabezado(
            context,
            Icons.qr_code_2,
            tr('Escanea el código QR'),
            tr('En tu app autenticadora toca "+" o "Agregar cuenta" y escanea este código.'),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.mdAll,
              ),
              child: QrImageView(
                data: _urlQr ?? '',
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            tr('¿No puedes escanear? Escribe esta clave en la app:'),
            textAlign: TextAlign.center,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: SelectableText(
                  agrupada,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: tr('Copiar clave'),
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: clave));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(tr('Clave copiada.'))));
                },
              ),
            ],
          ),
          if (!kIsWeb && _urlQr != null)
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(_urlQr!)),
              icon: const Icon(Icons.open_in_new),
              label: Text(tr('Abrir en mi app autenticadora')),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(tr('Escribe el código de 6 dígitos que muestra la app:'), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          CampoCodigo(controller: _codigoCtrl, onListo: _activar),
          const SizedBox(height: AppSpacing.md),
          _boton(tr('Activar'), _activar),
        ];
      case _Paso.listo:
        return [
          _encabezado(
            context,
            Icons.verified_user,
            tr('¡Listo! Tu cuenta está protegida'),
            tr('Desde ahora, al iniciar sesión te pediremos el código de tu app autenticadora. No borres la cuenta de {app} de esa app.',
                {'app': AppBrand.nombre}),
          ),
          FilledButton(onPressed: () => widget.onListo(true), child: Text(tr('Continuar'))),
        ];
      case _Paso.noDisponible:
        return [
          _encabezado(
            context,
            Icons.info_outline,
            tr('Todavía no disponible'),
            tr('La verificación en dos pasos todavía no está activada en el servidor. Avisa al administrador de la plataforma.'),
          ),
          if (_detalle != null)
            Text('(${_detalle!})',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: _empezar, child: Text(tr('Reintentar'))),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => widget.onListo(false),
            child: Text(widget.obligatoria ? tr('Continuar sin activarla por ahora') : tr('Volver')),
          ),
        ];
    }
  }
}

class _PasoNumerado extends StatelessWidget {
  final int numero;
  final String texto;
  const _PasoNumerado(this.numero, this.texto);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text('$numero', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}

/// Muestra [child] solo si quien inició sesión cumple la regla de la
/// verificación en dos pasos: el personal debe tenerla activa; el cliente
/// puede usar la app igual.
class PuertaDosPasos extends StatefulWidget {
  final UsuarioModel usuario;
  final Widget child;
  const PuertaDosPasos({super.key, required this.usuario, required this.child});

  /// Si el servidor todavía no permite activarla, el personal puede seguir
  /// (solo por esta sesión) para no quedarse sin acceso.
  static bool omitidaEnEstaSesion = false;

  @override
  State<PuertaDosPasos> createState() => _PuertaDosPasosState();
}

class _PuertaDosPasosState extends State<PuertaDosPasos> {
  late Future<bool> _activa = DosPasosService.instancia.estaActiva();

  @override
  Widget build(BuildContext context) {
    if (widget.usuario.esCliente || PuertaDosPasos.omitidaEnEstaSesion) return widget.child;
    return FutureBuilder<bool>(
      future: _activa,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data == true) return widget.child;
        return AsistenteDosPasos(
          obligatoria: true,
          onListo: (activada) => setState(() {
            if (!activada) PuertaDosPasos.omitidaEnEstaSesion = true;
            _activa = DosPasosService.instancia.estaActiva();
          }),
        );
      },
    );
  }
}

/// Opción de "Mi cuenta": muestra si está activa y permite activarla
/// (y desactivarla, solo a los clientes).
class TileDosPasos extends StatefulWidget {
  const TileDosPasos({super.key});

  @override
  State<TileDosPasos> createState() => _TileDosPasosState();
}

class _TileDosPasosState extends State<TileDosPasos> {
  late Future<bool> _activa = DosPasosService.instancia.estaActiva();

  void _refrescar() => setState(() => _activa = DosPasosService.instancia.estaActiva());

  Future<void> _activar() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DosPasosScreen()));
    if (mounted) _refrescar();
  }

  Future<void> _desactivar() async {
    final ctrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('Desactivar verificación en dos pasos')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Tu cuenta quedará protegida solo con tu contraseña. Para confirmar, escribe tu contraseña.')),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: ctrl,
              autofocus: true,
              obscureText: true,
              obscuringCharacter: '*',
              decoration: InputDecoration(labelText: tr('Contraseña *')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(ctrl.text),
            child: Text(tr('Desactivar')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (password == null || password.isEmpty || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instancia.reautenticar(
        password,
        pedirCodigo: (error) => pedirCodigoDosPasos(context, error: error),
      );
      await DosPasosService.instancia.desactivar();
      messenger.showSnackBar(SnackBar(content: Text(tr('Verificación en dos pasos desactivada.'))));
    } on FirebaseAuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AuthService.instancia.mensajeError(e.code))));
    }
    if (mounted) _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final esCliente = SesionActual.instancia.esCliente;
    final semantic = context.semanticColors;
    return FutureBuilder<bool>(
      future: _activa,
      builder: (context, snapshot) {
        final activa = snapshot.data == true;
        final cargando = snapshot.connectionState == ConnectionState.waiting;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            activa ? Icons.verified_user : Icons.shield_outlined,
            color: activa ? semantic.success : null,
          ),
          title: Text(tr('Verificación en dos pasos')),
          subtitle: Text(
            cargando
                ? '…'
                : activa
                    ? (esCliente
                        ? tr('Activada con app autenticadora')
                        : tr('Activada · obligatoria para el personal'))
                    : tr('Desactivada · protege tu cuenta con un código de tu teléfono'),
          ),
          trailing: cargando
              ? null
              : activa
                  ? (esCliente
                      ? TextButton(onPressed: _desactivar, child: Text(tr('Desactivar')))
                      : null)
                  : FilledButton.tonal(onPressed: _activar, child: Text(tr('Activar'))),
        );
      },
    );
  }
}
