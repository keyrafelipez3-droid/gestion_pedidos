import 'package:cloud_firestore/cloud_firestore.dart';

/// Cupón de descuento de un negocio: `negocios/{id}/cupones/{CODIGO}`.
/// El id del documento es el código en mayúsculas (ej. CARO10).
class CuponModel {
  static const porcentaje = 'porcentaje';
  static const monto = 'monto';

  final String codigo;
  final String tipo; // porcentaje | monto
  final double valor; // 10 = 10 % o Bs 10
  final double minimo; // compra mínima en Bs (0 = sin mínimo)
  final DateTime? vence; // null = no vence
  final bool activo;
  final String descripcion;

  const CuponModel({
    required this.codigo,
    this.tipo = porcentaje,
    required this.valor,
    this.minimo = 0,
    this.vence,
    this.activo = true,
    this.descripcion = '',
  });

  bool get vencido => vence != null && vence!.isBefore(DateTime.now());
  bool get vigente => activo && !vencido;

  /// "10 %" o "Bs 15.00".
  String get etiquetaValor =>
      tipo == porcentaje ? '${valor.toStringAsFixed(valor % 1 == 0 ? 0 : 1)} %' : 'Bs ${valor.toStringAsFixed(2)}';

  /// Descuento para una compra de [subtotal] Bs (nunca más que el subtotal).
  double descuentoPara(double subtotal) {
    final d = tipo == porcentaje ? subtotal * valor / 100 : valor;
    final redondeado = (d * 100).floorToDouble() / 100;
    return redondeado > subtotal ? subtotal : redondeado;
  }

  Map<String, dynamic> toMap() => {
        'tipo': tipo,
        'valor': valor,
        'minimo': minimo,
        'vence': vence == null ? null : Timestamp.fromDate(vence!),
        'activo': activo,
        'descripcion': descripcion,
      };

  factory CuponModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CuponModel(
      codigo: doc.id,
      tipo: d['tipo'] as String? ?? porcentaje,
      valor: (d['valor'] as num?)?.toDouble() ?? 0,
      minimo: (d['minimo'] as num?)?.toDouble() ?? 0,
      vence: (d['vence'] as Timestamp?)?.toDate(),
      activo: d['activo'] as bool? ?? true,
      descripcion: d['descripcion'] as String? ?? '',
    );
  }
}
