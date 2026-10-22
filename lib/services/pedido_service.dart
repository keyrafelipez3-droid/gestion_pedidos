import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
import '../models/alergenos.dart';
import '../models/carrito_models.dart';
import '../models/mesa_model.dart';
import '../models/pedido_models.dart';
import '../utils/errores.dart';
import 'carrito_service.dart';
import 'cupon_service.dart';
import 'sesion_actual.dart';

/// HU-24 a HU-31: confirmar pedido (a partir del carrito), consultarlo,
/// y que el personal del negocio (Cajero/Cocina/Administrador) lo
/// gestione y cambie de estado.
class PedidoService {
  PedidoService._();
  static final instancia = PedidoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pedidos => _db.collection('pedidos');

  /// HU-24/HU-26: confirma el pedido a partir de los items ya cargados
  /// del carrito (se los pasa la pantalla, que ya los tiene vía
  /// CarritoService.streamCarrito). Crea el pedido + su detalle + el
  /// primer renglón de historialEstados, y al final vacía el carrito de
  /// ese negocio. Devuelve el id del pedido creado.
  Future<String> confirmarPedido({
    required String idCliente,
    required String idNegocio,
    required String idSucursal,
    required String modalidad,
    String? idMesa,
    Map<String, dynamic>? direccionEntrega,
    required String metodoPago,
    String? comprobantePagoUrl,
    required List<CarritoItemModel> itemsCarrito,
    String notas = '',
    List<String> alergias = const [],
    String? codigoCupon,
    double propina = 0,
    DateTime? programadoPara,
    String? facturaNit,
    String? facturaRazonSocial,
  }) async {
    if (itemsCarrito.isEmpty) {
      throw Exception(tr('El carrito está vacío, no se puede confirmar el pedido.'));
    }

    final subtotal = itemsCarrito.fold<double>(0, (acc, item) => acc + item.subtotal);
    // El cupón se vuelve a comprobar aquí (pudo vencer o pausarse mientras
    // el cliente confirmaba).
    final cupon = codigoCupon == null
        ? null
        : await CuponService.instancia.validar(idNegocio, codigoCupon, subtotal);
    final descuento = cupon?.descuentoPara(subtotal) ?? 0;
    final total = double.parse((subtotal - descuento).toStringAsFixed(2));
    if (total <= 0) {
      throw Exception(tr('El total del pedido debe ser mayor a 0.'));
    }

    await _registrarClienteEnNegocio(idNegocio: idNegocio, idCliente: idCliente);

    final pedidoDoc = _pedidos.doc();
    final numeroMesa = await _numeroDeMesa(idSucursal, idMesa);

    // Solo en delivery: nombre y teléfono para que el repartidor pueda
    // contactar al cliente durante la entrega (y nadie más que el personal
    // de este negocio los ve; se borran si el cliente elimina su cuenta).
    final esDelivery = modalidad == PedidoModalidad.delivery;
    final usuario = SesionActual.instancia.actual;
    final telefonoCliente = usuario?.telefono ?? '';

    final pedido = PedidoModel(
      id: pedidoDoc.id,
      nombreCliente: esDelivery ? usuario?.nombre : null,
      telefonoCliente: esDelivery && telefonoCliente.isNotEmpty ? telefonoCliente : null,
      idCliente: idCliente,
      idNegocio: idNegocio,
      idSucursal: idSucursal,
      modalidad: modalidad,
      idMesa: idMesa,
      numeroMesa: numeroMesa,
      direccionEntrega: direccionEntrega,
      metodoPago: metodoPago,
      comprobantePagoUrl: comprobantePagoUrl,
      estado: PedidoEstado.pendiente,
      total: total,
      notas: notas,
      alergias: Alergenos.ordenar(alergias),
      // Idioma en que el cliente escribió sus notas: el personal las ve
      // traducidas al español.
      idiomaCliente: IdiomaController.instancia.codigo.value,
      codigoCupon: cupon?.codigo,
      descuento: descuento,
      propina: modalidad == PedidoModalidad.delivery && propina > 0 ? propina : 0,
      programadoPara: programadoPara,
      facturaNit: (facturaNit ?? '').trim().isEmpty ? null : facturaNit!.trim(),
      facturaRazonSocial: (facturaNit ?? '').trim().isEmpty ? null : (facturaRazonSocial ?? '').trim(),
    );

    // OJO (bug encontrado probando): el pedido se crea en un PRIMER
    // commit, solo, y recién en un SEGUNDO commit se agregan detalle +
    // historialEstados. No se puede hacer todo en un solo batch: las
    // reglas de detalle/historialEstados necesitan leer (get()) el
    // documento del pedido para confirmar que es tuyo, y esa lectura NO
    // ve los demás escrituras del mismo batch todavía sin confirmar
    // (Firestore evalúa las reglas de un batch contra el estado ANTES
    // del batch) — por eso fallaba con "permission-denied" aunque la
    // regla de creación del pedido en sí era correcta.
    await pedidoDoc.set(pedido.toMap());

    final batch = _db.batch();

    for (final item in itemsCarrito) {
      final detalle = DetallePedidoModel(
        id: '',
        idProducto: item.idProducto,
        nombreProducto: item.nombreProducto,
        precioUnitario: item.precioUnitario,
        cantidad: item.cantidad,
        variantes: item.variantes,
        complementos: item.complementos,
        notas: item.notas,
        subtotal: item.subtotal,
      );
      batch.set(pedidoDoc.collection('detalle').doc(), detalle.toMap());
    }

    final historial = HistorialEstadoModel(
      id: '',
      estado: PedidoEstado.pendiente,
      idUsuarioQueCambio: idCliente,
      comentario: 'Pedido creado por el cliente.',
    );
    batch.set(pedidoDoc.collection('historialEstados').doc(), historial.toMap());

    await batch.commit();

    // El carrito ya se copió al pedido, así que se vacía para que no
    // quede duplicado si el cliente abre el carrito de nuevo.
    await _items(idCliente).where('idNegocio', isEqualTo: idNegocio).get().then((qs) async {
      final limpiarBatch = _db.batch();
      for (final doc in qs.docs) {
        limpiarBatch.delete(doc.reference);
      }
      await limpiarBatch.commit();
    });

    return pedidoDoc.id;
  }

  /// Deja registrado al cliente en este negocio (`negocios/{id}/clientes`)
  /// la primera vez que pide, y actualiza su nombre/teléfono y su último
  /// pedido las siguientes. Si el Administrador lo bloqueó, lanza un error
  /// y el pedido no se crea (las reglas de Firestore también lo impiden).
  Future<void> _registrarClienteEnNegocio({
    required String idNegocio,
    required String idCliente,
  }) async {
    final ref = _db.collection('negocios').doc(idNegocio).collection('clientes').doc(idCliente);
    final snap = await ref.get();
    if (snap.exists && snap.data()?['bloqueado'] == true) {
      throw Exception(
          tr('Tu cuenta no puede hacer pedidos en este negocio. Comunícate con el local.'));
    }
    final usuario = SesionActual.instancia.actual;
    final nombre = usuario?.nombre ?? '';
    final telefono = usuario?.telefono ?? '';
    if (!snap.exists) {
      await ref.set({
        'nombre': nombre,
        'telefono': telefono,
        'bloqueado': false,
        'fechaPrimerPedido': FieldValue.serverTimestamp(),
        'ultimoPedido': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({
        'nombre': nombre,
        'telefono': telefono,
        'ultimoPedido': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Busca el número de la mesa para guardarlo junto al pedido (así Cocina
  /// y Cajero ven "Mesa 3" sin otra consulta). Si falla, el pedido igual se
  /// crea, solo sin el número.
  Future<String?> _numeroDeMesa(String idSucursal, String? idMesa) async {
    if (idMesa == null || idMesa.isEmpty) return null;
    try {
      final doc = await _db
          .collection('sucursales')
          .doc(idSucursal)
          .collection('mesas')
          .doc(idMesa)
          .get();
      return doc.data()?['numero'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// El Cajero registra un pedido para una mesa que ya asignó a un grupo
  /// de clientes. No hay cuenta de cliente (`idCliente` vacío): el pedido
  /// queda a nombre del local, con `origen: cajero`, y forma parte de la
  /// cuenta abierta de la mesa hasta que se cierre. El cobro se define al
  /// cerrar la mesa, por eso el método queda "Por definir".
  Future<String> registrarPedidoMesa({
    required String idCajero,
    required String idNegocio,
    required String idSucursal,
    required MesaModel mesa,
    required List<CarritoItemModel> items,
    String notas = '',
    List<String> alergias = const [],
  }) async {
    if (items.isEmpty) {
      throw Exception('Agrega al menos un producto al pedido.');
    }

    final total = items.fold<double>(0, (acc, item) => acc + item.subtotal);
    final pedidoDoc = _pedidos.doc();

    final pedido = PedidoModel(
      id: pedidoDoc.id,
      idCliente: '',
      idNegocio: idNegocio,
      idSucursal: idSucursal,
      modalidad: PedidoModalidad.mesa,
      idMesa: mesa.id,
      numeroMesa: mesa.numero,
      metodoPago: MetodoPago.porDefinir,
      estado: PedidoEstado.pendiente,
      total: total,
      notas: notas,
      alergias: Alergenos.ordenar(alergias),
      origen: PedidoOrigen.cajero,
      creadoPor: idCajero,
      cuentaAbierta: true,
    );

    // Mismo orden en dos pasos que confirmarPedido (ver el comentario
    // allí): primero el pedido solo, después detalle + historial.
    await pedidoDoc.set(pedido.toMap());

    final batch = _db.batch();
    for (final item in items) {
      final detalle = DetallePedidoModel(
        id: '',
        idProducto: item.idProducto,
        nombreProducto: item.nombreProducto,
        precioUnitario: item.precioUnitario,
        cantidad: item.cantidad,
        variantes: item.variantes,
        complementos: item.complementos,
        notas: item.notas,
        subtotal: item.subtotal,
      );
      batch.set(pedidoDoc.collection('detalle').doc(), detalle.toMap());
    }
    final historial = HistorialEstadoModel(
      id: '',
      estado: PedidoEstado.pendiente,
      idUsuarioQueCambio: idCajero,
      comentario: 'Pedido registrado por el Cajero para la mesa ${mesa.numero}.',
    );
    batch.set(pedidoDoc.collection('historialEstados').doc(), historial.toMap());
    await batch.commit();

    return pedidoDoc.id;
  }

  Query<Map<String, dynamic>> _consultaCuentaMesa(String idNegocio, String idMesa) => _pedidos
      .where('idNegocio', isEqualTo: idNegocio)
      .where('idMesa', isEqualTo: idMesa)
      .where('cuentaAbierta', isEqualTo: true);

  /// Pedidos que el Cajero registró para una mesa y todavía no se cobraron
  /// (la "cuenta abierta" de la mesa), del más antiguo al más nuevo.
  Stream<List<PedidoModel>> streamCuentaMesa(String idNegocio, String idMesa) =>
      _consultaCuentaMesa(idNegocio, idMesa).snapshots().map((qs) {
        final lista = qs.docs.map(PedidoModel.fromSnapshot).toList();
        lista.sort((a, b) =>
            (a.fechaCreacion ?? DateTime(0)).compareTo(b.fechaCreacion ?? DateTime(0)));
        return lista;
      });

  /// HU-46: cuántas mesas de la sucursal tienen una cuenta abierta (con
  /// algún pedido no cancelado). La caja no se puede cerrar mientras haya.
  Future<int> contarMesasConCuentaAbierta({
    required String idNegocio,
    required String idSucursal,
  }) async {
    final qs = await _pedidos
        .where('idNegocio', isEqualTo: idNegocio)
        .where('idSucursal', isEqualTo: idSucursal)
        .where('cuentaAbierta', isEqualTo: true)
        .get();
    final mesas = <String>{};
    for (final doc in qs.docs) {
      final data = doc.data();
      if (data['estado'] == PedidoEstado.cancelado) continue;
      final idMesa = data['idMesa'] as String?;
      if (idMesa != null) mesas.add(idMesa);
    }
    return mesas.length;
  }

  CollectionReference<Map<String, dynamic>> _items(String uid) =>
      _db.collection('usuarios').doc(uid).collection('carritoItems');

  /// HU-28: el cliente consulta sus propios pedidos.
  Stream<List<PedidoModel>> streamPedidosCliente(String idCliente) =>
      _pedidos.where('idCliente', isEqualTo: idCliente).snapshots().map((qs) {
        final lista = qs.docs.map(PedidoModel.fromSnapshot).toList();
        lista.sort((a, b) =>
            (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
        return lista;
      });

  /// HU-29: el Cajero registra y consulta los pedidos recibidos de su
  /// negocio. `filtroEstado` es opcional (ej. para una pestaña "activos").
  Stream<List<PedidoModel>> streamPedidosNegocio(String idNegocio, {String? filtroEstado}) {
    Query<Map<String, dynamic>> query = _pedidos.where('idNegocio', isEqualTo: idNegocio);
    if (filtroEstado != null) {
      query = query.where('estado', isEqualTo: filtroEstado);
    }
    return query.snapshots().map((qs) {
      final lista = qs.docs.map(PedidoModel.fromSnapshot).toList();
      lista.sort((a, b) =>
          (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
      return lista;
    });
  }

  /// HU-42: ventas del negocio = pedidos Entregados con fecha dentro de
  /// [desde, hasta) (hasta no incluido), del más reciente al más antiguo.
  /// Requiere un índice compuesto en Firestore: idNegocio + estado +
  /// fechaCreacion (descendente); la consola de Flutter muestra el enlace
  /// para crearlo la primera vez.
  Stream<List<PedidoModel>> streamVentas({
    required String idNegocio,
    required DateTime desde,
    required DateTime hasta,
  }) =>
      _pedidos
          .where('idNegocio', isEqualTo: idNegocio)
          .where('estado', isEqualTo: PedidoEstado.entregado)
          .where('fechaCreacion', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
          .where('fechaCreacion', isLessThan: Timestamp.fromDate(hasta))
          .orderBy('fechaCreacion', descending: true)
          .snapshots()
          .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

  /// Pedidos del negocio que todavía no terminan (Pendiente, En
  /// preparación, Listo, En camino, En el lugar), del más antiguo al más
  /// nuevo. Una consulta por estado (solo igualdades, sin índices nuevos)
  /// que se combinan en vivo.
  Stream<List<PedidoModel>> streamPedidosEnCurso(String idNegocio) {
    const estados = [
      PedidoEstado.pendiente,
      PedidoEstado.enPreparacion,
      PedidoEstado.listo,
      PedidoEstado.enCamino,
      PedidoEstado.llego,
    ];
    final porEstado = List<List<PedidoModel>>.generate(estados.length, (_) => const []);
    final recibidos = List<bool>.filled(estados.length, false);
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<List<PedidoModel>> ctrl;
    // broadcast: se puede volver a escuchar después de cancelar (por ejemplo
    // si una tarjeta del panel se quita y vuelve a aparecer) sin el error
    // "Stream has already been listened to".
    ctrl = StreamController<List<PedidoModel>>.broadcast(
      onListen: () {
        for (var i = 0; i < estados.length; i++) {
          porEstado[i] = const [];
          recibidos[i] = false;
        }
        for (var i = 0; i < estados.length; i++) {
          subs.add(_pedidos
              .where('idNegocio', isEqualTo: idNegocio)
              .where('estado', isEqualTo: estados[i])
              .snapshots()
              .listen((qs) {
            porEstado[i] = qs.docs.map(PedidoModel.fromSnapshot).toList();
            recibidos[i] = true;
            // Recién cuando las 5 consultas respondieron se publica la lista
            // (antes se veía un número parcial que luego "saltaba").
            if (recibidos.every((r) => r)) {
              final todos = porEstado.expand((l) => l).toList()
                ..sort((a, b) => (a.fechaCreacion ?? DateTime.now())
                    .compareTo(b.fechaCreacion ?? DateTime.now()));
              ctrl.add(todos);
            }
          }, onError: ctrl.addError));
        }
      },
      onCancel: () async {
        final activas = List.of(subs);
        subs.clear();
        for (final s in activas) {
          await s.cancel();
        }
      },
    );
    return ctrl.stream;
  }

  /// Cantidad de pedidos en curso del negocio (ver [streamPedidosEnCurso]).
  Stream<int> streamPedidosActivos(String idNegocio) =>
      streamPedidosEnCurso(idNegocio).map((l) => l.length);

  /// Pedidos Pendientes del negocio (para avisar al personal cuando entra
  /// uno nuevo). Solo una igualdad por campo: no necesita índice.
  Stream<List<PedidoModel>> streamPendientes(String idNegocio) => _pedidos
      .where('idNegocio', isEqualTo: idNegocio)
      .where('estado', isEqualTo: PedidoEstado.pendiente)
      .snapshots()
      .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

  /// HU-30: Cocina consulta solo los pedidos pendientes/en preparación
  /// (no necesita ver los ya entregados o cancelados).
  Stream<List<PedidoModel>> streamPedidosCocina(String idNegocio) =>
      streamPedidosNegocio(idNegocio).map((lista) => lista
          .where((p) =>
              p.estado == PedidoEstado.pendiente || p.estado == PedidoEstado.enPreparacion)
          .toList());

  Stream<List<DetallePedidoModel>> streamDetalle(String idPedido) => _pedidos
      .doc(idPedido)
      .collection('detalle')
      .snapshots()
      .map((qs) => qs.docs.map(DetallePedidoModel.fromSnapshot).toList());

  Stream<List<HistorialEstadoModel>> streamHistorial(String idPedido) => _pedidos
      .doc(idPedido)
      .collection('historialEstados')
      .snapshots()
      .map((qs) {
        final lista = qs.docs.map(HistorialEstadoModel.fromSnapshot).toList();
        lista.sort((a, b) => (a.fecha ?? DateTime(0)).compareTo(b.fecha ?? DateTime(0)));
        return lista;
      });

  // ---------------------------------------------------------------------
  // Reparto (Delivery)
  // ---------------------------------------------------------------------

  /// Pedidos de delivery ya listos que ningún repartidor ha tomado todavía.
  /// Si el repartidor está asignado a una sucursal, solo ve los de ella.
  Stream<List<PedidoModel>> streamEntregasDisponibles(
    String idNegocio, {
    String? idSucursal,
  }) =>
      _pedidos
          .where('idNegocio', isEqualTo: idNegocio)
          .where('modalidad', isEqualTo: PedidoModalidad.delivery)
          .where('estado', isEqualTo: PedidoEstado.listo)
          .snapshots()
          .map((qs) {
        final lista = qs.docs
            .map(PedidoModel.fromSnapshot)
            .where((p) => p.idRepartidor == null)
            .where((p) => idSucursal == null || idSucursal.isEmpty || p.idSucursal == idSucursal)
            .toList();
        lista.sort((a, b) =>
            (a.fechaCreacion ?? DateTime(0)).compareTo(b.fechaCreacion ?? DateTime(0)));
        return lista;
      });

  /// Entregas que este repartidor tiene en curso (En camino o Llegó).
  Stream<List<PedidoModel>> streamMisEntregas(String idNegocio, String idRepartidor) =>
      _pedidos
          .where('idNegocio', isEqualTo: idNegocio)
          .where('modalidad', isEqualTo: PedidoModalidad.delivery)
          .where('idRepartidor', isEqualTo: idRepartidor)
          .snapshots()
          .map((qs) {
        final lista = qs.docs.map(PedidoModel.fromSnapshot).where((p) => p.enReparto).toList();
        lista.sort((a, b) =>
            (a.fechaCreacion ?? DateTime(0)).compareTo(b.fechaCreacion ?? DateTime(0)));
        return lista;
      });

  /// El repartidor toma un pedido Listo: queda asignado a él y pasa a
  /// "En camino". Si otro repartidor lo tomó antes, las reglas de Firestore
  /// lo rechazan (el pedido ya no está Listo) y se avisa con un mensaje claro.
  ///
  /// Dos pasos a propósito (igual que al crear un pedido): primero el
  /// pedido, después el historial, porque las reglas del historial leen el
  /// pedido ya confirmado.
  Future<void> tomarEntrega({
    required String idPedido,
    required String idRepartidor,
    required String nombreRepartidor,
    required String telefonoRepartidor,
  }) async {
    try {
      await _pedidos.doc(idPedido).update({
        'estado': PedidoEstado.enCamino,
        'idRepartidor': idRepartidor,
        'nombreRepartidor': nombreRepartidor,
        'telefonoRepartidor': telefonoRepartidor,
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw Exception('Otro repartidor ya tomó este pedido.');
      }
      rethrow;
    }
    await _registrarHistorial(
      idPedido,
      PedidoEstado.enCamino,
      idRepartidor,
      'El repartidor $nombreRepartidor salió con el pedido.',
    );
  }

  /// "Ya llegué": el repartidor avisa al cliente que está en el lugar.
  Future<void> avisarLlegada({
    required String idPedido,
    required String idRepartidor,
  }) async {
    await _pedidos.doc(idPedido).update({'estado': PedidoEstado.llego});
    await _registrarHistorial(
      idPedido,
      PedidoEstado.llego,
      idRepartidor,
      'El repartidor llegó al lugar de entrega.',
    );
  }

  /// El repartidor entrega el pedido al cliente.
  Future<void> entregarPedido({
    required String idPedido,
    required String idRepartidor,
  }) async {
    // Al entregar se borra la posición del repartidor (ya no hace falta).
    await _pedidos.doc(idPedido).update({
      'estado': PedidoEstado.entregado,
      'ubicacionRepartidor': null,
      'ubicacionActualizada': null,
    });
    await _registrarHistorial(
      idPedido,
      PedidoEstado.entregado,
      idRepartidor,
      'Pedido entregado por el repartidor.',
    );
  }

  /// Guarda la posición actual del repartidor en el pedido para que el
  /// cliente la vea en el mapa. Solo se usa mientras el pedido está en
  /// camino; se borra al entregarlo.
  Future<void> actualizarUbicacionRepartidor({
    required String idPedido,
    required double latitud,
    required double longitud,
  }) =>
      _pedidos.doc(idPedido).update({
        'ubicacionRepartidor': GeoPoint(latitud, longitud),
        'ubicacionActualizada': FieldValue.serverTimestamp(),
      });

  Future<void> _registrarHistorial(
    String idPedido,
    String estado,
    String idUsuario,
    String comentario,
  ) {
    final historial = HistorialEstadoModel(
      id: '',
      estado: estado,
      idUsuarioQueCambio: idUsuario,
      comentario: comentario,
    );
    return _pedidos.doc(idPedido).collection('historialEstados').add(historial.toMap());
  }

  /// HU-31 (Cocina actualiza preparación) y HU-29 (Cajero gestiona el
  /// pedido): cambia el estado del pedido y deja registro en el
  /// historial de quién lo cambió.
  Future<void> cambiarEstado({
    required String idPedido,
    required String nuevoEstado,
    required String idUsuarioQueCambio,
    String comentario = '',
    bool limpiarUbicacion = false,
  }) async {
    final ref = _pedidos.doc(idPedido);
    // Transacción: lee el estado REAL, valida el cambio y recién ahí escribe
    // pedido + historial juntos. Si alguien más lo cambió mientras tanto,
    // Firestore reintenta y la validación detecta el cambio.
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const PedidoEstadoException('El pedido ya no existe.');
      }
      final actual = (snap.data()?['estado'] ?? '') as String;
      _validarCambio(actual, nuevoEstado);
      tx.update(ref, {
        'estado': nuevoEstado,
        // Si el pedido iba en camino, se borra la posición del repartidor.
        if (limpiarUbicacion) 'ubicacionRepartidor': null,
        if (limpiarUbicacion) 'ubicacionActualizada': null,
      });
      final historial = HistorialEstadoModel(
        id: '',
        estado: nuevoEstado,
        idUsuarioQueCambio: idUsuarioQueCambio,
        comentario: comentario,
      );
      tx.set(ref.collection('historialEstados').doc(), historial.toMap());
    });
    // Control de stock: se descuenta cuando la cocina empieza a preparar.
    if (nuevoEstado == PedidoEstado.enPreparacion) {
      await _descontarStock(idPedido).catchError((_) {});
    }
  }

  /// Resta del stock lo que lleva el pedido (solo productos con control de
  /// stock). Si alguno llega a 0, queda "No disponible" en el menú.
  Future<void> _descontarStock(String idPedido) async {
    final detalle = await _pedidos.doc(idPedido).collection('detalle').get();
    final cantidades = <String, int>{};
    for (final d in detalle.docs) {
      final id = d.data()['idProducto'] as String? ?? '';
      if (id.isEmpty) continue;
      cantidades[id] = (cantidades[id] ?? 0) + ((d.data()['cantidad'] as num?)?.toInt() ?? 1);
    }
    for (final e in cantidades.entries) {
      final ref = _db.collection('productos').doc(e.key);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final stock = (snap.data()?['stock'] as num?)?.toInt();
        if (!snap.exists || stock == null) return; // sin control de stock
        final nuevo = stock - e.value < 0 ? 0 : stock - e.value;
        tx.update(ref, {
          'stock': nuevo,
          if (nuevo == 0) 'disponible': false,
        });
      });
    }
  }

  /// Entregas que este repartidor terminó hoy (para ver sus propinas).
  Stream<List<PedidoModel>> streamEntregadosHoy(String idNegocio, String idRepartidor) {
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, ahora.day);
    return _pedidos
        .where('idNegocio', isEqualTo: idNegocio)
        .where('modalidad', isEqualTo: PedidoModalidad.delivery)
        .where('idRepartidor', isEqualTo: idRepartidor)
        .snapshots()
        .map((qs) => qs.docs
            .map(PedidoModel.fromSnapshot)
            .where((p) =>
                p.estado == PedidoEstado.entregado &&
                p.fechaCreacion != null &&
                !p.fechaCreacion!.isBefore(inicio))
            .toList());
  }

  /// "Volver a pedir": copia al carrito los productos de un pedido anterior
  /// que sigan disponibles, con su precio de HOY. Devuelve cuántos se
  /// agregaron y los nombres de los que ya no están.
  Future<({int agregados, List<String> noDisponibles})> repetirPedido({
    required String idCliente,
    required PedidoModel pedido,
  }) async {
    final detalle = await _pedidos.doc(pedido.id).collection('detalle').get();
    var agregados = 0;
    final faltan = <String>[];
    for (final d in detalle.docs.map(DetallePedidoModel.fromSnapshot)) {
      final prod = await _db.collection('productos').doc(d.idProducto).get();
      final data = prod.data();
      final disponible = prod.exists &&
          data?['estado'] != false &&
          data?['disponible'] != false &&
          data?['idNegocio'] == pedido.idNegocio;
      if (!disponible) {
        faltan.add(d.nombreProducto);
        continue;
      }
      // Precio de HOY del producto (los extras conservan su precio).
      await CarritoService.instancia.agregarAlCarrito(
        idCliente,
        CarritoItemModel(
          id: '',
          idProducto: d.idProducto,
          nombreProducto: data!['nombre'] as String? ?? d.nombreProducto,
          imagenUrl: data['imagenUrl'] as String? ?? '',
          precioUnitario: (data['precio'] as num?)?.toDouble() ?? d.precioUnitario,
          cantidad: d.cantidad,
          variantes: d.variantes,
          complementos: d.complementos,
          notas: d.notas,
          idNegocio: pedido.idNegocio,
        ),
      );
      agregados += 1;
    }
    return (agregados: agregados, noDisponibles: faltan);
  }

  /// Cajero o Administrador cancelan un pedido indicando el motivo. El
  /// motivo queda en el historial (el cliente lo ve en el detalle). Si el
  /// pedido iba en camino, se borra la posición del repartidor. Un pedido
  /// ya cobrado no se cancela aquí: primero hay que devolver el dinero
  /// (egreso en caja) para que la caja cuadre.
  Future<void> cancelarPedido({
    required String idPedido,
    required String motivo,
    required String idUsuario,
  }) async {
    final limpio = motivo.trim();
    if (limpio.length < 4) {
      throw const PedidoEstadoException('Escribe el motivo de la cancelación.');
    }
    final ref = _pedidos.doc(idPedido);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        throw const PedidoEstadoException('El pedido ya no existe.');
      }
      final data = snap.data()!;
      final actual = (data['estado'] ?? '') as String;
      if (data['cobrado'] == true) {
        throw const PedidoEstadoException(
          'Este pedido ya se cobró en caja. Registra la devolución como egreso '
          'en la caja antes de cancelarlo.',
        );
      }
      _validarCambio(actual, PedidoEstado.cancelado);
      final enReparto = actual == PedidoEstado.enCamino || actual == PedidoEstado.llego;
      tx.update(ref, {
        'estado': PedidoEstado.cancelado,
        if (enReparto) 'ubicacionRepartidor': null,
        if (enReparto) 'ubicacionActualizada': null,
      });
      tx.set(
        ref.collection('historialEstados').doc(),
        HistorialEstadoModel(
          id: '',
          estado: PedidoEstado.cancelado,
          idUsuarioQueCambio: idUsuario,
          comentario: 'Motivo: $limpio',
        ).toMap(),
      );
    });
  }

  /// Comprueba, ANTES de hacer otras operaciones (como registrar un cobro),
  /// que el pedido todavía puede pasar a [nuevoEstado]. Lanza
  /// [PedidoEstadoException] con un mensaje claro si ya no se puede.
  Future<void> verificarCambio(String idPedido, String nuevoEstado) async {
    final snap = await _pedidos.doc(idPedido).get();
    if (!snap.exists) {
      throw const PedidoEstadoException('El pedido ya no existe.');
    }
    _validarCambio((snap.data()?['estado'] ?? '') as String, nuevoEstado);
  }

  void _validarCambio(String actual, String nuevo) {
    if (actual == nuevo) {
      throw PedidoEstadoException(
        'Este pedido ya estaba en "$nuevo". La pantalla se actualizó, revisa el estado.',
      );
    }
    if (!PedidoEstado.puedePasar(actual, nuevo)) {
      throw PedidoEstadoException(
        'No se puede pasar de "$actual" a "$nuevo". Es posible que otra persona '
        'haya cambiado el pedido; revisa el estado actual.',
      );
    }
  }
}
