import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/models/catalogo_models.dart';
import 'package:gestion_pedidos/models/sucursal_model.dart';
import 'package:gestion_pedidos/services/dashboard_service.dart';

void main() {
  group('HU-35 Promociones', () {
    final hoy = DateTime(2026, 10, 25, 12);

    test('la promoción vigente cambia el precio que se cobra', () {
      final p = ProductoModel(id: 'a', nombre: 'Pollo', precio: 40, precioPromo: 30);
      expect(p.promoActiva(hoy), isTrue);
      expect(p.precioVigente(hoy), 30);
      expect(p.porcentajePromo(hoy), 25);
    });

    test('vencida o más cara que el precio normal, no aplica', () {
      final vencida = ProductoModel(
          id: 'a', nombre: 'Pollo', precio: 40, precioPromo: 30, promoHasta: DateTime(2026, 10, 24, 23, 59));
      expect(vencida.precioVigente(hoy), 40);
      const mal = ProductoModel(id: 'b', nombre: 'Papas', precio: 10, precioPromo: 12);
      expect(mal.promoActiva(hoy), isFalse);
      expect(mal.precioVigente(hoy), 10);
    });

    test('sin promoción el precio es el normal', () {
      const p = ProductoModel(id: 'a', nombre: 'Pollo', precio: 40);
      expect(p.precioVigente(), 40);
      expect(p.porcentajePromo(), 0);
    });
  });

  group('HU-37 Combos', () {
    const pollo = ProductoModel(id: 'p', nombre: 'Pollo', precio: 35);
    const papas = ProductoModel(id: 'f', nombre: 'Papas', precio: 10);
    const soda = ProductoModel(id: 's', nombre: 'Soda', precio: 8, disponible: false);
    const combo = ProductoModel(id: 'c', nombre: 'Combo Familiar', precio: 45, esCombo: true, comboIds: ['p', 'f']);

    test('el nombre del pedido lleva lo que incluye', () {
      expect(combo.nombreParaPedido([pollo, papas]), 'Combo Familiar (Pollo + Papas)');
      expect(pollo.nombreParaPedido([pollo]), 'Pollo');
    });

    test('solo se vende si todo lo que incluye está disponible', () {
      expect(combo.comboDisponible([pollo, papas]), isTrue);
      const conSoda = ProductoModel(id: 'c2', nombre: 'Combo', precio: 40, esCombo: true, comboIds: ['p', 's']);
      expect(conSoda.comboDisponible([pollo, soda]), isFalse);
      // Si se borró un producto del combo, tampoco se vende.
      expect(combo.comboDisponible([pollo]), isFalse);
    });
  });

  group('HU-44 Menos vendidos', () {
    test('el ranking incluye con 0 los productos que no se vendieron', () {
      final r = armarRanking({'Pollo': 5, 'Papas': 2}, {'Pollo': 175, 'Papas': 20},
          catalogo: ['Pollo', 'Papas', 'Ensalada']);
      expect(r.map((p) => p.nombre), ['Pollo', 'Papas', 'Ensalada']);
      expect(r.last.cantidad, 0);
      expect(r.reversed.first.nombre, 'Ensalada');
    });
  });

  group('HU-47 Pausa de pedidos', () {
    test('una sucursal en pausa aparece cerrada con el motivo', () {
      const s = SucursalModel(id: 's', nombre: 'Centro', pedidosPausados: true, motivoPausa: 'Cocina llena');
      final ap = s.estadoApertura(DateTime(2026, 10, 25, 12));
      expect(ap.abierta, isFalse);
      expect(ap.mensaje, contains('Cocina llena'));
    });

    test('sin pausa (y sin horarios) atiende normalmente', () {
      const s = SucursalModel(id: 's', nombre: 'Centro');
      expect(s.estadoApertura(DateTime(2026, 10, 25, 12)).abierta, isTrue);
    });
  });
}
