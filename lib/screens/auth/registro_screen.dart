import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contrasena.dart';
import '../../widgets/app_pantalla_foto.dart';
import '../../widgets/campo_telefono.dart';
import '../../widgets/logo_caro.dart';
import '../legal/legal_screen.dart';

/// HU-01 — Pantalla de registro para Clientes.
/// ("Registrarme con mis datos básicos")
///
/// Mismo tratamiento responsive que login_screen.dart (Fase 4): en
/// ventanas anchas se muestra un panel de marca junto al formulario; en
/// celular el formulario queda centrado como antes. Toda la lógica de
/// registro (_registrar, validadores, controllers) se mantiene igual.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _cargando = false;
  bool _verPassword = false;
  bool _aceptaTerminos = false;
  bool _errorTerminos = false;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    // Oculta el teclado y valida el formulario.
    FocusScope.of(context).unfocus();
    final formularioValido = _formKey.currentState!.validate();
    if (!_aceptaTerminos) {
      setState(() => _errorTerminos = true);
      return;
    }
    if (!formularioValido) return;

    setState(() => _cargando = true);

    final error = await AuthService.instancia.registrarCliente(
      nombre: _nombreCtrl.text,
      email: _emailCtrl.text,
      telefono: _telefonoCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error),
      );
      return;
    }

    // Si no hubo error, AuthGate detecta la nueva sesión automáticamente
    // y navega a Home — solo cerramos esta pantalla si quedó algo encima.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ancho = MediaQuery.sizeOf(context).width;
    final esAmplio = AppBreakpoints.isExpanded(ancho);

    final formulario = _Formulario(
      formKey: _formKey,
      nombreCtrl: _nombreCtrl,
      emailCtrl: _emailCtrl,
      telefonoCtrl: _telefonoCtrl,
      passwordCtrl: _passwordCtrl,
      confirmarCtrl: _confirmarCtrl,
      verPassword: _verPassword,
      cargando: _cargando,
      onTogglePassword: () => setState(() => _verPassword = !_verPassword),
      onSubmit: _registrar,
      mostrarEncabezado: !esAmplio,
      aceptaTerminos: _aceptaTerminos,
      errorTerminos: _errorTerminos,
      onCambiarTerminos: (v) => setState(() {
        _aceptaTerminos = v;
        if (v) _errorTerminos = false;
      }),
    );

    if (esAmplio) {
      return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: BotonIdioma(),
        ),
        body: Row(
          children: [
            Expanded(child: _PanelMarca(color: scheme.primary)),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: formulario,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Celular: foto de comida a pantalla completa con el formulario encima
    // y una barra transparente con la flecha de regreso.
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(tr('Crear cuenta')),
        actions: const [BotonIdioma(color: Colors.white)],
      ),
      body: AppPantallaFoto(
        asset: 'assets/images/comida_terraza.jpg',
        formulario: formulario,
        conAppBar: true,
      ),
    );
  }
}

class _PanelMarca extends StatelessWidget {
  final Color color;
  const _PanelMarca({required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Foto de comida de fondo (si faltara el archivo, queda el color
        // de marca de siempre).
        ColoredBox(color: color),
        Image.asset(
          'assets/images/comida_steak.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.45),
                Colors.black.withValues(alpha: 0.80),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const LogoCaro(size: 140),
              const SizedBox(height: AppSpacing.lg),
              Text(
                tr('Únete a {nombre}', {'nombre': AppBrand.nombre}),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                tr('Crea tu cuenta y empieza a pedir en segundos.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Formulario extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombreCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController telefonoCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmarCtrl;
  final bool verPassword;
  final bool cargando;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final bool mostrarEncabezado;
  final bool aceptaTerminos;
  final bool errorTerminos;
  final ValueChanged<bool> onCambiarTerminos;

  const _Formulario({
    required this.formKey,
    required this.nombreCtrl,
    required this.emailCtrl,
    required this.telefonoCtrl,
    required this.passwordCtrl,
    required this.confirmarCtrl,
    required this.verPassword,
    required this.cargando,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.mostrarEncabezado,
    required this.aceptaTerminos,
    required this.errorTerminos,
    required this.onCambiarTerminos,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mostrarEncabezado) ...[
            Icon(Icons.person_add_alt_1, size: 64, color: scheme.primary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              tr('Regístrate'),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ] else ...[
            Text(
              tr('Regístrate'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            tr('Crea tu cuenta de cliente para hacer pedidos.'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: mostrarEncabezado ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: AppSpacing.xl),

          TextFormField(
            controller: nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: tr('Nombre completo *'),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? tr('Ingresa tu nombre') : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: tr('Correo electrónico *'),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return tr('Ingresa tu correo');
              }
              final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!regex.hasMatch(v.trim())) {
                return tr('Correo no válido');
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          CampoTelefono(
            controller: telefonoCtrl,
            obligatorio: true,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: passwordCtrl,
            obscureText: !verPassword,
            obscuringCharacter: '*',
            decoration: InputDecoration(
              labelText: tr('Contraseña *'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  verPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            validator: (v) => validarContrasena(v),
          ),
          MedidorContrasena(controller: passwordCtrl),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: confirmarCtrl,
            obscureText: !verPassword,
            obscuringCharacter: '*',
            decoration: InputDecoration(
              labelText: tr('Confirmar contraseña *'),
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => (v != passwordCtrl.text)
                ? tr('Las contraseñas no coinciden')
                : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSpacing.md),

          // Consentimiento expreso: sin aceptar no se crea la cuenta.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: aceptaTerminos,
                onChanged: cargando ? null : (v) => onCambiarTerminos(v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(tr('Acepto los ')),
                      _EnlaceLegal(
                        texto: tr('Términos y condiciones'),
                        tipo: TipoTextoLegal.terminos,
                      ),
                      Text(tr(' y la ')),
                      _EnlaceLegal(
                        texto: tr('Política de privacidad'),
                        tipo: TipoTextoLegal.politicaPrivacidad,
                      ),
                      const Text(' *'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (errorTerminos)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: AppSpacing.xs),
              child: Text(
                tr('Debes aceptar para crear tu cuenta'),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          FilledButton(
            onPressed: cargando ? null : onSubmit,
            child: cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(tr('Crear cuenta')),
          ),
          const SizedBox(height: AppSpacing.sm),

          TextButton(
            onPressed: cargando ? null : () => Navigator.of(context).pop(),
            child: Text(tr('Ya tengo una cuenta')),
          ),
        ],
      ),
    );
  }
}

/// Texto que abre la política de privacidad o los términos.
class _EnlaceLegal extends StatelessWidget {
  final String texto;
  final TipoTextoLegal tipo;
  const _EnlaceLegal({required this.texto, required this.tipo});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LegalScreen(tipo: tipo)),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
