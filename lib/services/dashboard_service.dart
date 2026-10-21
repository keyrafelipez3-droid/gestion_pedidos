import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caja_models.dart';
import '../models/pedido_models.dart';

/// Un producto en el ranking de más vendidos.
class ProductoVendido {
  final String nombre;
  final int cantidad;
  final double total;
  const ProductoVendido(this.nombre, this.cantidad, this.total);
}

/// Datos de los paneles (dashboard) del Administrador y del SuperAdmin.
///
/// Todo sale de Firestore, nunca se inventa un número. Solo se usan
/// consultas que funcionan con los índices que el proyecto ya tiene
/// (igualdades, o un rango sobre un solo campo), para que el panel no
/// dependa de publicar índices nuevos.
class DashboardService {
  DashboardService._();
  static final instancia = DashboardService._();

  final _db = FirebaseFirestore.instance;

  /// Cajas abiertas ahora mismo en el negocio (quién está cobrando).
  Stream<List<CajaModel>> streamCajasAbiertas(String idNegocio) => _db
      .collection('cajas')
      .where('idNegocio', isEqualTo: idNegocio)
      .where('estado', isEqualTo: CajaEstado.abierta)
      .snapshots()
      .map((qs) => qs.docs.map(CajaModel.fromSnapshot).toList());

  /// SuperAdmin: todos los pedidos de la plataforma creados desde [desde]
  /// (un rango sobre un solo campo: Firestore no necesita índice compuesto).
  Stream<List<PedidoModel>> streamPedidosPlataforma(DateTime desde) => _db
      .collection('pedidos')
      .where('fechaCreacion', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
      .snapshots()
      .map((qs) => qs.docs.map(PedidoModel.fromSnapshot).toList());

  /// Productos más vendidos dentro de [pedidos] (pedidos entregados).
  /// Lee el detalle de cada pedido, por eso se limita a los [maxPedidos]
  /// más recientes para no gastar lecturas de más.
  Future<List<ProductoVendido>> topProductos(
    List<PedidoModel> pedidos, {
    int maxPedidos = 60,
    int top = 5,
  }) async {
    final recientes = List.of(pedidos)
      ..sort((a, b) => (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
    final elegidos = recientes.take(maxPedidos).toList();
    final detalles = await Future.wait(elegidos.map(
      (p) => _db.collection('pedidos').doc(p.id).collection('detalle').get(),
    ));
    final cantidades = <String, int>{};
    final totales = <String, double>{};
    for (final qs in detalles) {
      for (final doc in qs.docs) {
        final d = DetallePedidoModel.fromSnapshot(doc);
        final nombre = d.nombreProducto.trim().isEmpty ? 'Producto' : d.nombreProducto.trim();
        cantidades[nombre] = (cantidades[nombre] ?? 0) + d.cantidad;
        totales[nombre] = (totales[nombre] ?? 0) + d.subtotal;
      }
    }
    final lista = cantidades.entries
        .map((e) => ProductoVendido(e.key, e.value, redondearDinero(totales[e.key] ?? 0)))
        .toList()
      ..sort((a, b) {
        final porCantidad = b.cantidad.compareTo(a.cantidad);
        return porCantidad != 0 ? porCantidad : b.total.compareTo(a.total);
      });
    return lista.take(top).toList();
  }
}

// ---------------------------------------------------------------------------
// Cálculos sobre listas de pedidos (sin Firestore, fáciles de probar).
// ---------------------------------------------------------------------------

DateTime inicioDelDia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Pedidos cuya fecha de creación cae en el día de [dia].
List<PedidoModel> pedidosDelDia(List<PedidoModel> pedidos, DateTime dia) {
  final inicio = inicioDelDia(dia);
  final fin = inicio.add(const Duration(days: 1));
  return pedidos.where((p) {
    final f = p.fechaCreacion;
    return f != null && !f.isBefore(inicio) && f.isBefore(fin);
  }).toList();
}

/// Pedidos creados en [desde, hasta).
List<PedidoModel> pedidosEntre(List<PedidoModel> pedidos, DateTime desde, DateTime hasta) =>
    pedidos.where((p) {
      final f = p.fechaCreacion;
      return f != null && !f.isBefore(desde) && f.isBefore(hasta);
    }).toList();

double sumarTotales(Iterable<PedidoModel> pedidos) =>
    redondearDinero(pedidos.fold<double>(0, (a, p) => a + p.total));

/// Suma de [valor] agrupada por la clave que devuelve [clave].
Map<String, double> agruparSuma(
  Iterable<PedidoModel> pedidos,
  String Function(PedidoModel) clave,
) {
  final m = <String, double>{};
  for (final p in pedidos) {
    final k = clave(p);
    m[k] = redondearDinero((m[k] ?? 0) + p.total);
  }
  return m;
}

/// Cantidad de pedidos agrupada por la clave que devuelve [clave].
Map<String, int> agruparConteo(
  Iterable<PedidoModel> pedidos,
  String Function(PedidoModel) clave,
) {
  final m = <String, int>{};
  for (final p in pedidos) {
    final k = clave(p);
    m[k] = (m[k] ?? 0) + 1;
  }
  return m;
}

/// Variación porcentual de [actual] respecto de [anterior]; null si no hay
/// base para comparar (la semana anterior no tuvo ventas).
double? variacionPorcentual(double actual, double anterior) {
  if (anterior <= 0) return null;
  return (actual - anterior) / anterior * 100;
}

const diasCortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// Minutos transcurridos desde [desde] hasta ahora (0 si no hay fecha).
int minutosDesde(DateTime? desde) {
  if (desde == null) return 0;
  final m = DateTime.now().difference(desde).inMinutes;
  return m < 0 ? 0 : m;
}

String textoEspera(int minutos) {
  if (minutos < 1) return 'recién';
  if (minutos < 60) return 'hace $minutos min';
  final h = minutos ~/ 60;
  final m = minutos % 60;
  return m == 0 ? 'hace $h h' : 'hace $h h $m min';
}

String bs(double v) => 'Bs ${v.toStringAsFixed(2)}';
