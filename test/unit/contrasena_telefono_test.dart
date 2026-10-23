import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/utils/contrasena.dart';
import 'package:gestion_pedidos/utils/telefono.dart';

void main() {
  group('contraseñas', () {
    test('rechaza cortas, sin números, comunes o con el correo', () {
      expect(validarContrasena('abc12'), isNotNull);
      expect(validarContrasena('soloLetras'), isNotNull);
      expect(validarContrasena('12345678'), isNotNull);
      expect(validarContrasena('password1'), isNotNull);
      expect(validarContrasena('keyra2026x', correo: 'keyra@gmail.com'), isNotNull);
    });

    test('acepta una contraseña razonable', () {
      expect(validarContrasena('Caro2026!'), isNull);
      expect(validarContrasena('pollo y papas 77'), isNull);
    });

    test('medidor de seguridad', () {
      expect(fuerzaContrasena(''), 0);
      expect(fuerzaContrasena('abc'), 1);
      expect(fuerzaContrasena('Caro2026!seguro'), 4);
    });
  });

  group('teléfonos de Bolivia', () {
    test('celular válido de 8 dígitos', () {
      expect(Telefono.validar(Telefono.bolivia, '71234567', obligatorio: true), isNull);
      expect(Telefono.validar(Telefono.bolivia, '64896530', obligatorio: true), isNull);
    });

    test('con 7 dígitos avisa la cantidad', () {
      final error = Telefono.validar(Telefono.bolivia, '6489653', obligatorio: true);
      expect(error, isNotNull);
      expect(error, contains('7'));
    });

    test('vacío solo es error si es obligatorio', () {
      expect(Telefono.validar(Telefono.bolivia, '', obligatorio: false), isNull);
      expect(Telefono.validar(Telefono.bolivia, '', obligatorio: true), isNotNull);
    });
  });
}
