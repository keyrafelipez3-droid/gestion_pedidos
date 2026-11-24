import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../l10n/idioma.dart';
import '../screens/cuenta/dos_pasos_screen.dart';
import '../services/auth_service.dart';
import '../theme/design_tokens.dart';

/// Antes de una acción sensible (cerrar la caja, cancelar un pedido,
/// cambiar el rol o desactivar a un empleado) se vuelve a pedir la
/// contraseña y, si la cuenta tiene verificación en dos pasos, el código de
/// 6 dígitos. Así nadie puede hacerlo desde una sesión que quedó abierta.
///
/// En el celular primero se usa la huella o la cara (si el teléfono las
/// tiene); si falla o no hay, se pide la contraseña. Después de confirmar,
/// durante 10 minutos no se vuelve a preguntar (como el "modo sudo" de
/// GitHub), para no repetirlo en cada pedido.
///
/// Devuelve true si la persona confirmó su identidad.
Future<bool> confirmarIdentidad(BuildContext context, {required String accion}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  if (_confirmadoHace(uid) < _ventana) return true;

  if (!kIsWeb && await _conHuellaOCara(accion)) {
    _recordar(uid);
    return true;
  }
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoIdentidad(accion: accion),
  );
  if (ok == true) _recordar(uid);
  return ok == true;
}

/// Tiempo durante el que no se vuelve a pedir la confirmación.
const _ventana = Duration(minutes: 10);

String? _uidConfirmado;
DateTime? _confirmadoEn;

void _recordar(String uid) {
  _uidConfirmado = uid;
  _confirmadoEn = DateTime.now();
}

/// Cuánto pasó desde la última confirmación de esta persona.
Duration _confirmadoHace(String uid) {
  final en = _confirmadoEn;
  if (en == null || _uidConfirmado != uid) return const Duration(days: 1);
  return DateTime.now().difference(en);
}

/// Pide la huella o la cara del teléfono. Devuelve false si el teléfono no
/// las tiene, si la persona cancela o si falla (entonces se pide la
/// contraseña).
Future<bool> _conHuellaOCara(String accion) async {
  try {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported() || !await auth.canCheckBiometrics) return false;
    final registradas = await auth.getAvailableBiometrics();
    if (registradas.isEmpty) return false;
    return await auth.authenticate(
      localizedReason: tr('Confirma que eres tú para {accion}.', {'accion': accion}),
      options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
    );
  } catch (_) {
    return false;
  }
}

class _DialogoIdentidad extends StatefulWidget {
  final String accion;
  const _DialogoIdentidad({required this.accion});

  @override
  State<_DialogoIdentidad> createState() => _DialogoIdentidadState();
}

class _DialogoIdentidadState extends State<_DialogoIdentidad> {
  final _ctrl = TextEditingController();
  bool _ver = false;
  bool _verificando = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_ctrl.text.isEmpty) {
      setState(() => _error = tr('Escribe tu contraseña'));
      return;
    }
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      await AuthService.instancia.reautenticar(
        _ctrl.text,
        pedirCodigo: (error) => pedirCodigoDosPasos(context, error: error),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _verificando = false;
          _error = AuthService.instancia.mensajeError(e.code);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _verificando = false;
          _error = tr('No se pudo verificar. Intenta de nuevo.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Con el teclado abierto el contenido se desplaza en vez de
      // encimarse con los botones.
      scrollable: true,
      icon: const Icon(Icons.verified_user_outlined, size: 36),
      title: Text(tr('Confirma que eres tú')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Para {accion}, escribe tu contraseña.', {'accion': widget.accion})),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _ctrl,
              autofocus: true,
              obscureText: !_ver,
              obscuringCharacter: '*',
              onSubmitted: (_) => _verificando ? null : _confirmar(),
              decoration: InputDecoration(
                labelText: tr('Contraseña *'),
                errorText: _error,
                errorMaxLines: 2,
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_ver ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _ver = !_ver),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _verificando ? null : () => Navigator.of(context).pop(false),
          child: Text(tr('Cancelar')),
        ),
        FilledButton(
          onPressed: _verificando ? null : _confirmar,
          child: _verificando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(tr('Confirmar')),
        ),
      ],
    );
  }
}
