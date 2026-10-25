import 'package:flutter/material.dart';

import '../theme/brand_style.dart';

/// Convierte un color guardado como texto hexadecimal ("#E65100" o
/// "E65100") en un [Color]. Si el texto está vacío o no es válido,
/// devuelve [respaldo].
Color colorDesdeHex(String? hex, Color respaldo) {
  if (hex == null) return respaldo;
  final limpio = hex.replaceAll('#', '').trim();
  if (limpio.length != 6) return respaldo;
  final valor = int.tryParse('FF$limpio', radix: 16);
  return valor == null ? respaldo : Color(valor);
}

/// Color de texto legible (oscuro o blanco) sobre [fondo].
Color textoSobreColor(Color fondo) => colorLegibleSobre(fondo, oscuro: const Color(0xFF1A1200));
