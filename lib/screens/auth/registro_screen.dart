import 'package:flutter/material.dart';

import '../../l10n/idioma.dart';
import '../../l10n/tamano_texto.dart';
import '../../services/auth_service.dart';
import '../../services/codigo_negocio_service.dart';
import '../../theme/design_tokens.dart';
import '../../utils/contrasena.dart';
import '../../widgets/animaciones_marca.dart';
import '../../widgets/app_pantalla_foto.dart';
import '../../widgets/campo_telefono.dart';
import '../../widgets/codigo_restaurante.dart';
import '../../widgets/logo_nami.dart';
import '../legal/legal_screen.dart';

/// HU-01 — Pantalla de registro para Clientes.
/// ("Registrarme con mis datos básicos")
///
/// Mismo tratamiento responsive que login_screen.dart (Fase 4): en
/// ventanas anchas se muestra un panel de marca junto al formulario; en
/// celular el formulario queda centrado como antes. Al abrirse, todo
/// entra con una animación corta, como el inicio de sesión (sin
/// animación si el dispositivo pide "reducir movimiento"). Toda la lógica
/// de registro (_registrar, validadores, controllers) se mantiene igual.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  /// Animación de entrada (más corta que la bienvenida del login).
  late final AnimationController _entrada =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  bool _arranco = false;

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();
  // Código del restaurante (viene ya escrito si entró por su enlace).
  final _codigoCtrl = TextEditingController(text: CodigoNegocioService.codigoDelEnlace ?? '');

  bool _cargando = false;
  bool _verPassword = false;
  bool _aceptaTerminos = false;
  bool _errorTerminos = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrada.value = 1;
    } else if (!_arranco) {
      _arranco = true;
      _entrada.forward();
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    _codigoCtrl.dispose();
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

    // El cliente se registra para pedir en UN restaurante: su código debe
    // existir. Al entrar, la pantalla principal lo deja dentro de él.
    final invitacion = await CodigoNegocioService.instancia.buscar(_codigoCtrl.text);
    if (!mounted) return;
    if (invitacion == null) {
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('Ese código de restaurante no existe. Revisa que esté bien escrito.')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }
    CodigoNegocioService.codigoDelEnlace = invitacion.codigo;

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
    final ancho = MediaQuery.sizeOf(context).width;
    final esAmplio = AppBreakpoints.isExpanded(ancho);

    final formulario = _Formulario(
      formKey: _formKey,
      nombreCtrl: _nombreCtrl,
      emailCtrl: _emailCtrl,
      telefonoCtrl: _telefonoCtrl,
      passwordCtrl: _passwordCtrl,
      confirmarCtrl: _confirmarCtrl,
      codigoCtrl: _codigoCtrl,
      verPassword: _verPassword,
      cargando: _cargando,
      onTogglePassword: () => setState(() => _verPassword = !_verPassword),
      onSubmit: _registrar,
      mostrarEncabezado: !esAmplio,
      entrada: _entrada,
      inicioEntrada: esAmplio ? 0.30 : 0.05,
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [BotonTamanoTexto(), BotonIdioma()]),
        ),
        body: Row(
          children: [
            Expanded(flex: 11, child: _PanelMarca(entrada: _entrada)),
            Expanded(
              flex: 9,
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
        actions: const [BotonTamanoTexto(color: Colors.white), BotonIdioma(color: Colors.white)],
      ),
      body: AppPantallaFoto(
        asset: 'assets/images/comida_terraza.jpg',
        formulario: formulario,
        conAppBar: true,
      ),
    );
  }
}

/// Panel de marca del registro (pantallas anchas): mismo lenguaje que el
/// login — fondo berenjena, logotipo y la foto de comida en un "plato".
/// Cada parte entra con la animación: el logo, "nami" que se escribe, las
/// frases y al final el plato.
class _PanelMarca extends StatelessWidget {
  final Animation<double> entrada;
  const _PanelMarca({required this.entrada});

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final foto = Image.asset(
      'assets/images/comida_steak.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => const ColoredBox(color: AppBrand.locoto),
    );
    return ColoredBox(
      color: AppBrand.berenjena,
      child: LayoutBuilder(
        builder: (context, c) {
          final diametro = c.maxHeight * 0.74;
          return AnimatedBuilder(
            animation: entrada,
            builder: (context, _) {
              final v = entrada.value;
              double tramo(double a, double b, [Curve curva = Curves.easeOutCubic]) =>
                  curva.transform(((v - a) / (b - a)).clamp(0.0, 1.0));
              final logo = tramo(0.0, 0.25, Curves.easeOutBack);
              final escrito = tramo(0.10, 0.40, Curves.linear);
              final frase = tramo(0.30, 0.55);
              final detalle = tramo(0.40, 0.65);
              final plato = tramo(0.45, 0.85, Curves.easeOutBack);
              return Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    left: -diametro * 0.18,
                    bottom: -diametro * 0.26,
                    width: diametro,
                    height: diametro,
                    child: Opacity(
                      opacity: plato.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * plato,
                        alignment: Alignment.bottomLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppBrand.aji, width: 10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: ClipOval(child: foto),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 48, 56, 48),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Opacity(
                              opacity: logo.clamp(0.0, 1.0),
                              child: Transform.scale(
                                scale: 0.5 + 0.5 * logo,
                                child: const LogoNami(size: 52, conFondo: false),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            RevelarHorizontal(
                              progreso: escrito,
                              child: const WordmarkNami(alto: 36, color: AppBrand.leche),
                            ),
                          ],
                        ),
                        SizedBox(height: c.maxHeight * 0.12),
                        Opacity(
                          opacity: frase,
                          child: Transform.translate(
                            offset: Offset(0, (1 - frase) * 12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Text(
                                tr('Únete a {nombre}', {'nombre': AppBrand.nombre}),
                                style: texto.displaySmall?.copyWith(
                                  color: AppBrand.leche,
                                  height: 1.08,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Opacity(
                          opacity: detalle,
                          child: Transform.translate(
                            offset: Offset(0, (1 - detalle) * 12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 380),
                              child: Text(
                                tr('Crea tu cuenta y empieza a pedir en segundos.'),
                                style: texto.bodyLarge?.copyWith(
                                  color: AppBrand.leche.withValues(alpha: 0.72),
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
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
  final TextEditingController codigoCtrl;
  final bool verPassword;
  final bool cargando;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final bool mostrarEncabezado;

  /// Animación de entrada: cada parte del formulario aparece una tras otra
  /// a partir de [inicioEntrada].
  final Animation<double> entrada;
  final double inicioEntrada;
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
    required this.codigoCtrl,
    required this.verPassword,
    required this.cargando,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.mostrarEncabezado,
    required this.entrada,
    required this.inicioEntrada,
    required this.aceptaTerminos,
    required this.errorTerminos,
    required this.onCambiarTerminos,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Form(
      key: formKey,
      child: _ColumnaEscalonada(
        entrada: entrada,
        inicio: inicioEntrada,
        children: [
          if (mostrarEncabezado) ...[
            const Center(child: LogoNami(size: 56)),
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

          if (CodigoNegocioService.codigoDelEnlace != null)
            BannerInvitacion(codigo: CodigoNegocioService.codigoDelEnlace!),
          TextFormField(
            controller: codigoCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: tr('Código del restaurante *'),
              helperText: tr('Te lo da el restaurante donde quieres pedir.'),
              prefixIcon: const Icon(Icons.vpn_key_outlined),
            ),
            validator: (v) => CodigoNegocioService.normalizar(v ?? '').length < 4
                ? tr('Ingresa el código del restaurante')
                : null,
          ),
          const SizedBox(height: AppSpacing.md),

          TextFormField(
            controller: nombreCtrl,
            maxLength: 80,
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
                      Text(tr(', y confirmo que tengo 18 años o más (o el permiso de mi madre, padre o tutor)')),
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

/// Columna cuyas partes entran una tras otra con [entrada], a partir de
/// [inicio] (de 0 a 1).
class _ColumnaEscalonada extends StatelessWidget {
  final Animation<double> entrada;
  final double inicio;
  final List<Widget> children;

  const _ColumnaEscalonada({required this.entrada, required this.inicio, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          EntradaEscalonada(
            animacion: entrada,
            inicio: (inicio + i * 0.02).clamp(0.0, 0.84),
            fin: (inicio + i * 0.02 + 0.16).clamp(0.16, 1.0),
            child: children[i],
          ),
      ],
    );
  }
}
