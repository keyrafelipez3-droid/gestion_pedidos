import 'package:flutter_test/flutter_test.dart';

import 'package:gestion_pedidos/config/app_config.dart';
import 'package:gestion_pedidos/legal/textos_legales.dart';
import 'package:gestion_pedidos/models/condiciones_negocio.dart';
import 'package:gestion_pedidos/models/negocio_model.dart';
import 'package:gestion_pedidos/models/usuario_model.dart';
import 'package:gestion_pedidos/services/condiciones_service.dart';

String _todo(List<SeccionLegal> s) =>
    [for (final x in s) ...[x.titulo, x.enSimple ?? '', ...x.parrafos]].join('\n');

void main() {
  const pollos = NegocioModel(
    idNegocio: 'n1',
    nombre: 'Pollos Doña Rosa',
    razonSocial: 'Rosa Quispe SRL',
    nit: '1020304050',
    telefono: '70000000',
    condiciones: CondicionesNegocio(
      version: '2026-10-25 20:00',
      reembolso: CondicionesNegocio.reembolsoCupon,
      diasReembolso: 3,
      contactoReclamos: 'reclamos@pollos.bo',
      notas: 'Los pedidos de más de 10 platos se hacen con un día de anticipación.',
    ),
    reglasPersonal: ReglasPersonal(version: '2026-10-25 21:00', reglas: ['Usar gorro en cocina']),
  );

  test('las condiciones se leen aunque falten datos', () {
    expect(CondicionesNegocio.desde(null).version, '');
    final c = CondicionesNegocio.desde({'version': 'v1', 'diasReembolso': 7, 'reembolso': 'cupon'});
    expect(c.version, 'v1');
    expect(c.diasReembolso, 7);
    expect(c.textoReembolso, contains('cupón'));
    expect(CondicionesNegocio.desde(c.toMap()).toMap(), c.toMap());
    expect(ReglasPersonal.desde({'reglas': ['  a ', '', 3]}).reglas, ['a']);
  });

  test('las condiciones del cliente llevan los datos y reglas de SU restaurante', () {
    final texto = _todo(TextosLegales.condicionesRestaurante(pollos));
    expect(texto, contains('Rosa Quispe SRL'));
    expect(texto, contains('1020304050'));
    expect(texto, contains('reclamos@pollos.bo'));
    expect(texto, contains('10 platos'));
    expect(TextosLegales.tituloCondiciones(pollos), 'Condiciones de Pollos Doña Rosa');
    final resumen = TextosLegales.resumenCondiciones(pollos);
    expect(resumen.length, 5);
    expect(resumen.join(' '), contains('3 días hábiles'));
  });

  test('cada sección tiene su "En simple" y van numeradas', () {
    for (final s in [
      ...TextosLegales.condicionesRestaurante(pollos),
      ...TextosLegales.terminos(),
      ...TextosLegales.politicaPrivacidad(),
    ]) {
      expect(s.enSimple, isNotNull, reason: s.titulo);
      expect(RegExp(r'^\d+\. ').hasMatch(s.titulo), isTrue, reason: s.titulo);
    }
  });

  test('el acuerdo del personal es personal y solo con las tareas de su cargo', () {
    const cocinero = UsuarioModel(
      idUsuario: 'u1', nombre: 'Juan Mamani', email: 'j@x.bo', telefono: '', rol: Rol.cocina);
    final texto = _todo(TextosLegales.acuerdoPersonal(
        negocio: pollos, usuario: cocinero, sucursal: 'Centro'));
    expect(texto, contains('Juan Mamani'));
    expect(texto, contains('Centro'));
    expect(texto, contains('Usar gorro en cocina'));
    expect(texto, contains('alergia'));
    expect(texto, isNot(contains('Abre y cierra tu caja')));
  });

  test('si el restaurante cambia sus reglas, cambia la versión que se firma', () {
    expect(TextosLegales.versionAcuerdo(null), AppConfig.versionAcuerdoPersonal);
    expect(TextosLegales.versionAcuerdo(pollos),
        '${AppConfig.versionAcuerdoPersonal}+2026-10-25 21:00');
  });

  test('la versión nueva es la fecha y hora', () {
    expect(CondicionesService.nuevaVersion(DateTime(2026, 3, 4, 5, 6)), '2026-03-04 05:06');
  });
}
