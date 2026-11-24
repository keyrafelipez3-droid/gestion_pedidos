import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido_models.dart';
import '../models/usuario_model.dart';
import '../utils/sonido.dart';
import 'pedido_service.dart';
import 'reclamo_service.dart';
import 'resena_service.dart';
import 'sesion_actual.dart';
import 'solicitudes_service.dart';

/// Tipos de aviso de la campanita del personal.
class TipoAvisoPersonal {
  TipoAvisoPersonal._();

  static const String pedidoNuevo = 'pedido_nuevo';
  static const String pedidoListo = 'pedido_listo';
  static const String pedidoCancelado = 'pedido_cancelado';
  static const String entregaDisponible = 'entrega_disponible';
  static const String entregaAsignada = 'entrega_asignada';
  static const String resenaNueva = 'resena_nueva';
  static const String reclamoNuevo = 'reclamo_nuevo';
  static const String solicitudNueva = 'solicitud_nueva';

  /// Qué avisa la campanita a cada rol. El cliente tiene su propia
  /// campanita (AvisosService), con los cambios de estado de sus pedidos.
  static List<String> delRol(String rol) => switch (rol) {
        Rol.cocina => const [pedidoNuevo, pedidoCancelado],
        Rol.cajero => const [pedidoNuevo, pedidoListo, pedidoCancelado],
        Rol.repartidor => const [entregaDisponible, entregaAsignada],
        Rol.administrador => const [pedidoNuevo, pedidoCancelado, resenaNueva, reclamoNuevo],
        Rol.superAdmin => const [solicitudNueva],
        _ => const [],
      };
}

/// Un aviso de la campanita del personal ("Nuevo pedido #abc123").
class AvisoPersonal {
  final String tipo;

  /// Lo que se avisa (id del pedido, de la reseña, del reclamo o de la
  /// solicitud). Junto con el tipo identifica al aviso: el mismo aviso
  /// no se repite.
  final String idRef;
  final String texto;
  final DateTime fecha;
  final bool leido;

  const AvisoPersonal({
    required this.tipo,
    required this.idRef,
    required this.texto,
    required this.fecha,
    this.leido = false,
  });

  String get clave => '$tipo:$idRef';

  /// true si al tocarlo se abre el detalle de un pedido.
  bool get esDePedido =>
      tipo != TipoAvisoPersonal.resenaNueva &&
      tipo != TipoAvisoPersonal.reclamoNuevo &&
      tipo != TipoAvisoPersonal.solicitudNueva;

  AvisoPersonal leidoComo(bool valor) =>
      AvisoPersonal(tipo: tipo, idRef: idRef, texto: texto, fecha: fecha, leido: valor);

  Map<String, dynamic> toJson() => {
        't': tipo,
        'r': idRef,
        'x': texto,
        'f': fecha.millisecondsSinceEpoch,
        'l': leido,
      };

  factory AvisoPersonal.fromJson(Map<String, dynamic> j) => AvisoPersonal(
        tipo: j['t'] as String? ?? '',
        idRef: j['r'] as String? ?? '',
        texto: j['x'] as String? ?? '',
        fecha: DateTime.fromMillisecondsSinceEpoch((j['f'] as num?)?.toInt() ?? 0),
        leido: j['l'] as bool? ?? false,
      );
}

/// Algo que la campanita vigila (un pedido, una reseña...) con su estado
/// actual y el aviso que daría.
class ElementoVigilado {
  final String id;
  final String estado;
  final AvisoPersonal? Function(String? estadoAnterior) aviso;

  const ElementoVigilado(this.id, this.estado, this.aviso);
}

/// Compara lo que se ve ahora con lo que ya se había visto ([vistos]:
/// id → estado) y devuelve los avisos nuevos. Si [vistos] es null es la
/// primera vez en este dispositivo: no se avisa de todo lo que ya existía.
List<AvisoPersonal> detectarAvisos(Map<String, String>? vistos, List<ElementoVigilado> ahora) {
  if (vistos == null) return const [];
  final nuevos = <AvisoPersonal>[];
  for (final e in ahora) {
    final antes = vistos[e.id];
    if (antes == e.estado) continue;
    final a = e.aviso(antes);
    if (a != null) nuevos.add(a);
  }
  return nuevos;
}

/// Número corto del pedido (#abc123).
String numeroPedido(String id) => (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();

/// Avisos de cada fuente según el rol. Son funciones puras para poder
/// probarlas sin Firebase.
class ReglasAvisoPersonal {
  ReglasAvisoPersonal._();

  /// Pedidos en curso de la cocina, la caja o el administrador.
  static ElementoVigilado pedidoEnCurso(
    PedidoModel p, {
    required String rol,
    required String uid,
    required DateTime ahora,
  }) =>
      ElementoVigilado(p.id, p.estado, (antes) {
        final numero = numeroPedido(p.id);
        // El pedido de mesa que registró la misma persona no le avisa.
        final propio = p.creadoPor != null && p.creadoPor == uid;
        if (antes == null && p.estado == PedidoEstado.pendiente && !propio) {
          return AvisoPersonal(
            tipo: TipoAvisoPersonal.pedidoNuevo,
            idRef: p.id,
            texto: rol == Rol.cocina
                ? 'Nuevo pedido #$numero para preparar · ${p.etiquetaModalidad}'
                : 'Nuevo pedido #$numero · ${p.etiquetaModalidad}',
            fecha: ahora,
          );
        }
        if (rol == Rol.cajero &&
            antes != null &&
            antes != PedidoEstado.listo &&
            p.estado == PedidoEstado.listo) {
          return AvisoPersonal(
            tipo: TipoAvisoPersonal.pedidoListo,
            idRef: p.id,
            texto: p.modalidad == PedidoModalidad.delivery
                ? 'El pedido #$numero está listo para el repartidor'
                : 'El pedido #$numero está listo para entregar',
            fecha: ahora,
          );
        }
        return null;
      });

  /// Pedidos cancelados de hoy.
  static ElementoVigilado cancelado(PedidoModel p, {required DateTime ahora}) =>
      ElementoVigilado(p.id, p.estado, (antes) {
        if (antes != null) return null;
        return AvisoPersonal(
          tipo: TipoAvisoPersonal.pedidoCancelado,
          idRef: p.id,
          texto: 'Se canceló el pedido #${numeroPedido(p.id)}. Toca para ver el motivo.',
          fecha: ahora,
        );
      });

  /// Entregas listas que ningún repartidor tomó todavía.
  static ElementoVigilado entregaDisponible(PedidoModel p, {required DateTime ahora}) =>
      ElementoVigilado(p.id, p.estado, (antes) {
        if (antes != null) return null;
        final zona = (p.zonaEntrega ?? '').trim();
        return AvisoPersonal(
          tipo: TipoAvisoPersonal.entregaDisponible,
          idRef: p.id,
          texto: 'Nueva entrega disponible: pedido #${numeroPedido(p.id)}'
              '${zona.isEmpty ? '' : ' · $zona'}',
          fecha: ahora,
        );
      });

  /// Entregas del repartidor. Solo avisa las que le asignó la caja (las
  /// que él mismo tomó pasan directo a "En camino").
  static ElementoVigilado entregaMia(PedidoModel p, {required DateTime ahora}) =>
      ElementoVigilado(p.id, p.estado, (antes) {
        if (antes != null || p.estado != PedidoEstado.listo) return null;
        return AvisoPersonal(
          tipo: TipoAvisoPersonal.entregaAsignada,
          idRef: p.id,
          texto: 'Te asignaron el pedido #${numeroPedido(p.id)}. Pasa a recogerlo.',
          fecha: ahora,
        );
      });

  /// Reseña nueva (Administrador).
  static ElementoVigilado resena(
    String id,
    int calificacion,
    String nombre, {
    required DateTime ahora,
  }) =>
      ElementoVigilado(id, 'r', (antes) {
        if (antes != null) return null;
        return AvisoPersonal(
          tipo: TipoAvisoPersonal.resenaNueva,
          idRef: id,
          texto: 'Nueva reseña de $calificacion ${calificacion == 1 ? 'estrella' : 'estrellas'}'
              '${nombre.trim().isEmpty ? '' : ' de ${nombre.trim()}'}',
          fecha: ahora,
        );
      });

  /// Reclamo nuevo (Administrador).
  static ElementoVigilado reclamo(String id, String motivo, {required DateTime ahora}) =>
      ElementoVigilado(id, 'r', (antes) {
        if (antes != null) return null;
        return AvisoPersonal(
          tipo: TipoAvisoPersonal.reclamoNuevo,
          idRef: id,
          texto: 'Nuevo reclamo: $motivo',
          fecha: ahora,
        );
      });

  /// Solicitud de negocio nueva (SuperAdmin).
  static ElementoVigilado solicitud(String id, String negocio, {required DateTime ahora}) =>
      ElementoVigilado(id, 'p', (antes) {
        if (antes != null) return null;
        return AvisoPersonal(
          tipo: TipoAvisoPersonal.solicitudNueva,
          idRef: id,
          texto: 'Nueva solicitud de negocio: $negocio',
          fecha: ahora,
        );
      });
}

/// Campanita del personal (Administrador, Cajero, Cocina, Repartidor y
/// SuperAdmin): junta los avisos de su rol mientras tiene la sesión
/// abierta y los guarda en el dispositivo, para verlos al volver a entrar
/// con su correo y contraseña.
///
/// Funciona sin servidor (el proyecto no usa Cloud Functions): usa las
/// mismas consultas que ya tienen las pantallas de cada rol y compara con
/// lo que ya vio la última vez en este dispositivo.
class AvisosPersonalService {
  AvisosPersonalService._();
  static final instancia = AvisosPersonalService._();

  static const _maxAvisos = 50;
  static const _maxVistos = 300;

  final ValueNotifier<List<AvisoPersonal>> avisos = ValueNotifier(const []);

  final _nuevos = StreamController<AvisoPersonal>.broadcast();

  /// Avisos que llegan en este momento (para el mensaje emergente).
  Stream<AvisoPersonal> get nuevos => _nuevos.stream;

  final List<StreamSubscription<List<ElementoVigilado>>> _subs = [];
  final Map<String, LinkedHashMap<String, String>?> _vistos = {};
  String? _uid;

  int get sinLeer => avisos.value.where((a) => !a.leido).length;

  String _clave(String uid, String que) => 'avisosPersonal_${que}_$uid';

  Future<void> iniciar(UsuarioModel u) async {
    if (_uid == u.idUsuario && _subs.isNotEmpty) return;
    await detener();
    _uid = u.idUsuario;
    final fuentes = _fuentes(u);
    await _cargar(u.idUsuario, fuentes.keys);
    if (_uid != u.idUsuario) return; // cerró sesión mientras cargaba
    fuentes.forEach((nombre, stream) {
      _subs.add(stream.listen((lista) => _procesar(nombre, lista), onError: (_) {}));
    });
  }

  Future<void> detener() async {
    final activas = List.of(_subs);
    _subs.clear();
    for (final s in activas) {
      await s.cancel();
    }
    _uid = null;
    _vistos.clear();
    avisos.value = const [];
  }

  /// Qué consulta vigila cada rol. Cajero y Cocina con sucursal ven solo su
  /// sucursal (lo hace PedidoService).
  Map<String, Stream<List<ElementoVigilado>>> _fuentes(UsuarioModel u) {
    final idNegocio = u.idNegocio ?? '';
    final uid = u.idUsuario;
    final pedidos = PedidoService.instancia;
    DateTime ahora() => DateTime.now();
    if (u.esSuperAdmin) {
      return {
        'solicitudes': SolicitudesService.instancia.streamPendientes().map((l) => [
              for (final s in l)
                ReglasAvisoPersonal.solicitud(s.idUsuario, s.nombreNegocio, ahora: ahora()),
            ]),
      };
    }
    if (idNegocio.isEmpty) return const {};
    Stream<List<ElementoVigilado>> enCurso() =>
        pedidos.streamPedidosEnCurso(idNegocio).map((l) => [
              for (final p in l)
                ReglasAvisoPersonal.pedidoEnCurso(p, rol: u.rol, uid: uid, ahora: ahora()),
            ]);
    Stream<List<ElementoVigilado>> cancelados() =>
        pedidos.streamCanceladosRecientes(idNegocio, dias: 1).map((l) => [
              for (final p in l) ReglasAvisoPersonal.cancelado(p, ahora: ahora()),
            ]);
    switch (u.rol) {
      case Rol.cocina:
        return {
          'cocina': pedidos.streamPedidosCocina(idNegocio).map((l) => [
                for (final p in l)
                  ReglasAvisoPersonal.pedidoEnCurso(p, rol: u.rol, uid: uid, ahora: ahora()),
              ]),
          'cancelados': cancelados(),
        };
      case Rol.cajero:
        return {'enCurso': enCurso(), 'cancelados': cancelados()};
      case Rol.repartidor:
        return {
          'disponibles': pedidos
              .streamEntregasDisponibles(idNegocio, idSucursal: u.idSucursal)
              .map((l) => [for (final p in l) ReglasAvisoPersonal.entregaDisponible(p, ahora: ahora())]),
          'mias': pedidos
              .streamMisEntregas(idNegocio, uid)
              .map((l) => [for (final p in l) ReglasAvisoPersonal.entregaMia(p, ahora: ahora())]),
        };
      case Rol.administrador:
        return {
          'enCurso': enCurso(),
          'cancelados': cancelados(),
          'resenas': ResenaService.instancia.streamRecientes(idNegocio).map((l) => [
                for (final r in l)
                  ReglasAvisoPersonal.resena(r.id, r.calificacion, r.nombreCliente, ahora: ahora()),
              ]),
          'reclamos': ReclamoService.instancia.streamRecientes(idNegocio).map((l) => [
                for (final r in l) ReglasAvisoPersonal.reclamo(r.id, r.motivo, ahora: ahora()),
              ]),
        };
      default:
        return const {};
    }
  }

  Future<void> _cargar(String uid, Iterable<String> fuentes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final f in fuentes) {
        final guardado = prefs.getString(_clave(uid, 'vistos_$f'));
        _vistos[f] = guardado == null
            ? null
            : LinkedHashMap<String, String>.from(jsonDecode(guardado) as Map);
      }
      final lista = prefs.getString(_clave(uid, 'lista'));
      avisos.value = lista == null
          ? const []
          : (jsonDecode(lista) as List)
              .map((e) => AvisoPersonal.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
    } catch (_) {
      for (final f in fuentes) {
        _vistos[f] = null;
      }
      avisos.value = const [];
    }
  }

  Future<void> _guardar() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final e in _vistos.entries) {
        final v = e.value;
        if (v != null) await prefs.setString(_clave(uid, 'vistos_${e.key}'), jsonEncode(v));
      }
      await prefs.setString(_clave(uid, 'lista'), jsonEncode(avisos.value.map((a) => a.toJson()).toList()));
    } catch (_) {}
  }

  void _procesar(String fuente, List<ElementoVigilado> lista) {
    final vistos = _vistos[fuente];
    final detectados = detectarAvisos(vistos, lista);
    // Se guarda lo visto sin borrar lo anterior (si la primera respuesta
    // viene de la copia del teléfono, incompleta, no se vuelve a avisar
    // de lo que ya se había visto). Se conservan los últimos 300.
    final nuevoMapa = LinkedHashMap<String, String>.from(vistos ?? const {});
    for (final e in lista) {
      nuevoMapa.remove(e.id);
      nuevoMapa[e.id] = e.estado;
    }
    while (nuevoMapa.length > _maxVistos) {
      nuevoMapa.remove(nuevoMapa.keys.first);
    }
    _vistos[fuente] = nuevoMapa;
    // El mismo aviso no se repite.
    final ya = avisos.value.map((a) => a.clave).toSet();
    final nuevos = [
      for (final a in detectados)
        if (ya.add(a.clave)) a,
    ];
    if (nuevos.isNotEmpty) {
      final todos = [...nuevos, ...avisos.value];
      avisos.value = todos.length > _maxAvisos ? todos.sublist(0, _maxAvisos) : todos;
      final quiereAvisos = SesionActual.instancia.actual?.notificacionesActivas ?? true;
      if (quiereAvisos) {
        for (final a in nuevos) {
          _nuevos.add(a);
        }
      }
    }
    _guardar();
  }

  /// Suena el aviso (lo llama la pantalla al mostrar el mensaje).
  void sonar() => sonarAvisoPedido();

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
