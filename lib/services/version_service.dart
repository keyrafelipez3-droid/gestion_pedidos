import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Versión publicada de la app, guardada en `plataforma/app`. La edita el
/// SuperAdmin (pantalla "Versiones de la app") cada vez que sube una APK
/// nueva o despliega la web.
class VersionPublicada {
  /// Versión visible, por ejemplo "1.1.0".
  final String version;

  /// Número de compilación (el que va después del "+" en pubspec.yaml).
  final int build;

  /// Las instalaciones con un número menor a este ya no pueden usarse
  /// (por ejemplo, después de un cambio de seguridad). 0 = ninguna.
  final int buildMinimo;

  /// Enlace de descarga de la APK (Google Drive, Play Store, etc.).
  final String urlApk;

  /// Novedades que se muestran en el aviso.
  final String notas;

  const VersionPublicada({
    required this.version,
    required this.build,
    this.buildMinimo = 0,
    this.urlApk = '',
    this.notas = '',
  });

  factory VersionPublicada.desde(Map<String, dynamic> d) => VersionPublicada(
        version: d['version'] as String? ?? '',
        build: (d['build'] as num?)?.toInt() ?? 0,
        buildMinimo: (d['buildMinimo'] as num?)?.toInt() ?? 0,
        urlApk: d['urlApk'] as String? ?? '',
        notas: d['notas'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'version': version,
        'build': build,
        'buildMinimo': buildMinimo,
        'urlApk': urlApk,
        'notas': notas,
      };
}

enum EstadoActualizacion { alDia, disponible, obligatoria }

/// Compara la instalación con la versión publicada.
EstadoActualizacion estadoActualizacion({
  required int buildInstalado,
  required VersionPublicada? publicada,
}) {
  // Sin datos (o en un entorno sin número de compilación) no se molesta.
  if (publicada == null || buildInstalado <= 0) return EstadoActualizacion.alDia;
  if (buildInstalado < publicada.buildMinimo) return EstadoActualizacion.obligatoria;
  if (buildInstalado < publicada.build) return EstadoActualizacion.disponible;
  return EstadoActualizacion.alDia;
}

class VersionService {
  VersionService._();
  static final instancia = VersionService._();

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('plataforma').doc('app');

  Future<PackageInfo>? _info;

  /// Datos de la app instalada (versión y número de compilación).
  Future<PackageInfo> info() => _info ??= PackageInfo.fromPlatform();

  Future<int> buildInstalado() async => int.tryParse((await info()).buildNumber) ?? 0;

  /// "v1.0.0 (1)".
  Future<String> etiqueta() async {
    final i = await info();
    return i.buildNumber.isEmpty ? 'v${i.version}' : 'v${i.version} (${i.buildNumber})';
  }

  /// Versión publicada en vivo. Si no se puede leer, se considera al día.
  Stream<VersionPublicada?> stream() => _doc
      .snapshots()
      .map((s) => s.exists ? VersionPublicada.desde(s.data()!) : null)
      .handleError((_) {});

  Future<VersionPublicada?> leer() async {
    final s = await _doc.get();
    return s.exists ? VersionPublicada.desde(s.data()!) : null;
  }

  Future<void> publicar(VersionPublicada v, {required String uid}) => _doc.set({
        ...v.toMap(),
        'actualizadoPor': uid,
        'actualizado': FieldValue.serverTimestamp(),
      });
}
