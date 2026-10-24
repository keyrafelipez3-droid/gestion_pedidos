import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_pedidos/services/version_service.dart';

void main() {
  const publicada = VersionPublicada(version: '1.2.0', build: 5, buildMinimo: 3);

  test('al día si tiene la última compilación (o una más nueva)', () {
    expect(estadoActualizacion(buildInstalado: 5, publicada: publicada), EstadoActualizacion.alDia);
    expect(estadoActualizacion(buildInstalado: 6, publicada: publicada), EstadoActualizacion.alDia);
  });

  test('aviso opcional entre el mínimo y la última', () {
    expect(estadoActualizacion(buildInstalado: 3, publicada: publicada), EstadoActualizacion.disponible);
    expect(estadoActualizacion(buildInstalado: 4, publicada: publicada), EstadoActualizacion.disponible);
  });

  test('obligatoria por debajo del mínimo', () {
    expect(estadoActualizacion(buildInstalado: 2, publicada: publicada), EstadoActualizacion.obligatoria);
  });

  test('sin datos no molesta a nadie', () {
    expect(estadoActualizacion(buildInstalado: 1, publicada: null), EstadoActualizacion.alDia);
    expect(estadoActualizacion(buildInstalado: 0, publicada: publicada), EstadoActualizacion.alDia);
  });

  test('lee el documento de Firestore aunque falten campos', () {
    final v = VersionPublicada.desde({'version': '1.1.0', 'build': 2});
    expect(v.buildMinimo, 0);
    expect(v.urlApk, '');
    expect(v.toMap()['build'], 2);
  });
}
