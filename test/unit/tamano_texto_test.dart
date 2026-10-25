import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/l10n/tamano_texto.dart';

void main() {
  test('se suma al tamaño del sistema, con un tope', () {
    expect(escalaFinal(1.0, 1.3), closeTo(1.3, 0.001));
    expect(escalaFinal(1.2, 1.15), closeTo(1.38, 0.001));
    // Sistema muy grande + "Máximo": no pasa de 2x para no desarmar pantallas.
    expect(escalaFinal(1.8, 1.5), 2.0);
  });

  test('un valor guardado raro se lleva al tamaño más cercano', () {
    expect(TamanoTexto.deEscala(1.0).nombre, 'Normal');
    expect(TamanoTexto.deEscala(1.27).nombre, 'Muy grande');
    expect(TamanoTexto.deEscala(9).nombre, 'Máximo');
  });
}
