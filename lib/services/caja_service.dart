import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caja_models.dart';
import '../models/mesa_model.dart';
import '../models/pedido_models.dart';
import '../models/usuario_model.dart';
import '../utils/errores.dart';

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

  /// Pedidos que se cobran en un mismo lote. Las reglas de Firestore leen
  /// cada pedido antes y después del cobro, y un lote admite pocas lecturas.
  static const _pedidosPorLote = 8;

  /// Movimiento de cobro de UN pedido. Su id es fijo (`cobro_{idPedido}`):
  /// las reglas exigen que en el mismo lote el pedido pase a cobrado en
  /// esta caja, así un pedido no se cobra dos veces ni en dos cajas.
  void _agregarCobro(
    WriteBatch lote,
    CajaModel caja,
    PedidoModel pedido, {
    required String concepto,
    required String metodoPago,
    required String idUsuario,
    String? idMesa,
  }) {
    lote.set(_movimientos(caja.id).doc('cobro_${pedido.id}'), {
      'tipo': MovimientoTipo.cobro,
      'concepto': concepto,
      // Productos + envío (la propina es del repartidor, no de la caja).
      'monto': redondearDinero(pedido.montoNegocio),
      'metodoPago': metodoPago,
      'idPedido': pedido.id,
      if (idMesa != null) 'idMesa': idMesa,
      'idUsuario': idUsuario,
      'fecha': FieldValue.serverTimestamp(),
    });
  }

  /// Cobra la cuenta abierta de una mesa: un movimiento por cada pedido no
  /// cancelado, y esos pedidos quedan cobrados y fuera de la cuenta
  /// abierta. Un pedido ya cobrado nunca se suma dos veces. Liberar la mesa
  /// en sí lo hace MesaService.liberarMesa.
  Future<void> cobrarMesa({
    required CajaModel caja,
    required MesaModel mesa,
    required String metodoPago,
    required String idUsuario,
  }) async {
    final qs = await _db
        .collection('pedidos')
        .where('idNegocio', isEqualTo: caja.idNegocio)
        // La caja es de la sucursal del cajero (las reglas lo exigen).
        .where('idSucursal', isEqualTo: caja.idSucursal)
        .where('idMesa', isEqualTo: mesa.id)
        .where('cuentaAbierta', isEqualTo: true)
        .get();
    final pedidos = qs.docs.map(PedidoModel.fromSnapshot).toList();
    for (var i = 0; i < pedidos.length; i += _pedidosPorLote) {
      final lote = _db.batch();
      for (final pedido in pedidos.skip(i).take(_pedidosPorLote)) {
        final ref = _db.collection('pedidos').doc(pedido.id);
        if (pedido.estado == PedidoEstado.cancelado || pedido.cobrado) {
          lote.update(ref, {'cuentaAbierta': false});
          continue;
        }
        lote.update(ref, {
          'cuentaAbierta': false,
          'cobrado': true,
          'idCaja': caja.id,
          'metodoPago': metodoPago,
        });
        _agregarCobro(lote, caja, pedido,
            concepto: 'Mesa ${mesa.numero} · #${pedido.id.substring(0, 6)}',
            metodoPago: metodoPago,
            idUsuario: idUsuario,
            idMesa: mesa.id);
      }
      await lote.commit();
    }
  }

  /// El Cajero entrega un pedido y lo cobra en SU caja, en UNA sola
  /// transacción: lee el pedido y la caja, comprueba que el pedido siga
  /// sin cobrar y que la caja esté abierta y sin contar, y escribe el
  /// pedido (Entregado y cobrado), el movimiento y el historial juntos. Si
  /// otra persona lo cobró o lo cambió al mismo tiempo, no se cobra dos
  /// veces: la transacción lo detecta.
  Future<void> entregarYCobrar({
    required CajaModel caja,
    required PedidoModel pedido,
    required String idUsuario,
  }) async {
    final ref = _db.collection('pedidos').doc(pedido.id);
    final refCaja = _cajas.doc(caja.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final snapCaja = await tx.get(refCaja);
      if (!snap.exists) {
        throw const PedidoEstadoException('El pedido ya no existe.');
      }
      final actual = PedidoModel.fromSnapshot(snap);
      if (actual.cobrado) {
        throw const PedidoEstadoException('Este pedido ya se cobró.');
      }
      if (!PedidoEstado.puedePasar(actual.estado, PedidoEstado.entregado)) {
        throw PedidoEstadoException(
          'No se puede pasar de "${actual.estado}" a "${PedidoEstado.entregado}". '
          'Es posible que otra persona lo haya cambiado.',
        );
      }
      final datosCaja = snapCaja.data();
      if (datosCaja == null ||
          datosCaja['estado'] != CajaEstado.abierta ||
          datosCaja['montoContado'] != null) {
        throw const PedidoEstadoException('Tu caja ya no está abierta para cobrar.');
      }
      tx.update(ref, {
        'estado': PedidoEstado.entregado,
        'cobrado': true,
        'idCaja': caja.id,
      });
      tx.set(_movimientos(caja.id).doc('cobro_${actual.id}'), {
        'tipo': MovimientoTipo.cobro,
        'concepto': 'Pedido #${actual.id.substring(0, 6)}',
        'monto': redondearDinero(actual.montoNegocio),
        'metodoPago': actual.metodoPago,
        'idPedido': actual.id,
        'idUsuario': idUsuario,
        'fecha': FieldValue.serverTimestamp(),
      });
      tx.set(
        ref.collection('historialEstados').doc(),
        HistorialEstadoModel(
          id: '',
          estado: PedidoEstado.entregado,
          idUsuarioQueCambio: idUsuario,
          comentario: 'Entregado y cobrado en caja.',
        ).toMap(),
      );
    });
  }

  /// Rendición del repartidor: registra en la caja los pedidos de delivery
  /// que entregó (efectivo que trae y pagos por QR/transferencia ya
  /// recibidos). Un pedido ya cobrado no se repite. Devuelve cuántos
  /// pedidos se registraron.
  Future<int> recibirRendicion({
    required CajaModel caja,
    required List<PedidoModel> pedidos,
    required String idUsuario,
  }) async {
    final pendientes = pedidos.where((p) => !p.cobrado).toList();
    for (var i = 0; i < pendientes.length; i += _pedidosPorLote) {
      final lote = _db.batch();
      for (final pedido in pendientes.skip(i).take(_pedidosPorLote)) {
        _agregarCobro(lote, caja, pedido,
            concepto: 'Delivery #${pedido.id.substring(0, 6)} · ${pedido.nombreRepartidor ?? 'Repartidor'}',
            metodoPago: pedido.metodoPago,
            idUsuario: idUsuario);
        lote.update(_db.collection('pedidos').doc(pedido.id), {
          'cobrado': true,
          'idCaja': caja.id,
        });
      }
      await lote.commit();
    }
    return pendientes.length;
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
