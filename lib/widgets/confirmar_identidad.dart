import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/idioma.dart';
import '../screens/cuenta/dos_pasos_screen.dart';
import '../services/auth_service.dart';
import '../theme/design_tokens.dart';

/// Antes de una acción sensible (cerrar la caja, cancelar un pedido,
/// cambiar el rol o desactivar a un empleado) se vuelve a pedir la
/// contraseña y, si la cuenta tiene verificación en dos pasos, el código de
/// 6 dígitos. Así nadie puede hacerlo desde una sesión que quedó abierta.
///
/// Devuelve true si la persona confirmó su identidad.
Future<bool> confirmarIdentidad(BuildContext context, {required String accion}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DialogoIdentidad(accion: accion),
  );
  return ok == true;
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
