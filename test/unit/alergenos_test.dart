import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/models/alergenos.dart';

void main() {
  test('ordenar quita códigos desconocidos y repetidos', () {
    expect(Alergenos.ordenar(['cebolla', 'mani', 'xyz', 'mani']), ['mani', 'cebolla']);
  });

  test('desdeFirestore tolera datos raros', () {
    expect(Alergenos.desdeFirestore(null), isEmpty);
    expect(Alergenos.desdeFirestore('mani'), isEmpty);
    expect(Alergenos.desdeFirestore(['tomate', 3, 'gluten']), ['gluten', 'tomate']);
  });

  test('enComun detecta el conflicto entre producto y alergia', () {
    expect(Alergenos.enComun(['cebolla', 'tomate', 'gluten'], ['tomate', 'mani']), ['tomate']);
    expect(Alergenos.enComun(['cebolla'], const []), isEmpty);
  });

  test('nombres en español', () {
    expect(Alergenos.nombres(['cebolla', 'mani']), 'Maní, Cebolla');
  });

  test('la lista de la app coincide con la de las reglas de Firestore', () {
    // Si se agrega un alérgeno, también hay que agregarlo en
    // firestore.rules (función alergiasValidas).
    expect(Alergenos.todos.map((a) => a.codigo).toList(), [
      'mani', 'frutos_secos', 'gluten', 'lacteos', 'huevo', 'mariscos', 'pescado',
      'soya', 'sesamo', 'cebolla', 'tomate', 'ajo', 'picante',
    ]);
  });
}
