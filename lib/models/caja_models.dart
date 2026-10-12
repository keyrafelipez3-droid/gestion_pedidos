import 'package:cloud_firestore/cloud_firestore.dart';

import 'pedido_models.dart';

/// HU-46: la caja es el "cajón de plata" de UN Cajero durante UN turno.
class CajaEstado {
  static const String abierta = 'Abierta';
  static const String cerrada = 'Cerrada';
}

/// Tipos de movimiento dentro de una caja.
///
/// - `Cobro`: plata que entra por un pedido (mesa o pedido del cliente).
/// - `Ingreso`: plata que el negocio pone en el cajón a mano (siempre efectivo).
/// - `Egreso`: plata que sale del cajón a mano, ej. comprar gas (siempre efectivo).
class MovimientoTipo {
  static const String cobro = 'Cobro';
  static const String ingreso = 'Ingreso';
  static const String egreso = 'Egreso';
  static const List<String> todos = [cobro, ingreso, egreso];
}

/// Redondea a 2 decimales para que las sumas de dinero no arrastren
/// errores de punto flotante (ej. 0.1 + 0.2).
double redondearDinero(double valor) => (valor * 100).round() / 100;

/// Documento de `cajas/{idCaja}`. Un Cajero solo puede tener UNA caja
/// `Abierta` a la vez.
///
/// Flujo de cierre "ciego": el Cajero primero registra cuánto contó
/// (`montoContado`) SIN ver cuánto debería haber; recién después se
/// calcula la diferencia y se cierra (`estado == Cerrada`).
class CajaModel {
  final String id;
  final String idNegocio;
  final String idSucursal;
  final String idCajero;
  final String nombreCajero;
  final String estado;
  final double montoInicial;
  final DateTime? fechaApertura;

  /// Efectivo que el Cajero contó al cerrar. Una vez registrado ya no se
  /// puede cambiar ni agregar movimientos (la caja queda "en cierre").
  final double? montoContado;
  final DateTime? fechaConteo;

  // Se llenan al cerrar (foto del turno, no se vuelven a tocar).
  final DateTime? fechaCierre;
  final double? montoEsperado;
  final double? diferencia;
  final String observacionCierre;
  final double? totalEfectivo;
  final double? totalTransferencia;
  final double? totalQr;
  final double? totalIngresos;
  final double? totalEgresos;

  const CajaModel({
    required this.id,
    required this.idNegocio,
    required this.idSucursal,
    required this.idCajero,
    required this.nombreCajero,
    required this.estado,
    required this.montoInicial,
    this.fechaApertura,
    this.montoContado,
    this.fechaConteo,
    this.fechaCierre,
    this.montoEsperado,
    this.diferencia,
    this.observacionCierre = '',
    this.totalEfectivo,
    this.totalTransferencia,
    this.totalQr,
    this.totalIngresos,
    this.totalEgresos,
  });

  bool get abierta => estado == CajaEstado.abierta;

  /// Ya se registró el conteo: solo falta cerrar.
  bool get contada => montoContado != null;

  factory CajaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    double? num_(String k) => (d[k] as num?)?.toDouble();
    DateTime? ts(String k) => (d[k] as Timestamp?)?.toDate();
    return CajaModel(
      id: doc.id,
      idNegocio: d['idNegocio'] as String? ?? '',
      idSucursal: d['idSucursal'] as String? ?? '',
      idCajero: d['idCajero'] as String? ?? '',
      nombreCajero: d['nombreCajero'] as String? ?? '',
      estado: d['estado'] as String? ?? CajaEstado.abierta,
      montoInicial: num_('montoInicial') ?? 0,
      fechaApertura: ts('fechaApertura'),
      montoContado: num_('montoContado'),
      fechaConteo: ts('fechaConteo'),
      fechaCierre: ts('fechaCierre'),
      montoEsperado: num_('montoEsperado'),
      diferencia: num_('diferencia'),
      observacionCierre: d['observacionCierre'] as String? ?? '',
      totalEfectivo: num_('totalEfectivo'),
      totalTransferencia: num_('totalTransferencia'),
      totalQr: num_('totalQr'),
      totalIngresos: num_('totalIngresos'),
      totalEgresos: num_('totalEgresos'),
    );
  }
}

/// Documento de `cajas/{idCaja}/movimientos/{id}`. Nunca se edita ni se
/// borra: un error se corrige con un movimiento contrario y su concepto.
class MovimientoCajaModel {
  final String id;
  final String tipo;
  final String concepto;
  final double monto; // siempre positivo
  final String metodoPago;
  final String? idPedido;
  final String? idMesa;
  final String idUsuario;
  final DateTime? fecha;

  const MovimientoCajaModel({
    required this.id,
    required this.tipo,
    required this.concepto,
    required this.monto,
    required this.metodoPago,
    this.idPedido,
    this.idMesa,
    required this.idUsuario,
    this.fecha,
  });

  bool get esEfectivo => metodoPago == MetodoPago.efectivo;

  factory MovimientoCajaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MovimientoCajaModel(
      id: doc.id,
      tipo: d['tipo'] as String? ?? MovimientoTipo.cobro,
      concepto: d['concepto'] as String? ?? '',
      monto: (d['monto'] as num?)?.toDouble() ?? 0,
      metodoPago: d['metodoPago'] as String? ?? MetodoPago.efectivo,
      idPedido: d['idPedido'] as String?,
      idMesa: d['idMesa'] as String?,
      idUsuario: d['idUsuario'] as String? ?? '',
      fecha: (d['fecha'] as Timestamp?)?.toDate(),
    );
  }
}

/// Totales de una caja, calculados SIEMPRE desde sus movimientos (no hay
/// contadores sueltos que puedan desfasarse).
///
/// El efectivo esperado solo cuenta plata física: monto inicial + cobros
/// en efectivo + ingresos − egresos. Transferencia y QR van al banco, no
/// al cajón, así que se muestran aparte solo como información.
class ResumenCaja {
  final double montoInicial;
  final double cobrosEfectivo;
  final double cobrosTransferencia;
  final double cobrosQr;
  final double ingresos;
  final double egresos;

  const ResumenCaja({
    required this.montoInicial,
    required this.cobrosEfectivo,
    required this.cobrosTransferencia,
    required this.cobrosQr,
    required this.ingresos,
    required this.egresos,
  });

  double get esperado =>
      redondearDinero(montoInicial + cobrosEfectivo + ingresos - egresos);

  factory ResumenCaja.de(double montoInicial, List<MovimientoCajaModel> movimientos) {
    double efectivo = 0, transferencia = 0, qr = 0, ingresos = 0, egresos = 0;
    for (final m in movimientos) {
      switch (m.tipo) {
        case MovimientoTipo.ingreso:
          ingresos += m.monto;
          break;
        case MovimientoTipo.egreso:
          egresos += m.monto;
          break;
        default:
          if (m.metodoPago == MetodoPago.transferencia) {
            transferencia += m.monto;
          } else if (m.metodoPago == MetodoPago.qr) {
            qr += m.monto;
          } else {
            efectivo += m.monto;
          }
      }
    }
    return ResumenCaja(
      montoInicial: montoInicial,
      cobrosEfectivo: redondearDinero(efectivo),
      cobrosTransferencia: redondearDinero(transferencia),
      cobrosQr: redondearDinero(qr),
      ingresos: redondearDinero(ingresos),
      egresos: redondearDinero(egresos),
    );
  }
}
