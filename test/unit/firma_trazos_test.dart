import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/utils/firma_trazos.dart';

void main() {
  final trazo = [for (var i = 0; i < 20; i++) Offset(10.0 + i * 5, 50.0 + (i % 3) * 4)];

  test('la firma se guarda como texto y se vuelve a leer igual', () {
    final texto = FirmaTrazos.aTexto([trazo, [const Offset(200, 20), const Offset(220, 40)]]);
    expect(texto, startsWith('M10 50 L'));
    final leidos = FirmaTrazos.desdeTexto(texto);
    expect(leidos.length, 2);
    expect(leidos.first.first, const Offset(10, 50));
    expect(leidos.last.last, const Offset(220, 40));
  });

  test('los puntos quedan dentro del recuadro', () {
    final texto = FirmaTrazos.aTexto([[const Offset(-20, 500), const Offset(400, -3)]]);
    expect(texto, 'M0 120 L300 0');
  });

  test('un punto o una rayita no cuentan como firma', () {
    expect(FirmaTrazos.esValida(FirmaTrazos.aTexto([trazo])), isTrue);
    expect(FirmaTrazos.esValida('M10 10 L20 20'), isFalse);
    expect(FirmaTrazos.esValida(''), isFalse);
    expect(FirmaTrazos.esValida('<script>'), isFalse);
  });
}
