import 'package:firebase_auth/firebase_auth.dart';

import '../l10n/idioma.dart';
import '../theme/design_tokens.dart';

/// Pide al usuario el código de 6 dígitos de su app autenticadora.
/// [error] es el mensaje a mostrar si el intento anterior falló.
/// Devuelve null si la persona canceló.
typedef PedirCodigo = Future<String?> Function(String? error);

/// Verificación en dos pasos con app autenticadora (Google Authenticator,
/// Microsoft Authenticator, Authy...). Usa la autenticación multifactor de
/// Firebase (TOTP): el código se valida en los servidores de Firebase, así
/// que nadie puede entrar con solo la contraseña.
///
/// - Obligatoria para el personal (SuperAdmin, Administrador, Cajero,
///   Cocina y Repartidor): ver `PuertaDosPasos`.
/// - Opcional para los clientes, desde "Mi cuenta".
///
/// Requisitos en Firebase (una sola vez): plan Blaze, Identity Platform y
/// TOTP activado (ver "Claude outputs/datos-demo/dos-pasos.js").
class DosPasosService {
  DosPasosService._();
  static final instancia = DosPasosService._();

  static const _codigosIncorrectos = {
    'invalid-verification-code',
    'invalid-code',
    'missing-code',
    'code-expired',
  };

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// ¿El usuario logueado ya tiene la verificación en dos pasos activa?
  Future<bool> estaActiva() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final factores = await user.multiFactor.getEnrolledFactors();
    return factores.isNotEmpty;
  }

  /// Primer paso para activarla: Firebase genera una clave secreta nueva
  /// que la persona agrega a su app autenticadora (con el QR).
  Future<TotpSecret> generarSecreto() async {
    final user = _auth.currentUser!;
    final sesion = await user.multiFactor.getSession();
    return TotpMultiFactorGenerator.generateSecret(sesion);
  }

  /// Contenido del código QR (formato otpauth://) para la app autenticadora.
  Future<String> urlQr(TotpSecret secreto) => secreto.generateQrCodeUrl(
        accountName: _auth.currentUser?.email ?? '',
        issuer: AppBrand.nombre,
      );

  /// Segundo paso: confirma con el primer código que muestra la app.
  Future<void> activar(TotpSecret secreto, String codigo) async {
    final confirmacion =
        await TotpMultiFactorGenerator.getAssertionForEnrollment(secreto, codigo.trim());
    await _auth.currentUser!.multiFactor
        .enroll(confirmacion, displayName: 'App autenticadora');
  }

  /// Quita la verificación en dos pasos (solo clientes; antes hay que
  /// volver a confirmar la contraseña con `AuthService.reautenticar`).
  Future<void> desactivar() async {
    final user = _auth.currentUser!;
    for (final f in await user.multiFactor.getEnrolledFactors()) {
      await user.multiFactor.unenroll(multiFactorInfo: f);
    }
  }

  Future<void> enviarVerificacionCorreo() => _auth.currentUser!.sendEmailVerification();

  Future<bool> correoVerificado() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Completa un inicio de sesión (o una reautenticación) que pidió el
  /// segundo paso: pide el código y lo valida. Permite equivocarse algunas
  /// veces. Devuelve null si la persona canceló.
  Future<UserCredential?> resolver(MultiFactorResolver resolver, PedirCodigo? pedirCodigo) async {
    if (pedirCodigo == null) {
      throw FirebaseAuthException(code: 'multi-factor-auth-required');
    }
    final pista = resolver.hints.where((h) => h.factorId == 'totp').firstOrNull;
    if (pista == null) {
      throw FirebaseAuthException(code: 'segundo-paso-no-soportado');
    }
    String? error;
    for (var intento = 0; intento < 5; intento++) {
      final codigo = await pedirCodigo(error);
      if (codigo == null) return null;
      try {
        final confirmacion =
            await TotpMultiFactorGenerator.getAssertionForSignIn(pista.uid, codigo.trim());
        return await resolver.resolveSignIn(confirmacion);
      } on FirebaseAuthException catch (e) {
        if (!_codigosIncorrectos.contains(e.code)) rethrow;
        error = tr('Código incorrecto. Revisa que la hora de tu teléfono esté bien y usa el código más reciente.');
      }
    }
    throw FirebaseAuthException(code: 'too-many-requests');
  }

  static bool esCodigoIncorrecto(FirebaseAuthException e) => _codigosIncorrectos.contains(e.code);
}
