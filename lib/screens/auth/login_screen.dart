import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../l10n/tamano_texto.dart';
import '../../models/negocio_model.dart';
import '../../services/app_theme_controller.dart';
import '../../services/auth_service.dart';
import '../../services/codigo_negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/animaciones_marca.dart';
import '../../widgets/codigo_restaurante.dart';
import '../../widgets/etiqueta_version.dart';
import '../../widgets/logo_caro.dart';
import '../cuenta/dos_pasos_screen.dart';
import '../legal/legal_screen.dart';
import 'registro_screen.dart';

/// HU-02 — Pantalla de inicio de sesión.
/// ("Iniciar sesión con mis credenciales")
///
/// Entrada con animación (estilo "Slate"): fondo negro, el logo aparece,
/// "Nami" se escribe letra por letra y luego el bloque negro sube y deja
/// ver el formulario, que entra por partes. La bienvenida completa se ve
/// solo la primera vez que se abre la app; se puede saltar tocándola.
/// En ventanas anchas el bloque negro se queda como panel a la izquierda.
/// La lógica de autenticación no cambió en nada.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  /// La bienvenida completa se muestra solo la primera vez; al cerrar
  /// sesión y volver, solo entra el formulario.
  static bool _bienvenidaVista = false;

  /// Punto de la animación (de 0 a 1) en que el bloque negro termina de
  /// subir y empieza a entrar el formulario.
  static const double _finBienvenida = 0.72;

  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  late final Animation<double> _subida = CurvedAnimation(
    parent: _entrada,
    curve: const Interval(0.50, _finBienvenida, curve: Curves.easeInOutCubic),
  );

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _cargando = false;
  bool _verPassword = false;

  @override
  void initState() {
    super.initState();
    if (_bienvenidaVista) _entrada.value = _finBienvenida;
    _bienvenidaVista = true;
  }

  bool _arranco = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si el teléfono pide menos animaciones, todo aparece de una vez.
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1;
    } else if (!_arranco) {
      _arranco = true;
      _empezarBienvenida();
    }
  }

  /// En la web la imagen del logo tarda en cargar: se espera a que esté
  /// lista y a que se dibuje la primera pantalla, para que la animación se
  /// vea completa y no empiece con la pantalla todavía en blanco.
  Future<void> _empezarBienvenida() async {
    try {
      await precacheImage(AssetImage(AppBrand.logoAsset), context);
    } catch (_) {
      // Si el logo no carga, igual se muestra la animación.
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (mounted && _entrada.value < 1) _entrada.forward();
  }

  /// Tocar la bienvenida la adelanta hasta el formulario.
  void _saltarBienvenida() {
    if (_entrada.value < _finBienvenida) {
      _entrada.value = _finBienvenida;
      _entrada.forward();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
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
      pedirCodigo: (error) => pedirCodigoDosPasos(context, error: error),
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

  Future<void> _olvidePassword() async {
    final enviado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoRecuperar(emailInicial: _emailCtrl.text.trim()),
    );
    if (enviado == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('Si el correo tiene una cuenta, te enviamos un enlace para restablecer la contraseña. Revisa también la carpeta de spam.'),
          ),
        ),
      );
    }
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
      onOlvide: _olvidePassword,
      entrada: _entrada,
      inicioEntrada: _finBienvenida - 0.02,
    );

    if (esAmplio) {
      // Computadora: el bloque negro cubre toda la pantalla y luego se
      // achica hasta la mitad izquierda, dejando ver el formulario.
      return Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: const Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [BotonTamanoTexto(), BotonIdioma()]),
        ),
        body: LayoutBuilder(
          builder: (context, c) => Stack(
            children: [
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: c.maxWidth / 2,
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
              AnimatedBuilder(
                animation: _subida,
                builder: (context, _) => Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  width: c.maxWidth - (c.maxWidth / 2) * _subida.value,
                  child: GestureDetector(
                    onTap: _saltarBienvenida,
                    child: ValueListenableBuilder<NegocioModel?>(
                      valueListenable: AppThemeController.instancia.negocio,
                      builder: (context, negocio, _) => _PanelMarca(
                        color: scheme.primary,
                        imagenUrl: negocio?.bannerUrl ?? '',
                        entrada: _entrada,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Celular: bloque negro con la marca y borde curvo arriba; el
    // formulario debajo. Durante la bienvenida el bloque ocupa toda la
    // pantalla y después sube.
    final altoPantalla = MediaQuery.sizeOf(context).height;
    final altoFinal = math.max(altoPantalla * 0.36, 280.0);
    return Scaffold(
      backgroundColor: scheme.surface,
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: const SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [BotonTamanoTexto(color: Colors.white), BotonIdioma(color: Colors.white)],
        ),
      ),
      body: AnimatedBuilder(
        animation: _entrada,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: formulario,
            ),
          ),
        ),
        builder: (context, hijo) {
          final t = _subida.value;
          final altoMarca = altoPantalla + (altoFinal - altoPantalla) * t;
          return SingleChildScrollView(
            physics: _entrada.value < _finBienvenida ? const NeverScrollableScrollPhysics() : null,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _saltarBienvenida,
                  child: ClipPath(
                    clipper: const CurvaInferior(),
                    child: Container(
                      height: altoMarca,
                      width: double.infinity,
                      color: AppBrand.negro,
                      padding: const EdgeInsets.only(bottom: 48),
                      child: SafeArea(
                        bottom: false,
                        child: _EncabezadoMarca(entrada: _entrada, tamanoLogo: 120 - 36 * t),
                      ),
                    ),
                  ),
                ),
                hijo!,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Logo, nombre y frase de la marca con su animación de entrada: el logo
/// aparece agrandándose, "Nami" se escribe letra por letra en dorado y la
/// frase aparece al final.
class _EncabezadoMarca extends StatelessWidget {
  final Animation<double> entrada;
  final double tamanoLogo;

  const _EncabezadoMarca({required this.entrada, required this.tamanoLogo});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: entrada,
      builder: (context, _) {
        final v = entrada.value;
        double tramo(double a, double b, [Curve curva = Curves.easeOutCubic]) =>
            curva.transform(((v - a) / (b - a)).clamp(0.0, 1.0));
        final logo = tramo(0.0, 0.18, Curves.easeOutBack);
        final escrito = tramo(0.12, 0.36, Curves.linear);
        final frase = tramo(0.34, 0.46);

        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: logo.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.5 + 0.5 * logo, child: LogoCaro(size: tamanoLogo)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextoEscrito(
                    texto: AppBrand.nombre,
                    progreso: escrito,
                    estilo: const TextStyle(
                      color: AppBrand.dorado,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Opacity(
                    opacity: frase,
                    child: Transform.translate(
                      offset: Offset(0, (1 - frase) * 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(
                          tr('Pide, gestiona y sirve todo desde un solo lugar.'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
  final Animation<double> entrada;
  const _PanelMarca({required this.color, required this.entrada, this.imagenUrl = ''});

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
          _EncabezadoMarca(entrada: entrada, tamanoLogo: 150),
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
  final VoidCallback onOlvide;

  /// Animación de entrada de la pantalla: cada parte del formulario
  /// aparece una tras otra a partir de [inicioEntrada].
  final Animation<double> entrada;
  final double inicioEntrada;

  const _Formulario({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.verPassword,
    required this.cargando,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onOlvide,
    required this.entrada,
    required this.inicioEntrada,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var orden = 0;
    // Cada llamada hace entrar una parte un poco después que la anterior.
    Widget entra(Widget parte) {
      final inicio = math.min(inicioEntrada + orden * 0.03, 0.9);
      orden++;
      return EntradaEscalonada(
        animacion: entrada,
        inicio: inicio,
        fin: math.min(inicio + 0.16, 1.0),
        child: parte,
      );
    }

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          entra(Text(
            tr('Bienvenido de nuevo'),
            style: Theme.of(context).textTheme.headlineSmall,
          )),
          const SizedBox(height: AppSpacing.xs),
          entra(Text(
            tr('Inicia sesión para continuar'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          )),
          const SizedBox(height: AppSpacing.xl),

          // Entró por el enlace de un restaurante: se muestra cuál es.
          if (CodigoNegocioService.codigoDelEnlace != null)
            entra(BannerInvitacion(codigo: CodigoNegocioService.codigoDelEnlace!)),
          entra(TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: tr('Correo electrónico *'),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? tr('Ingresa tu correo') : null,
          )),
          const SizedBox(height: AppSpacing.md),

          entra(TextFormField(
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
            validator: (v) =>
                (v == null || v.isEmpty) ? tr('Ingresa tu contraseña') : null,
            onFieldSubmitted: (_) => onSubmit(),
          )),
          entra(Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: cargando ? null : onOlvide,
              child: Text(tr('¿Olvidaste tu contraseña?')),
            ),
          )),
          const SizedBox(height: AppSpacing.sm),

          entra(FilledButton(
            onPressed: cargando ? null : onSubmit,
            child: cargando
                ? PuntosCargando(color: scheme.primary)
                : Text(tr('Iniciar sesión')),
          )),
          const SizedBox(height: AppSpacing.sm),

          entra(TextButton(
            onPressed: cargando
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RegistroScreen(),
                      ),
                    ),
            child: Text(tr('¿No tienes cuenta? Regístrate')),
          )),
          const SizedBox(height: AppSpacing.xs),

          entra(Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LegalScreen(tipo: TipoTextoLegal.terminos),
                  ),
                ),
                child: Text(tr('Términos y condiciones')),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalScreen(
                      tipo: TipoTextoLegal.politicaPrivacidad,
                    ),
                  ),
                ),
                child: Text(tr('Política de privacidad')),
              ),
            ],
          )),
          entra(const EtiquetaVersion()),
        ],
      ),
    );
  }
}

/// Diálogo para pedir el correo y enviar el enlace de restablecimiento.
class _DialogoRecuperar extends StatefulWidget {
  final String emailInicial;
  const _DialogoRecuperar({required this.emailInicial});

  @override
  State<_DialogoRecuperar> createState() => _DialogoRecuperarState();
}

class _DialogoRecuperarState extends State<_DialogoRecuperar> {
  late final TextEditingController _emailCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.emailInicial);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    final error = await AuthService.instancia.enviarRecuperacionPassword(_emailCtrl.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _enviando = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Con el teclado abierto el contenido se desplaza en vez de
      // encimarse con los botones.
      scrollable: true,
      title: Text(tr('Restablecer contraseña')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Escribe tu correo y te enviaremos un enlace para crear una contraseña nueva.')),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                labelText: tr('Correo electrónico *'),
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? tr('Ingresa tu correo') : null,
              onFieldSubmitted: (_) => _enviar(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: Text(tr('Cancelar')),
        ),
        FilledButton(
          onPressed: _enviando ? null : _enviar,
          child: _enviando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(tr('Enviar enlace')),
        ),
      ],
    );
  }
}
