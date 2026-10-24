import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/services/registro_errores.dart';

void main() {
  Map<String, dynamic> datos({String mensaje = 'Fallo', String pila = ''}) => datosDelError(
        mensaje: mensaje,
        pila: pila,
        contexto: '',
        plataforma: 'android',
        version: 'v1.0.0 (1)',
        idUsuario: 'u1',
        rol: 'Cajero',
        idNegocio: 'n1',
      );

  test('guarda solo los campos permitidos por las reglas', () {
    expect(datos().keys.toSet(), {
      'mensaje', 'pila', 'contexto', 'plataforma', 'version', 'idUsuario', 'rol', 'idNegocio',
    });
  });

  test('recorta los textos largos al tamaño que aceptan las reglas', () {
    final d = datos(mensaje: 'x' * 2000, pila: 'y' * 10000);
    expect((d['mensaje'] as String).length, 500);
    expect((d['pila'] as String).length, 3000);
  });

  test('no toca los textos cortos', () {
    expect(datos(mensaje: 'Null check')['mensaje'], 'Null check');
  });
}
