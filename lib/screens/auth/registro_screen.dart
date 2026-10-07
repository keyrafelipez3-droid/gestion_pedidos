import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';

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
    if (!_formKey.currentState!.validate()) return;

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
        SnackBar(content: Text(error), backgroundColor: Colors.red),
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
    );

    if (esAmplio) {
      return Scaffold(
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

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: formulario,
            ),
          ),
        ),
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
                color.withValues(alpha: 0.30),
                color.withValues(alpha: 0.72),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_add_alt_1, size: 96, color: Colors.white),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Únete a Gestión de Pedidos',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Crea tu cuenta y empieza a pedir en segundos.',
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
              'Regístrate',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ] else ...[
            Text(
              'Regístrate',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            'Crea tu cuenta de cliente para hacer pedidos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: mostrarEncabezado ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: AppSpacing.xl),

          TextFormField(
            controller: nombreCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Ingresa tu correo';
              }
              final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!regex.hasMatch(v.trim())) {
                return 'Correo no válido';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: telefonoCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Ingresa tu teléfono'
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: passwordCtrl,
            obscureText: !verPassword,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  verPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: confirmarCtrl,
            obscureText: !verPassword,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (v) => (v != passwordCtrl.text)
                ? 'Las contraseñas no coinciden'
                : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: AppSpacing.lg),

          FilledButton(
            onPressed: cargando ? null : onSubmit,
            child: cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear cuenta'),
          ),
          const SizedBox(height: AppSpacing.sm),

          TextButton(
            onPressed: cargando ? null : () => Navigator.of(context).pop(),
            child: const Text('Ya tengo una cuenta'),
          ),
        ],
      ),
    );
  }
}
