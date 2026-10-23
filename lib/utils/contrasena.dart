import 'package:flutter/material.dart';

import '../l10n/idioma.dart';

/// Política de contraseñas de la app (la misma que se activa en Firebase con
/// "Claude outputs/datos-demo/seguridad.js --politica"): mínimo 8
/// caracteres, con al menos una letra y un número, y que no sea parte del
/// correo ni una contraseña muy común.
const _comunes = {
  '12345678', '123456789', '1234567890', 'password', 'password1', 'contraseña',
  'qwerty123', 'abc12345', 'abcd1234', '11111111', '00000000', 'admin123',
  'bolivia1', 'caro1234', 'iloveyou', '87654321', 'asdf1234', 'qwertyui',
};

String? validarContrasena(String? valor, {String correo = ''}) {
  final v = valor ?? '';
  if (v.isEmpty) return tr('Ingresa la contraseña');
  if (v.length < 8) return tr('Mínimo 8 caracteres');
  if (!RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
    return tr('Usa letras y números');
  }
  if (_comunes.contains(v.toLowerCase())) return tr('Esa contraseña es muy común, elige otra');
  final usuario = correo.split('@').first.toLowerCase();
  if (usuario.length >= 4 && v.toLowerCase().contains(usuario)) {
    return tr('No uses tu correo dentro de la contraseña');
  }
  return null;
}

/// 0 = vacía, 1 = débil, 2 = aceptable, 3 = buena, 4 = muy buena.
int fuerzaContrasena(String v) {
  if (v.isEmpty) return 0;
  var puntos = 0;
  if (v.length >= 8) puntos++;
  if (v.length >= 12) puntos++;
  if (RegExp(r'[a-z]').hasMatch(v) && RegExp(r'[A-Z]').hasMatch(v)) puntos++;
  if (RegExp(r'\d').hasMatch(v)) puntos++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(v)) puntos++;
  if (validarContrasena(v) != null) return 1;
  return puntos <= 2 ? 2 : (puntos == 3 ? 3 : 4);
}

/// Barra de seguridad que se actualiza mientras se escribe.
class MedidorContrasena extends StatelessWidget {
  final TextEditingController controller;
  const MedidorContrasena({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, valor, _) {
        final f = fuerzaContrasena(valor.text);
        if (f == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              tr('Mínimo 8 caracteres, con letras y números.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        const colores = [Colors.transparent, Color(0xFFD32F2F), Color(0xFFF9A825), Color(0xFF7CB342), Color(0xFF2E7D32)];
        final etiquetas = ['', tr('Débil'), tr('Aceptable'), tr('Buena'), tr('Muy buena')];
        return Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
          child: Row(
            children: [
              for (var i = 1; i <= 4; i++)
                Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= f ? colores[f] : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                etiquetas[f],
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colores[f]),
              ),
            ],
          ),
        );
      },
    );
  }
}
