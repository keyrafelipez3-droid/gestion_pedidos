import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/services/codigo_negocio_service.dart';

void main() {
  test('el código se escribe sin importar mayúsculas, espacios o guiones', () {
    expect(CodigoNegocioService.normalizar(' abc-123 '), 'ABC123');
    expect(CodigoNegocioService.normalizar('pollo 1'), 'POLLO1');
  });

  test('los códigos nuevos tienen 6 caracteres fáciles de dictar', () {
    final azar = Random(7);
    for (var i = 0; i < 200; i++) {
      final c = CodigoNegocioService.generar(azar);
      expect(c.length, 6);
      expect(RegExp(r'^[A-Z2-9]{6}$').hasMatch(c), isTrue);
      expect(c.contains(RegExp('[01OIL]')), isFalse);
    }
  });

  test('el enlace de cada restaurante lleva su código', () {
    expect(CodigoNegocioService.enlace('ABC123'),
        'https://gestion-pedidos-univalle.web.app/?r=ABC123');
  });
}
