import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../l10n/idioma.dart';
import '../models/alergenos.dart';
import '../models/carrito_models.dart';
import '../models/catalogo_models.dart';
import '../models/mesa_model.dart';
import '../models/pedido_models.dart';
import '../models/usuario_model.dart';
import '../utils/errores.dart';
import 'carrito_service.dart';
import 'catalogo_service.dart';
import 'cupon_service.dart';
import 'sesion_actual.dart';
import 'sucursal_service.dart';
import '../utils/formato.dart';

/// HU-24 a HU-31: confirmar pedido (a partir del carrito), consultarlo,
/// y que el personal del negocio (Cajero/Cocina/Administrador) lo
/// gestione y cambie de estado.
class PedidoService {
  PedidoService._();
  static final instancia = PedidoService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pedidos => _db.collection('pedidos');

  /// Para los reportes del Administrador: a los pedidos con factura les
  /// suma el NIT y la razón social, que están en privado/contacto.
  Future<List<PedidoModel>> conDatosDeFactura(List<PedidoModel> pedidos) async {
    final lista = <PedidoModel>[];
    for (final p in pedidos) {
      if (p.conFactura && (p.facturaNit ?? '').isEmpty) {
        final contacto = await _contacto(p.id);
        if (contacto != null) {
          lista.add(PedidoModel.fromSnapshot(await _pedidos.doc(p.id).get(), contacto: contacto));
          continue;
        }
      }
      lista.add(p);
    }
    return lista;
  }

  /// Datos de contacto ya leídos (no cambian después de crear el pedido).
  static final _contactos = <String, Map<String, dynamic>>{};

  /// Se llama al cerrar sesión: la próxima persona que entre en el mismo
  /// dispositivo no debe ver direcciones ni teléfonos ya leídos.
  static void olvidarDatosLeidos() => _contactos.clear();

  /// Dirección, teléfono y factura del pedido (`privado/contacto`). Solo los
  /// pueden leer el cliente, el Administrador, el Cajero y el repartidor
  /// que lo lleva; para la Cocina, o si no se puede leer, devuelve null.
  Future<Map<String, dynamic>?> _contacto(String idPedido) async {
    final guardado = _contactos[idPedido];
    if (guardado != null) return guardado;
    if (SesionActual.instancia.esCocina) return null;
    try {
      final d = await _pedidos.doc(idPedido).collection('privado').doc('contacto').get();
      final datos = d.data();
      if (datos != null) _contactos[idPedido] = datos;
      return datos;
    } catch (_) {
      return null;
    }
  }

  /// Pedidos de un negocio. El Cajero y la Cocina con sucursal asignada
  /// solo ven los de SU sucursal (las reglas de Firestore también lo
  /// exigen, así que la consulta tiene que pedirlo).
  Query<Map<String, dynamic>> _delNegocio(String idNegocio) {
    Query<Map<String, dynamic>> consulta = _pedidos.where('idNegocio', isEqualTo: idNegocio);
    final sesion = SesionActual.instancia;
    final idSucursal = sesion.idSucursal;
    if ((sesion.esCajero || sesion.esCocina) && idSucursal != null && idSucursal.isNotEmpty) {
      consulta = consulta.where('idSucursal', isEqualTo: idSucursal);
    }
    return consulta;
  }

  /// HU-24/HU-26: confirma el pedido a partir de los items ya cargados
  /// del carrito (se los pasa la pantalla, que ya los tiene vía
  /// CarritoService.streamCarrito). Crea el pedido con sus líneas + el
  /// primer renglón de historialEstados, y al final vacía el carrito de
  /// ese negocio. Devuelve el id del pedido creado.
  Future<String> confirmarPedido({
    String? idPedido,
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
    String? zonaEntrega,
  }) async {
    // Si este mismo envío ya se hizo (doble toque o reintento), no se crea
    // otro pedido: se devuelve el que ya existe.
    final pedidoDoc = idPedido == null ? _pedidos.doc() : _pedidos.doc(idPedido);
    if (idPedido != null && await _yaCreado(pedidoDoc, 'idCliente', idCliente)) {
      return pedidoDoc.id;
    }
    if (itemsCarrito.isEmpty) {
      throw Exception(tr('El carrito está vacío, no se puede confirmar el pedido.'));
    }
    if ((comprobantePagoUrl ?? '').length > 500) {
      throw Exception(tr('El enlace del comprobante es muy largo. Sube la imagen en vez de pegar el enlace.'));
    }

    // Precios de HOY (la misma lista que revisan las reglas de Firestore).
    // Si alguno cambió, se corrige en el carrito y se avisa al cliente.
    final lineas = await _lineasConPrecioActual(idNegocio, itemsCarrito, uidCarrito: idCliente);
    final subtotal = _sumaLineas(lineas);
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

    // Costo de envío: se toma de la sucursal (no de la pantalla), por si
    // el Administrador lo cambió mientras el cliente pedía.
    double costoEnvio = 0;
    String? zona;
    if (modalidad == PedidoModalidad.delivery) {
      final sucursal = await SucursalService.instancia.obtener(idSucursal);
      if (sucursal != null && sucursal.cobraEnvio) {
        final costo = sucursal.zonasDelivery[zonaEntrega];
        if (zonaEntrega == null || costo == null) {
          throw Exception(tr('Elige la zona de entrega.'));
        }
        if (total < sucursal.pedidoMinimoDelivery) {
          throw Exception(tr('El pedido mínimo para delivery es {monto}.',
              {'monto': dinero(sucursal.pedidoMinimoDelivery)}));
        }
        costoEnvio = costo;
        zona = zonaEntrega;
      }
    }

    await _registrarClienteEnNegocio(idNegocio: idNegocio, idCliente: idCliente);

    final numeroMesa = await _numeroDeMesa(idSucursal, idMesa);

    // Solo en delivery: nombre y teléfono para que el repartidor pueda
    // contactar al cliente durante la entrega (y nadie más que el personal
    // de este negocio los ve; se borran si el cliente elimina su cuenta).
    final esDelivery = modalidad == PedidoModalidad.delivery;
    final usuario = SesionActual.instancia.actual;
    final telefonoCliente = usuario?.telefono ?? '';

    final pedido = PedidoModel(
      id: pedidoDoc.id,
      nombreCliente: esDelivery && usuario != null ? _recortar(usuario.nombre, 80) : null,
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
      costoEnvio: costoEnvio,
      zonaEntrega: zona,
      programadoPara: programadoPara,
      facturaNit: (facturaNit ?? '').trim().isEmpty ? null : facturaNit!.trim(),
      facturaRazonSocial: (facturaNit ?? '').trim().isEmpty ? null : (facturaRazonSocial ?? '').trim(),
      lineas: lineas,
      subtotal: subtotal,
    );

    // El pedido se crea con todas sus líneas, junto con su control/total,
    // en UN lote: las reglas comprueban los precios y la suma, y no puede
    // quedar un pedido sin productos. El historial va después porque su
    // regla lee el pedido.
    if (!await _crearUnaVez(pedidoDoc, pedido, 'idCliente', idCliente)) {
      return pedidoDoc.id;
    }

    final historial = HistorialEstadoModel(
      id: '',
      estado: PedidoEstado.pendiente,
      idUsuarioQueCambio: idCliente,
      comentario: 'Pedido creado por el cliente.',
    );
    try {
      await pedidoDoc.collection('historialEstados').doc().set(historial.toMap());
    } catch (_) {
      // El pedido ya existe; solo falta su primera línea del historial.
    }

    // El carrito ya se copió al pedido, así que se vacía para que no
    // quede duplicado si el cliente abre el carrito de nuevo. Si falla,
    // el pedido igual quedó hecho: no se muestra error.
    try {
      final qs = await _items(idCliente).where('idNegocio', isEqualTo: idNegocio).get();
      final limpiarBatch = _db.batch();
      for (final doc in qs.docs) {
        limpiarBatch.delete(doc.reference);
      }
      await limpiarBatch.commit();
    } catch (_) {}

    return pedidoDoc.id;
  }

  /// Arma las líneas del pedido con el precio de HOY de cada producto,
  /// tomado de la lista de precios del negocio (la misma que revisan las
  /// reglas). Si un producto ya no se vende, o su precio cambió, avisa y
  /// no deja seguir; con [uidCarrito] también corrige el precio en el
  /// carrito del cliente para que vea el total nuevo.
  Future<List<DetallePedidoModel>> _lineasConPrecioActual(
    String idNegocio,
    List<CarritoItemModel> items, {
    String? uidCarrito,
  }) async {
    if (items.length > PedidoModel.maxLineas) {
      throw Exception(tr('Un pedido puede tener hasta {n} productos distintos.',
          {'n': PedidoModel.maxLineas}));
    }
    // Cada variante o complemento ocupa una línea más en el pedido.
    final totalLineas = items.fold<int>(
        0, (n, item) => n + 1 + item.variantes.length + item.complementos.length);
    if (totalLineas > PedidoModel.maxLineas) {
      throw Exception(tr('Un pedido puede tener hasta {n} líneas contando los extras. Quita algunos extras o productos.',
          {'n': PedidoModel.maxLineas}));
    }
    final precios = await CatalogoService.instancia.preciosVigentes(idNegocio);
    final lineas = <DetallePedidoModel>[];
    final cambiaron = <String>[];
    for (final item in items) {
      final precio = precios[item.idProducto];
      if (precio == null) {
        throw Exception(tr('"{producto}" ya no está disponible. Quítalo para continuar.',
            {'producto': item.nombreProducto}));
      }
      // Los extras se cobran con el precio de la lista, igual que el producto.
      for (final o in [...item.variantes, ...item.complementos]) {
        final precioExtra = precios[o.id];
        if (precioExtra == null) {
          throw Exception(tr('El extra "{extra}" de "{producto}" ya no está disponible. Quita el producto y vuelve a agregarlo.',
              {'extra': o.nombre, 'producto': item.nombreProducto}));
        }
        if ((precioExtra - o.precio).abs() > 0.009) {
          throw Exception(tr('Cambió el precio del extra "{extra}" de "{producto}". Quita el producto y vuelve a agregarlo.',
              {'extra': o.nombre, 'producto': item.nombreProducto}));
        }
      }
      if (item.cantidad < 1 || item.cantidad > 99) {
        throw Exception(tr('La cantidad de cada producto debe estar entre 1 y 99.'));
      }
      if ((precio - item.precioUnitario).abs() > 0.009) {
        cambiaron.add(item.nombreProducto);
        if (uidCarrito != null && item.id.isNotEmpty) {
          await CarritoService.instancia.actualizarPrecio(uidCarrito, item.id, precio);
        }
        continue;
      }
      OpcionSeleccionada recortada(OpcionSeleccionada o) =>
          OpcionSeleccionada(id: o.id, nombre: _recortar(o.nombre, 100), precio: o.precio);
      final extras = [...item.variantes, ...item.complementos]
          .fold<double>(0, (suma, o) => suma + o.precio);
      lineas.add(DetallePedidoModel(
        id: '',
        idProducto: item.idProducto,
        nombreProducto: _recortar(item.nombreProducto, 200),
        precioUnitario: precio,
        cantidad: item.cantidad,
        variantes: item.variantes.map(recortada).toList(),
        complementos: item.complementos.map(recortada).toList(),
        notas: _recortar(item.notas, 200),
        subtotal: (precio + extras) * item.cantidad,
      ));
    }
    if (cambiaron.isNotEmpty) {
      throw Exception(tr('Cambió el precio de: {productos}. Revisa el total y vuelve a confirmar.',
          {'productos': cambiaron.join(', ')}));
    }
    await _revisarStock(items);
    await _revisarExtras(idNegocio, items);
    return lineas;
  }

  /// Los extras elegidos siguen activos, son de este negocio y cada
  /// variante es del producto con el que se pidió (una por producto).
  Future<void> _revisarExtras(String idNegocio, List<CarritoItemModel> items) async {
    for (final item in items) {
      if (item.variantes.length > 1) {
        throw Exception(tr('El extra "{extra}" de "{producto}" ya no está disponible. Quita el producto y vuelve a agregarlo.',
            {'extra': item.variantes.last.nombre, 'producto': item.nombreProducto}));
      }
      final docs = await Future.wait([
        for (final v in item.variantes) _db.collection('variantes').doc(v.id).get(),
        for (final c in item.complementos) _db.collection('complementos').doc(c.id).get(),
      ]);
      final opciones = [...item.variantes, ...item.complementos];
      for (var i = 0; i < docs.length; i++) {
        final data = docs[i].data();
        final esVariante = i < item.variantes.length;
        // Un complemento con lista de productos solo va con esos productos.
        final productos = data?['productos'];
        final valido = data != null &&
            data['estado'] != false &&
            data['idNegocio'] == idNegocio &&
            (!esVariante || data['idProducto'] == item.idProducto) &&
            (esVariante || productos is! List || productos.isEmpty || productos.contains(item.idProducto));
        if (!valido) {
          throw Exception(tr('El extra "{extra}" de "{producto}" ya no está disponible. Quita el producto y vuelve a agregarlo.',
              {'extra': opciones[i].nombre, 'producto': item.nombreProducto}));
        }
      }
    }
  }

  /// Antes de crear el pedido se revisa que haya stock para lo que se pide
  /// (solo productos con control de stock) y que el producto siga activo y
  /// disponible. El stock se descuenta recién cuando la cocina empieza a
  /// prepararlo, así que es una revisión de ayuda, no una reserva.
  Future<void> _revisarStock(List<CarritoItemModel> items) async {
    final porProducto = <String, int>{};
    final nombres = <String, String>{};
    for (final item in items) {
      porProducto[item.idProducto] = (porProducto[item.idProducto] ?? 0) + item.cantidad;
      nombres[item.idProducto] = item.nombreProducto;
    }
    // Un combo también necesita stock de lo que incluye.
    final pedidas = (await _sumarCombos(porProducto)).cantidades;
    final docs = await Future.wait([
      for (final id in pedidas.keys) _db.collection('productos').doc(id).get(),
    ]);
    for (final doc in docs) {
      final data = doc.data();
      final nombre = nombres[doc.id] ?? data?['nombre'] as String? ?? '';
      if (data == null || data['estado'] == false || data['disponible'] == false) {
        throw Exception(tr('"{producto}" ya no está disponible. Quítalo para continuar.',
            {'producto': nombre}));
      }
      final stock = (data['stock'] as num?)?.toInt();
      final cantidad = pedidas[doc.id] ?? 0;
      if (stock != null && cantidad > stock) {
        if (stock <= 0) {
          throw Exception(tr('"{producto}" ya no está disponible. Quítalo para continuar.',
              {'producto': nombre}));
        }
        throw Exception(tr('Solo quedan {n} de "{producto}". Cambia la cantidad para continuar.',
            {'n': stock, 'producto': nombre}));
      }
    }
  }

  /// Cuánto se usa de cada producto: lo pedido y, si es un combo, también
  /// lo que incluye (un combo "Pollo + Soda" usa un pollo y una soda).
  /// [deCombo] dice de qué combo salió cada producto incluido.
  Future<({Map<String, int> cantidades, Map<String, String> deCombo})> _sumarCombos(
    Map<String, int> pedidas,
  ) async {
    final cantidades = Map<String, int>.from(pedidas);
    final deCombo = <String, String>{};
    final docs = await Future.wait([
      for (final id in pedidas.keys) _db.collection('productos').doc(id).get(),
    ]);
    for (final doc in docs) {
      final data = doc.data();
      if (data == null || data['esCombo'] != true || data['comboIds'] is! List) continue;
      for (final id in data['comboIds'] as List) {
        if (id is! String || id == doc.id) continue;
        cantidades[id] = (cantidades[id] ?? 0) + (pedidas[doc.id] ?? 0);
        deCombo.putIfAbsent(id, () => doc.id);
      }
    }
    return (cantidades: cantidades, deCombo: deCombo);
  }

  /// Id nuevo para un pedido, para que la pantalla lo guarde y lo reuse si
  /// el envío se repite.
  String nuevoIdPedido() => _pedidos.doc().id;

  /// true si el pedido ya existe y es de quien lo está enviando.
  Future<bool> _yaCreado(
    DocumentReference<Map<String, dynamic>> pedidoDoc,
    String campo,
    String uid,
  ) async {
    try {
      final snap = await pedidoDoc.get();
      return snap.exists && snap.data()?[campo] == uid;
    } catch (_) {
      // Si no existe, las reglas no dejan leerlo: se toma como nuevo.
      return false;
    }
  }

  /// Crea el pedido. Si el lote se rechaza porque OTRO envío con el mismo id
  /// ya lo creó (dos toques casi al mismo tiempo), devuelve false en vez de
  /// mostrar un error: el pedido ya está hecho una sola vez.
  Future<bool> _crearUnaVez(
    DocumentReference<Map<String, dynamic>> pedidoDoc,
    PedidoModel pedido,
    String campo,
    String uid,
  ) async {
    try {
      await _crearConControl(pedidoDoc, pedido);
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && await _yaCreado(pedidoDoc, campo, uid)) {
        return false;
      }
      rethrow;
    }
  }

  /// Escribe el pedido y `pedidos/{id}/control/total` en un solo lote. El
  /// control es una copia de productos, cantidades, precios y subtotal: su
  /// regla de Firestore los compara con la lista de precios del negocio.
  Future<void> _crearConControl(
    DocumentReference<Map<String, dynamic>> pedidoDoc,
    PedidoModel pedido,
  ) async {
    final campos = DetallePedidoModel.camposDeLineas(pedido.lineas);
    final lote = _db.batch()
      ..set(pedidoDoc, pedido.toMap())
      ..set(pedidoDoc.collection('control').doc('total'), {
        'ids': campos['lineasIds'],
        'cant': campos['lineasCant'],
        'precios': campos['precios'],
        'subtotal': pedido.subtotal,
      });
    // Dirección, teléfono y factura van aparte (privado/contacto).
    final contacto = pedido.contactoMap();
    if (contacto.isNotEmpty) {
      lote.set(pedidoDoc.collection('privado').doc('contacto'), contacto);
    }
    // Cada cliente usa un cupón una sola vez: se deja anotado su uso.
    final cupon = pedido.codigoCupon;
    if (cupon != null) {
      lote.set(
        _db
            .collection('negocios')
            .doc(pedido.idNegocio)
            .collection('cupones')
            .doc(cupon)
            .collection('usos')
            .doc(pedido.idCliente),
        {'idPedido': pedidoDoc.id, 'fecha': FieldValue.serverTimestamp()},
      );
    }
    await lote.commit();
  }

  /// Suma de las líneas en el mismo orden que la calculan las reglas.
  double _sumaLineas(List<DetallePedidoModel> lineas) => DetallePedidoModel.sumar(lineas);

  String _recortar(String texto, int max) =>
      texto.length <= max ? texto : texto.substring(0, max);

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
    // Mismos tamaños que aceptan las reglas para la ficha del cliente.
    final nombre = _recortar(usuario?.nombre ?? '', 80);
    final telefono = _recortar(usuario?.telefono ?? '', 20);
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
    String? idPedido,
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

    final pedidoDoc = idPedido == null ? _pedidos.doc() : _pedidos.doc(idPedido);
    if (idPedido != null && await _yaCreado(pedidoDoc, 'creadoPor', idCajero)) {
      return pedidoDoc.id;
    }
    final lineas = await _lineasConPrecioActual(idNegocio, items);
    final total = _sumaLineas(lineas);

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
      lineas: lineas,
      subtotal: total,
    );

    // Igual que confirmarPedido: el pedido con sus líneas y su control en
    // un lote, y después el historial.
    if (!await _crearUnaVez(pedidoDoc, pedido, 'creadoPor', idCajero)) {
      return pedidoDoc.id;
    }

    final historial = HistorialEstadoModel(
      id: '',
      estado: PedidoEstado.pendiente,
      idUsuarioQueCambio: idCajero,
      comentario: 'Pedido registrado por el Cajero para la mesa ${mesa.numero}.',
    );
    try {
      await pedidoDoc.collection('historialEstados').doc().set(historial.toMap());
    } catch (_) {}

    return pedidoDoc.id;
  }

  Query<Map<String, dynamic>> _consultaCuentaMesa(String idNegocio, String idMesa) =>
      _delNegocio(idNegocio)
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

  /// Todos los pedidos con la cuenta abierta de las mesas de una sucursal
  /// (para ver en el plano cuánto lleva cada mesa y desde cuándo). Solo
  /// igualdades: no necesita índice.
  Stream<List<PedidoModel>> streamCuentasAbiertas(String idNegocio, String idSucursal) => _pedidos
      .where('idNegocio', isEqualTo: idNegocio)
      .where('idSucursal', isEqualTo: idSucursal)
      .where('cuentaAbierta', isEqualTo: true)
      .snapshots()
      .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

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

  /// "Mis pedidos" por partes: los [limite] más recientes del cliente.
  /// Usa el índice idCliente + fechaCreacion (firestore.indexes.json).
  Stream<List<PedidoModel>> streamPedidosClientePaginado(String idCliente, int limite) => _pedidos
      .where('idCliente', isEqualTo: idCliente)
      .orderBy('fechaCreacion', descending: true)
      .limit(limite)
      .snapshots()
      .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

  /// HU-29: el Cajero registra y consulta los pedidos recibidos de su
  /// negocio. `filtroEstado` es opcional (ej. para una pestaña "activos").
  Stream<List<PedidoModel>> streamPedidosNegocio(String idNegocio, {String? filtroEstado}) {
    Query<Map<String, dynamic>> query = _delNegocio(idNegocio);
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
      _delNegocio(idNegocio)
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
          subs.add(_delNegocio(idNegocio)
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
  Stream<List<PedidoModel>> streamPendientes(String idNegocio) => _delNegocio(idNegocio)
      .where('estado', isEqualTo: PedidoEstado.pendiente)
      .snapshots()
      .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

  /// HU-30: Cocina consulta solo los pedidos pendientes/en preparación
  /// (no necesita ver los ya entregados o cancelados). Antes leía TODOS los
  /// pedidos del negocio (cientos de lecturas cada vez); ahora solo los que
  /// están en curso.
  Stream<List<PedidoModel>> streamPedidosCocina(String idNegocio) =>
      streamPedidosEnCurso(idNegocio).map((lista) => lista
          .where((p) =>
              p.estado == PedidoEstado.pendiente || p.estado == PedidoEstado.enPreparacion)
          .toList());

  /// Un solo pedido, en vivo (detalle). Lee 1 documento, no la lista
  /// completa del negocio.
  Stream<PedidoModel?> streamPedido(String idPedido) => _pedidos
      .doc(idPedido)
      .snapshots()
      .asyncMap((d) async =>
          d.exists ? PedidoModel.fromSnapshot(d, contacto: await _contacto(d.id)) : null);

  /// Pedidos de un estado (Entregado / Cancelado) de los últimos [dias]
  /// días, del más reciente al más antiguo. Usa el índice
  /// idNegocio + estado + fechaCreacion que ya existe.
  Stream<List<PedidoModel>> streamRecientesPorEstado(
    String idNegocio,
    String estado, {
    int dias = 7,
  }) {
    final hoy = DateTime.now();
    final desde = DateTime(hoy.year, hoy.month, hoy.day).subtract(Duration(days: dias - 1));
    return _delNegocio(idNegocio)
        .where('estado', isEqualTo: estado)
        .where('fechaCreacion', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
        .orderBy('fechaCreacion', descending: true)
        .limit(200)
        .snapshots()
        .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());
  }

  /// Deliverys entregados por un repartidor que todavía no pasaron por caja
  /// (rendición). Antes se tomaban de los últimos 200 entregados de 7 días,
  /// y en un local con mucho movimiento algunos quedaban fuera. Solo
  /// igualdades: no necesita índice nuevo.
  Stream<List<PedidoModel>> streamPorRendir(String idNegocio) => _delNegocio(idNegocio)
      .where('modalidad', isEqualTo: PedidoModalidad.delivery)
      .where('estado', isEqualTo: PedidoEstado.entregado)
      .where('cobrado', isEqualTo: false)
      .snapshots()
      .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

  /// Líneas de un pedido, en vivo. Los pedidos nuevos las tienen dentro
  /// (campo `lineas`); los anteriores, en la subcolección `detalle`.
  Stream<List<DetallePedidoModel>> streamDetalle(String idPedido) =>
      _pedidos.doc(idPedido).snapshots().asyncMap((d) async {
        final lineas = DetallePedidoModel.desdePedido(d.data() ?? const {});
        if (lineas.isNotEmpty) return lineas;
        final qs = await _pedidos.doc(idPedido).collection('detalle').get();
        return qs.docs.map(DetallePedidoModel.fromSnapshot).toList();
      });

  /// Líneas de un pedido, una sola vez (ver [streamDetalle]).
  Future<List<DetallePedidoModel>> lineasDe(String idPedido) => streamDetalle(idPedido).first;

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
          // Solo las que siguen en curso (antes leía también todas las ya
          // entregadas, cada vez más con el tiempo).
          .where('estado', whereIn: [PedidoEstado.listo, PedidoEstado.enCamino, PedidoEstado.llego])
          .snapshots()
          .asyncMap((qs) async {
        // También los pedidos Listos que el Cajero le asignó (HU-39). A
        // cada uno se le suma su dirección y teléfono (privado/contacto).
        final lista = <PedidoModel>[];
        for (final d in qs.docs) {
          final p = PedidoModel.fromSnapshot(d);
          if (!p.enReparto && p.estado != PedidoEstado.listo) continue;
          lista.add(PedidoModel.fromSnapshot(d, contacto: await _contacto(d.id)));
        }
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

  /// HU-39: repartidores activos del negocio (para asignarles pedidos).
  Stream<List<UsuarioModel>> streamRepartidores(String idNegocio) => _db
      .collection('usuarios')
      .where('idNegocio', isEqualTo: idNegocio)
      .where('rol', isEqualTo: Rol.repartidor)
      .snapshots()
      .map((qs) => qs.docs.map(UsuarioModel.fromSnapshot).where((u) => u.estado).toList()
        ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase())));

  /// HU-39: el Cajero o el Administrador asigna un repartidor a un pedido
  /// de delivery Listo. El pedido sigue Listo hasta que el repartidor sale.
  Future<void> asignarRepartidor({
    required String idPedido,
    required String idRepartidor,
    required String nombreRepartidor,
    required String telefonoRepartidor,
    required String idUsuario,
  }) async {
    await _pedidos.doc(idPedido).update({
      'idRepartidor': idRepartidor,
      'nombreRepartidor': nombreRepartidor,
      'telefonoRepartidor': telefonoRepartidor,
    });
    await _registrarHistorial(
      idPedido,
      PedidoEstado.listo,
      idUsuario,
      'Se asignó el pedido al repartidor $nombreRepartidor.',
    );
  }

  /// HU-39: el repartidor sale con un pedido que le asignaron.
  Future<void> salirConEntregaAsignada({
    required String idPedido,
    required String idRepartidor,
    required String nombreRepartidor,
  }) async {
    await _pedidos.doc(idPedido).update({'estado': PedidoEstado.enCamino});
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
    final lineas = await lineasDe(idPedido);
    final porProducto = <String, int>{};
    for (final l in lineas) {
      if (l.idProducto.isEmpty) continue;
      porProducto[l.idProducto] = (porProducto[l.idProducto] ?? 0) + l.cantidad;
    }
    // Un combo descuenta también lo que incluye.
    final cantidades = (await _sumarCombos(porProducto)).cantidades;
    for (final e in cantidades.entries) {
      final ref = _db.collection('productos').doc(e.key);
      // Cada producto por separado: si uno falla, los demás igual se
      // descuentan.
      try {
        await _db.runTransaction((tx) async {
          final snap = await tx.get(ref);
          final stock = (snap.data()?['stock'] as num?)?.toInt();
          // Sin control de stock, o ya en 0 (se pidió antes de agotarse).
          if (!snap.exists || stock == null || stock <= 0) return;
          final nuevo = stock - e.value < 0 ? 0 : stock - e.value;
          tx.update(ref, {
            'stock': nuevo,
            if (nuevo == 0) 'disponible': false,
          });
        });
      } catch (_) {
        // Se sigue con el siguiente producto.
      }
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
    final lineas = pedido.lineas.isNotEmpty ? pedido.lineas : await lineasDe(pedido.id);
    var agregados = 0;
    final faltan = <String>[];
    for (final d in lineas) {
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
      // Precio de HOY del producto, con su promoción si está vigente (los
      // extras conservan su precio). Un combo mantiene el nombre con lo que
      // incluye.
      final actual = ProductoModel.fromSnapshot(prod);
      await CarritoService.instancia.agregarAlCarrito(
        idCliente,
        CarritoItemModel(
          id: '',
          idProducto: d.idProducto,
          nombreProducto: actual.esCombo || actual.nombre.isEmpty ? d.nombreProducto : actual.nombre,
          imagenUrl: actual.imagenUrl,
          precioUnitario: data?['precio'] is num ? actual.precioVigente() : d.precioUnitario,
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
  ///
  /// Con [devolverStock], lo que ya se había descontado del stock (al
  /// empezar a prepararlo) vuelve al inventario; por ejemplo, una bebida
  /// cerrada. Si la comida ya se preparó, se deja en false (se pierde).
  Future<void> cancelarPedido({
    required String idPedido,
    required String motivo,
    required String idUsuario,
    bool devolverStock = false,
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
      // Si el pedido usó un cupón, el cliente lo recupera (cada cupón se usa
      // una vez por cliente y este pedido no se va a cobrar). Las lecturas
      // de una transacción van antes de las escrituras.
      final cupon = data['codigoCupon'];
      final cliente = data['idCliente'];
      final negocio = data['idNegocio'];
      DocumentReference<Map<String, dynamic>>? usoCupon;
      if (cupon is String && cupon.isNotEmpty && cliente is String && cliente.isNotEmpty && negocio is String) {
        final ref = _db
            .collection('negocios')
            .doc(negocio)
            .collection('cupones')
            .doc(cupon)
            .collection('usos')
            .doc(cliente);
        try {
          final uso = await tx.get(ref);
          if (uso.exists && uso.data()?['idPedido'] == idPedido) usoCupon = ref;
        } catch (_) {
          // Sin permiso para verlo: el pedido se cancela igual.
        }
      }
      // Stock a devolver: solo si ya se había descontado (desde "En
      // preparación") y solo de productos con control de stock.
      final devoluciones = <DocumentReference<Map<String, dynamic>>, Map<String, dynamic>>{};
      if (devolverStock && actual != PedidoEstado.pendiente) {
        final porProducto = <String, int>{};
        for (final l in DetallePedidoModel.desdePedido(data)) {
          if (l.idProducto.isEmpty) continue;
          porProducto[l.idProducto] = (porProducto[l.idProducto] ?? 0) + l.cantidad;
        }
        // Lo que incluye un combo también vuelve al stock; las reglas lo
        // aceptan si se dice de qué combo del pedido salió (devolucionCombo).
        final suma = await _sumarCombos(porProducto);
        for (final e in suma.cantidades.entries) {
          final refProducto = _db.collection('productos').doc(e.key);
          final producto = await tx.get(refProducto);
          final stock = (producto.data()?['stock'] as num?)?.toInt();
          if (!producto.exists || stock == null) continue;
          final combo = porProducto.containsKey(e.key) ? null : suma.deCombo[e.key];
          devoluciones[refProducto] = {
            'stock': stock + e.value,
            if (stock <= 0) 'disponible': true,
            'devolucionDe': idPedido,
            if (combo != null) 'devolucionCombo': combo,
          };
        }
      }
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
      if (usoCupon != null) tx.delete(usoCupon);
      devoluciones.forEach((refProducto, cambios) => tx.update(refProducto, cambios));
    });
  }

  /// El cliente cancela su propio pedido mientras sigue Pendiente (antes de
  /// que el local lo acepte). Si usó un cupón, lo recupera. Si el local ya
  /// lo aceptó, lanza un error con un mensaje claro.
  Future<void> cancelarPorCliente({required String idPedido, required String idCliente}) async {
    final ref = _pedidos.doc(idPedido);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || data['idCliente'] != idCliente) {
        throw PedidoEstadoException(tr('No se encontró el pedido.'));
      }
      if (data['estado'] != PedidoEstado.pendiente) {
        throw PedidoEstadoException(
            tr('El local ya aceptó tu pedido; ya no se puede cancelar desde aquí. Comunícate con el local.'));
      }
      DocumentReference<Map<String, dynamic>>? usoCupon;
      final cupon = data['codigoCupon'];
      final negocio = data['idNegocio'];
      if (cupon is String && cupon.isNotEmpty && negocio is String) {
        final r = _db
            .collection('negocios')
            .doc(negocio)
            .collection('cupones')
            .doc(cupon)
            .collection('usos')
            .doc(idCliente);
        try {
          final uso = await tx.get(r);
          if (uso.exists && uso.data()?['idPedido'] == idPedido) usoCupon = r;
        } catch (_) {
          // Si no se puede ver el uso, el pedido se cancela igual.
        }
      }
      tx.update(ref, {'estado': PedidoEstado.cancelado});
      tx.set(
        ref.collection('historialEstados').doc(),
        HistorialEstadoModel(
          id: '',
          estado: PedidoEstado.cancelado,
          idUsuarioQueCambio: idCliente,
          comentario: 'Cancelado por el cliente.',
        ).toMap(),
      );
      if (usoCupon != null) tx.delete(usoCupon);
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
