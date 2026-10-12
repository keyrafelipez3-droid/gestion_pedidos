import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caja_models.dart';
import '../models/mesa_model.dart';
import '../models/pedido_models.dart';
import '../models/usuario_model.dart';

/// HU-46: apertura, movimientos y cierre de caja del Cajero.
///
/// Reglas de negocio (acordadas con Susan):
/// - Una caja por Cajero y por turno; solo una abierta a la vez.
/// - No se cobra sin caja abierta.
/// - Los movimientos no se editan ni se borran.
/// - El efectivo esperado no incluye Transferencia ni QR.
/// - Cierre ciego: primero se registra el conteo, después se ve la
///   diferencia.
class CajaService {
  CajaService._();
  static final instancia = CajaService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _cajas => _db.collection('cajas');

  CollectionReference<Map<String, dynamic>> _movimientos(String idCaja) =>
      _cajas.doc(idCaja).collection('movimientos');

  // ---------------------------------------------------------------- lectura

  /// La caja abierta del Cajero (o null si no tiene). Solo filtros de
  /// igualdad, así no hace falta un índice compuesto.
  Stream<CajaModel?> streamCajaAbierta(String idCajero) => _cajas
          .where('idCajero', isEqualTo: idCajero)
          .where('estado', isEqualTo: CajaEstado.abierta)
          .snapshots()
          .map((qs) {
        if (qs.docs.isEmpty) return null;
        return CajaModel.fromSnapshot(qs.docs.first);
      });

  Future<CajaModel?> cajaAbiertaActual(String idCajero) async {
    final qs = await _cajas
        .where('idCajero', isEqualTo: idCajero)
        .where('estado', isEqualTo: CajaEstado.abierta)
        .get();
    if (qs.docs.isEmpty) return null;
    return CajaModel.fromSnapshot(qs.docs.first);
  }

  /// Cierres anteriores del Cajero, del más reciente al más antiguo.
  Stream<List<CajaModel>> streamHistorial(String idCajero) => _cajas
          .where('idCajero', isEqualTo: idCajero)
          .where('estado', isEqualTo: CajaEstado.cerrada)
          .snapshots()
          .map((qs) {
        final lista = qs.docs.map(CajaModel.fromSnapshot).toList();
        lista.sort((a, b) =>
            (b.fechaCierre ?? DateTime(0)).compareTo(a.fechaCierre ?? DateTime(0)));
        return lista;
      });

  Stream<List<MovimientoCajaModel>> streamMovimientos(String idCaja) =>
      _movimientos(idCaja).snapshots().map((qs) {
        final lista = qs.docs.map(MovimientoCajaModel.fromSnapshot).toList();
        // Un movimiento recién creado todavía no tiene la hora del
        // servidor (fecha null): se muestra primero, como "ahora".
        final ahora = DateTime.now();
        lista.sort((a, b) => (b.fecha ?? ahora).compareTo(a.fecha ?? ahora));
        return lista;
      });

  Future<ResumenCaja> _resumenActual(CajaModel caja) async {
    final qs = await _movimientos(caja.id).get();
    return ResumenCaja.de(
      caja.montoInicial,
      qs.docs.map(MovimientoCajaModel.fromSnapshot).toList(),
    );
  }

  // --------------------------------------------------------------- apertura

  Future<void> abrirCaja({
    required UsuarioModel cajero,
    required double montoInicial,
  }) async {
    final idNegocio = cajero.idNegocio;
    final idSucursal = cajero.idSucursal;
    if (idNegocio == null || idSucursal == null) {
      throw Exception('Tu usuario no tiene sucursal asignada. Pídele al Administrador que te la asigne.');
    }
    if (montoInicial < 0) {
      throw Exception('El monto inicial no puede ser negativo.');
    }
    if (await cajaAbiertaActual(cajero.idUsuario) != null) {
      throw Exception('Ya tienes una caja abierta.');
    }
    await _cajas.add({
      'idNegocio': idNegocio,
      'idSucursal': idSucursal,
      'idCajero': cajero.idUsuario,
      'nombreCajero': cajero.nombre,
      'estado': CajaEstado.abierta,
      'montoInicial': redondearDinero(montoInicial),
      'fechaApertura': FieldValue.serverTimestamp(),
    });
  }

  // ------------------------------------------------------------ movimientos

  /// Ingreso o egreso manual (siempre efectivo). El egreso no puede dejar
  /// el efectivo del cajón en negativo.
  Future<void> registrarMovimientoManual({
    required CajaModel caja,
    required String tipo,
    required String concepto,
    required double monto,
    required String idUsuario,
  }) async {
    if (tipo != MovimientoTipo.ingreso && tipo != MovimientoTipo.egreso) {
      throw Exception('Tipo de movimiento no válido.');
    }
    final conceptoLimpio = concepto.trim();
    if (conceptoLimpio.isEmpty) {
      throw Exception('Escribe el concepto del movimiento.');
    }
    if (monto <= 0) {
      throw Exception('El monto debe ser mayor a cero.');
    }
    final montoFinal = redondearDinero(monto);
    if (tipo == MovimientoTipo.egreso) {
      final resumen = await _resumenActual(caja);
      if (montoFinal > resumen.esperado) {
        throw Exception('No hay suficiente efectivo en la caja para ese egreso.');
      }
    }
    await _movimientos(caja.id).add({
      'tipo': tipo,
      'concepto': conceptoLimpio,
      'monto': montoFinal,
      'metodoPago': MetodoPago.efectivo,
      'idUsuario': idUsuario,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  /// Cobra la cuenta abierta de una mesa: un solo movimiento con el total
  /// de los pedidos no cancelados, y deja esos pedidos como cobrados y
  /// fuera de la cuenta abierta. Un pedido ya cobrado nunca se suma dos
  /// veces. Liberar la mesa en sí lo hace MesaService.liberarMesa.
  Future<void> cobrarMesa({
    required CajaModel caja,
    required MesaModel mesa,
    required String metodoPago,
    required String idUsuario,
  }) async {
    final qs = await _db
        .collection('pedidos')
        .where('idNegocio', isEqualTo: caja.idNegocio)
        .where('idMesa', isEqualTo: mesa.id)
        .where('cuentaAbierta', isEqualTo: true)
        .get();
    if (qs.docs.isEmpty) return;

    final batch = _db.batch();
    double total = 0;
    final idsCobrados = <String>[];
    for (final doc in qs.docs) {
      final data = doc.data();
      final cancelado = data['estado'] == PedidoEstado.cancelado;
      final yaCobrado = data['cobrado'] == true;
      if (cancelado || yaCobrado) {
        batch.update(doc.reference, {'cuentaAbierta': false});
        continue;
      }
      total += (data['total'] as num?)?.toDouble() ?? 0;
      idsCobrados.add(doc.id);
      batch.update(doc.reference, {
        'cuentaAbierta': false,
        'cobrado': true,
        'idCaja': caja.id,
        'metodoPago': metodoPago,
      });
    }
    total = redondearDinero(total);
    if (total > 0) {
      batch.set(_movimientos(caja.id).doc(), {
        'tipo': MovimientoTipo.cobro,
        'concepto': 'Mesa ${mesa.numero}',
        'monto': total,
        'metodoPago': metodoPago,
        'idMesa': mesa.id,
        'idsPedidos': idsCobrados,
        'idUsuario': idUsuario,
        'fecha': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  /// Cobra un pedido de un cliente (Recoger o Mesa elegido en la app)
  /// cuando el Cajero lo entrega. El id del movimiento es fijo
  /// (`cobro_{idPedido}`), así que un doble clic o un reintento no lo
  /// registra dos veces.
  Future<void> cobrarPedido({
    required CajaModel caja,
    required PedidoModel pedido,
    required String idUsuario,
  }) async {
    if (pedido.cobrado) return;
    final batch = _db.batch();
    batch.set(_movimientos(caja.id).doc('cobro_${pedido.id}'), {
      'tipo': MovimientoTipo.cobro,
      'concepto': 'Pedido #${pedido.id.substring(0, 6)}',
      'monto': redondearDinero(pedido.total),
      'metodoPago': pedido.metodoPago,
      'idPedido': pedido.id,
      'idUsuario': idUsuario,
      'fecha': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection('pedidos').doc(pedido.id), {
      'cobrado': true,
      'idCaja': caja.id,
    });
    await batch.commit();
  }

  // ----------------------------------------------------------------- cierre

  /// Paso 1 del cierre ciego: el Cajero registra cuánto efectivo contó.
  /// Después ya no se puede cambiar ni registrar más movimientos.
  Future<void> registrarConteo(CajaModel caja, double montoContado) async {
    if (montoContado < 0) {
      throw Exception('El monto contado no puede ser negativo.');
    }
    await _cajas.doc(caja.id).update({
      'montoContado': redondearDinero(montoContado),
      'fechaConteo': FieldValue.serverTimestamp(),
    });
  }

  /// Paso 2: cierra la caja. Calcula el efectivo esperado y la diferencia
  /// desde los movimientos y los deja guardados como foto del turno.
  /// La observación es obligatoria si hay diferencia.
  Future<CajaModel> cerrarCaja(CajaModel caja, {String observacion = ''}) async {
    final contado = caja.montoContado;
    if (contado == null) {
      throw Exception('Primero registra el efectivo que contaste.');
    }
    final resumen = await _resumenActual(caja);
    final diferencia = redondearDinero(contado - resumen.esperado);
    final obs = observacion.trim();
    if (diferencia != 0 && obs.isEmpty) {
      throw Exception('Hay diferencia en la caja: escribe una observación.');
    }
    await _cajas.doc(caja.id).update({
      'estado': CajaEstado.cerrada,
      'fechaCierre': FieldValue.serverTimestamp(),
      'montoEsperado': resumen.esperado,
      'diferencia': diferencia,
      'observacionCierre': obs,
      'totalEfectivo': resumen.cobrosEfectivo,
      'totalTransferencia': resumen.cobrosTransferencia,
      'totalQr': resumen.cobrosQr,
      'totalIngresos': resumen.ingresos,
      'totalEgresos': resumen.egresos,
    });
    return CajaModel.fromSnapshot(await _cajas.doc(caja.id).get());
  }

  /// Resumen calculado para mostrar en pantalla cuando la caja ya fue
  /// contada (el Cajero ve el esperado recién entonces).
  Future<ResumenCaja> resumenDe(CajaModel caja) => _resumenActual(caja);
}
