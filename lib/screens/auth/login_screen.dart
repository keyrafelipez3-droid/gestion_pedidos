import 'package:flutter/material.dart';

import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/auth_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/app_pantalla_foto.dart';
import '../../widgets/logo_caro.dart';
import '../legal/legal_screen.dart';
import 'registro_screen.dart';

/// HU-02 — Pantalla de inicio de sesión.
/// ("Iniciar sesión con mis credenciales")
///
/// Primer ejemplo de la Fase 4 (rediseño de pantallas): en ventanas anchas
/// (escritorio/tablet grande) se muestra un panel de marca a la izquierda
/// y el formulario a la derecha; en celular se mantiene el formulario
/// centrado de siempre. La lógica de autenticación no cambió en nada.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  bool _verPassword = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    final error = await AuthService.instancia.iniciarSesion(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _cargando = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
    // Si no hay error, AuthGate detecta la sesión y navega solo a Home.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ancho = MediaQuery.sizeOf(context).width;
    final esAmplio = AppBreakpoints.isExpanded(ancho);

    final formulario = _Formulario(
      formKey: _formKey,
      emailCtrl: _emailCtrl,
      passwordCtrl: _passwordCtrl,
      verPassword: _verPassword,
      cargando: _cargando,
      onTogglePassword: () => setState(() => _verPassword = !_verPassword),
      onSubmit: _iniciarSesion,
      mostrarEncabezado: !esAmplio,
    );

    if (esAmplio) {
      return Scaffold(
        body: Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<NegocioModel?>(
                valueListenable: AppThemeController.instancia.negocio,
                builder: (context, negocio, _) => _PanelMarca(
                  color: scheme.primary,
                  imagenUrl: negocio?.bannerUrl ?? '',
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: formulario,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Celular: foto de comida a pantalla completa con el formulario encima.
    return Scaffold(
      body: AppPantallaFoto(
        asset: 'assets/images/fondo_movil.jpg',
        formulario: formulario,
      ),
    );
  }
}

/// Panel de marca del login. Si el negocio subió su propia foto de banner
/// (HU-10, Personalización — el mismo campo que usa el dashboard) se usa
/// esa; si no, se usa `assets/images/login_pattern.jpg`, una ilustración
/// propia del proyecto (no una foto de stock de terceros) para que el
/// panel no se vea plano desde el primer arranque. En los dos casos se
/// le pone encima un degradado del color de marca para que el texto en
/// blanco se siga leyendo bien.
class _PanelMarca extends StatelessWidget {
  final Color color;
  final String imagenUrl;
  const _PanelMarca({required this.color, this.imagenUrl = ''});

  @override
  Widget build(BuildContext context) {
    final tieneImagenPropia = imagenUrl.trim().isNotEmpty;

    return Container(
      color: color,
      alignment: Alignment.center,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Si el negocio subió su propia foto de banner (Personalización),
          // esa es la que se usa. Si no, se usa de todas formas un fondo
          // ilustrado propio del proyecto (nunca una foto de stock de
          // terceros) en vez de dejar el panel plano — así se ve como el
          // diseño de referencia desde el primer arranque, sin depender de
          // que alguien cargue una imagen primero.
          if (tieneImagenPropia)
            Image.network(
              imagenUrl.trim(), webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => const _FondoHero(),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
            )
          else
            const _FondoHero(),
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
              mainAxisSize: MainAxisSize.max,
              children: [
                const LogoCaro(size: 168),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppBrand.nombre,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Pide, gestiona y sirve todo desde un solo lugar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo del panel de marca: si existe `assets/images/login_hero.jpg`
/// (una foto de comida del proyecto) se usa esa; si no, el patrón
/// ilustrado de siempre. Así basta con copiar la foto a esa carpeta.
class _FondoHero extends StatelessWidget {
  const _FondoHero();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/login_hero.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => Image.asset(
        'assets/images/login_pattern.jpg',
        fit: BoxFit.cover,
      ),
    );
  }
}

class _Formulario extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool verPassword;
  final bool cargando;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final bool mostrarEncabezado;

  const _Formulario({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
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
            const Center(child: LogoCaro(size: 104)),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${AppBrand.nombre} · ${AppBrand.eslogan}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
          ] else ...[
            Text(
              'Bienvenido de nuevo',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            'Inicia sesión para continuar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
            textAlign: mostrarEncabezado ? TextAlign.center : TextAlign.start,
          ),
          const SizedBox(height: AppSpacing.xl),

          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico *',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Ingresa tu correo' : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: passwordCtrl,
            obscureText: !verPassword,
            decoration: InputDecoration(
              labelText: 'Contraseña *',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  verPassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: onTogglePassword,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Ingresa tu contraseña' : null,
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
                : const Text('Iniciar sesión'),
          ),
          const SizedBox(height: AppSpacing.sm),

          TextButton(
            onPressed: cargando
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegistroScreen(),
                      ),
                    ),
            child: const Text('¿No tienes cuenta? Regístrate'),
          ),
          const SizedBox(height: AppSpacing.xs),

          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LegalScreen(tipo: TipoTextoLegal.terminos),
                  ),
                ),
                child: const Text('Términos y condiciones'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(
                      tipo: TipoTextoLegal.politicaPrivacidad,
                    ),
                  ),
                ),
                child: const Text('Política de privacidad'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
