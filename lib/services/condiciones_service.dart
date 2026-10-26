import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/condiciones_negocio.dart';

/// Condiciones de cada restaurante para sus clientes, reglas internas para
/// su personal, y la aceptación de cada cliente.
class CondicionesService {
  CondicionesService._();
  static final instancia = CondicionesService._();

  final _db = FirebaseFirestore.instance;

  /// Versión nueva cada vez que se guarda (fecha y hora: fácil de leer).
  static String nuevaVersion([DateTime? ahora]) {
    final d = ahora ?? DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dos(d.month)}-${dos(d.day)} ${dos(d.hour)}:${dos(d.minute)}';
  }

  /// El Administrador guarda las condiciones para sus clientes. Sube la
  /// versión: cada cliente las acepta de nuevo antes de su próximo pedido.
  Future<CondicionesNegocio> guardarCondiciones(String idNegocio, CondicionesNegocio c) async {
    final nueva = CondicionesNegocio(
      version: nuevaVersion(),
      reembolso: c.reembolso,
      diasReembolso: c.diasReembolso,
      tiempoEntrega: c.tiempoEntrega.trim(),
      contactoReclamos: c.contactoReclamos.trim(),
      notas: c.notas.trim(),
    );
    await _db.collection('negocios').doc(idNegocio).update({'condiciones': nueva.toMap()});
    return nueva;
  }

  /// El Administrador guarda las reglas internas de su personal. Sube la
  /// versión: todo el personal vuelve a firmar su acuerdo.
  Future<ReglasPersonal> guardarReglas(String idNegocio, List<String> reglas) async {
    final nuevas = ReglasPersonal(
      version: nuevaVersion(),
      reglas: [for (final r in reglas) if (r.trim().isNotEmpty) r.trim()],
    );
    await _db.collection('negocios').doc(idNegocio).update({'reglasPersonal': nuevas.toMap()});
    return nuevas;
  }

  DocumentReference<Map<String, dynamic>> _membresia(String uid, String idNegocio) =>
      _db.collection('usuarios').doc(uid).collection('misNegocios').doc(idNegocio);

  /// Versión de las condiciones del restaurante que el cliente aceptó
  /// (null si todavía no aceptó ninguna).
  Future<String?> versionAceptada(String uid, String idNegocio) async {
    final d = (await _membresia(uid, idNegocio).get()).data();
    if (d == null || d['condicionesAceptadasEn'] == null) return null;
    return d['condicionesVersion'] as String? ?? '';
  }

  Future<void> aceptarCondiciones(String uid, String idNegocio, String version) =>
      _membresia(uid, idNegocio).update({
        'condicionesVersion': version,
        'condicionesAceptadasEn': FieldValue.serverTimestamp(),
      });
}
