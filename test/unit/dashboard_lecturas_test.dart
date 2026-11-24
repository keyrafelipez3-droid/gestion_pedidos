import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/screens/admin/dashboard/dashboard_graficos.dart';

void main() {
  test('el panel lee solo los días que necesita cada periodo', () {
    final hoy = DateTime(2026, 11, 24);
    for (final p in PeriodoDashboard.values) {
      final dias = diasACargar(p);
      final primerDia = hoy.subtract(Duration(days: dias - 1));
      final (desdeAnt, _) = p.rangoAnterior(hoy);
      // Alcanza para el periodo y su comparación con el anterior.
      expect(primerDia.isAfter(desdeAnt), isFalse, reason: p.name);
    }
    // Al entrar (Hoy o 7 días) no se leen dos meses de pedidos.
    expect(diasACargar(PeriodoDashboard.semana), 14);
    expect(diasACargar(PeriodoDashboard.hoy), 14);
    expect(diasACargar(PeriodoDashboard.mes), 60);
  });
}
