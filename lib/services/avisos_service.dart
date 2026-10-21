import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/idioma.dart';
import '../models/pedido_models.dart';
import '../utils/sonido.dart';
import 'pedido_service.dart';
import 'sesion_actual.dart';

/// Un aviso para el cliente: "Tu pedido #abc123 está listo".
class Aviso {
  final String idPedido;
  final String estado;
  final String modalidad;
  final DateTime fecha;
  final bool leido;

  const Aviso({
    required this.idPedido,
    required this.estado,
    required this.modalidad,
    required this.fecha,
    this.leido = false,
  });

  String get numero => idPedido.length >= 6 ? idPedido.substring(0, 6) : idPedido;

  /// Texto en el idioma actual del cliente.
  String get texto {
    final datos = {'id': numero};
    switch (estado) {
      case PedidoEstado.enPreparacion:
        return tr('Tu pedido #{id} se está preparando.', datos);
      case PedidoEstado.listo:
        return modalidad == PedidoModalidad.recoger
            ? tr('Tu pedido #{id} está listo. ¡Pasa a recogerlo!', datos)
            : tr('Tu pedido #{id} está listo.', datos);
      case PedidoEstado.enCamino:
        return tr('Tu pedido #{id} va en camino.', datos);
      case PedidoEstado.llego:
        return tr('El repartidor llegó con tu pedido #{id}.', datos);
      case PedidoEstado.entregado:
        return tr('Tu pedido #{id} fue entregado. ¡Buen provecho!', datos);
      case PedidoEstado.cancelado:
        return tr('Tu pedido #{id} fue cancelado. Toca para ver el motivo.', datos);
      default:
        return tr('Tu pedido #{id} cambió de estado.', datos);
    }
  }

  Aviso leidoComo(bool valor) =>
      Aviso(idPedido: idPedido, estado: estado, modalidad: modalidad, fecha: fecha, leido: valor);

  Map<String, dynamic> toJson() => {
        'p': idPedido,
        'e': estado,
        'm': modalidad,
        'f': fecha.millisecondsSinceEpoch,
        'l': leido,
      };

  factory Aviso.fromJson(Map<String, dynamic> j) => Aviso(
        idPedido: j['p'] as String? ?? '',
        estado: j['e'] as String? ?? '',
        modalidad: j['m'] as String? ?? '',
        fecha: DateTime.fromMillisecondsSinceEpoch((j['f'] as num?)?.toInt() ?? 0),
        leido: j['l'] as bool? ?? false,
      );
}

/// Avisos dentro de la app para el cliente: cada vez que uno de sus pedidos
/// cambia de estado (lo prepara la cocina, está listo, va en camino...),
/// se agrega un aviso a la campanita, suena y aparece un mensaje.
///
/// Funciona sin servidor: compara los estados de sus pedidos con los que
/// vio la última vez (guardados en el dispositivo). Si el estado cambió
/// mientras la app estaba cerrada, el aviso aparece al volver a entrar.
class AvisosService {
  AvisosService._();
  static final instancia = AvisosService._();

  static const _maxAvisos = 40;

  final ValueNotifier<List<Aviso>> avisos = ValueNotifier(const []);

  /// Avisos nuevos en este momento (para mostrar el mensaje emergente).
  final _nuevos = StreamController<Aviso>.broadcast();
  Stream<Aviso> get nuevos => _nuevos.stream;

  StreamSubscription<List<PedidoModel>>? _sub;
  String? _uid;
  Map<String, String> _estadosVistos = {};
  bool _tieneHistorial = false;

  int get sinLeer => avisos.value.where((a) => !a.leido).length;

  String _clave(String uid, String que) => 'avisos_${que}_$uid';

  Future<void> iniciar(String uid) async {
    if (_uid == uid && _sub != null) return;
    await detener();
    _uid = uid;
    await _cargar(uid);
    _sub = PedidoService.instancia.streamPedidosCliente(uid).listen(_procesar, onError: (_) {});
  }

  Future<void> detener() async {
    await _sub?.cancel();
    _sub = null;
    _uid = null;
    avisos.value = const [];
    _estadosVistos = {};
  }

  Future<void> _cargar(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final estados = prefs.getString(_clave(uid, 'estados'));
      _tieneHistorial = estados != null;
      _estadosVistos = estados == null ? {} : Map<String, String>.from(jsonDecode(estados) as Map);
      final lista = prefs.getString(_clave(uid, 'lista'));
      avisos.value = lista == null
          ? const []
          : (jsonDecode(lista) as List)
              .map((e) => Aviso.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
    } catch (_) {
      _estadosVistos = {};
      avisos.value = const [];
    }
  }

  Future<void> _guardar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave(uid, 'estados'), jsonEncode(_estadosVistos));
      await prefs.setString(_clave(uid, 'lista'), jsonEncode(avisos.value.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }

  void _procesar(List<PedidoModel> pedidos) {
    final nuevos = <Aviso>[];
    for (final p in pedidos) {
      final anterior = _estadosVistos[p.id];
      _estadosVistos[p.id] = p.estado;
      // La primera vez que se usa en este dispositivo no se avisa de todo
      // el historial; tampoco del pedido recién creado (Pendiente).
      if (!_tieneHistorial || anterior == p.estado) continue;
      if (anterior == null && p.estado == PedidoEstado.pendiente) continue;
      nuevos.add(Aviso(idPedido: p.id, estado: p.estado, modalidad: p.modalidad, fecha: DateTime.now()));
    }
    _tieneHistorial = true;
    if (nuevos.isNotEmpty) {
      final lista = [...nuevos, ...avisos.value];
      avisos.value = lista.length > _maxAvisos ? lista.sublist(0, _maxAvisos) : lista;
      final quiereAvisos = SesionActual.instancia.actual?.notificacionesActivas ?? true;
      if (quiereAvisos) {
        for (final a in nuevos) {
          _nuevos.add(a);
        }
        sonarAvisoPedido();
      }
    }
    _guardar();
  }

  void marcarTodosLeidos() {
    if (sinLeer == 0) return;
    avisos.value = avisos.value.map((a) => a.leidoComo(true)).toList();
    _guardar();
  }

  void borrarTodos() {
    avisos.value = const [];
    _guardar();
  }
}
