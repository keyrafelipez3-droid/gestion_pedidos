import 'package:cloud_firestore/cloud_firestore.dart';

/// Una variante o complemento ya elegido dentro de un item del carrito.
/// Se guarda "congelado" (nombre + precio en el momento de agregar al
/// carrito) para que el total no cambie si el Administrador edita luego
/// el precio de esa variante/complemento — mismo criterio que usará
/// DetallePedido más adelante (ver diseno-base-de-datos.md: "las
/// relaciones se implementan ... en DetallePedido por denormalización").
class OpcionSeleccionada {
  final String id;
  final String nombre;
  final double precio;

  const OpcionSeleccionada({
    required this.id,
    required this.nombre,
    this.precio = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'precio': precio,
      };

  factory OpcionSeleccionada.fromMap(Map<String, dynamic> data) {
    final raw = data['precio'];
    return OpcionSeleccionada(
      id: data['id'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      precio: raw is num ? raw.toDouble() : 0,
    );
  }
}

/// Documento de `usuarios/{uid}/carritoItems/{itemId}` (HU-20 a HU-23).
/// Cada documento es UNA línea del carrito: un producto + las variantes/
/// complementos elegidos + cantidad + notas. Igual que con favoritos,
/// vive como subcolección de usuarios/{uid} y ya queda cubierta por la
/// regla genérica de subcolecciones en firestore.rules — no hizo falta
/// agregar reglas nuevas.
class CarritoItemModel {
  final String id;
  final String idProducto;
  final String nombreProducto;
  final String imagenUrl;
  final double precioUnitario;
  final int cantidad;
  final List<OpcionSeleccionada> variantes;
  final List<OpcionSeleccionada> complementos;
  final String notas;
  final String idNegocio;
  final DateTime? fechaAgregado;

  const CarritoItemModel({
    required this.id,
    required this.idProducto,
    required this.nombreProducto,
    this.imagenUrl = '',
    required this.precioUnitario,
    this.cantidad = 1,
    this.variantes = const [],
    this.complementos = const [],
    this.notas = '',
    required this.idNegocio,
    this.fechaAgregado,
  });

  /// Precio de UNA unidad del item, ya con sus variantes/complementos
  /// sumados (sin multiplicar por cantidad todavía).
  double get precioUnitarioConOpciones {
    final extras = [...variantes, ...complementos]
        .fold<double>(0, (acc, o) => acc + o.precio);
    return precioUnitario + extras;
  }

  /// Subtotal de esta línea del carrito (HU-23: consultar el total).
  double get subtotal => precioUnitarioConOpciones * cantidad;

  /// Identifica "el mismo item" (mismo producto + mismas opciones + misma
  /// nota) para que CarritoService decida si sumar cantidad en vez de
  /// duplicar la línea al agregar de nuevo. El orden de variantes/
  /// complementos no debería importar, por eso se ordenan los ids antes
  /// de unirlos.
  String get claveAgrupacion {
    final idsVariantes = variantes.map((v) => v.id).toList()..sort();
    final idsComplementos = complementos.map((c) => c.id).toList()..sort();
    return '$idProducto|${idsVariantes.join(',')}|${idsComplementos.join(',')}|$notas';
  }

  Map<String, dynamic> toMap() => {
        'idProducto': idProducto,
        'nombreProducto': nombreProducto,
        'imagenUrl': imagenUrl,
        'precioUnitario': precioUnitario,
        'cantidad': cantidad,
        'variantes': variantes.map((v) => v.toMap()).toList(),
        'complementos': complementos.map((c) => c.toMap()).toList(),
        'notas': notas,
        'idNegocio': idNegocio,
        'fechaAgregado': FieldValue.serverTimestamp(),
      };

  factory CarritoItemModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrecio = data['precioUnitario'];
    final ts = data['fechaAgregado'] as Timestamp?;
    return CarritoItemModel(
      id: doc.id,
      idProducto: data['idProducto'] as String? ?? '',
      nombreProducto: data['nombreProducto'] as String? ?? '',
      imagenUrl: data['imagenUrl'] as String? ?? '',
      precioUnitario: rawPrecio is num ? rawPrecio.toDouble() : 0,
      cantidad: (data['cantidad'] as num?)?.toInt() ?? 1,
      variantes: ((data['variantes'] as List?) ?? [])
          .map((v) => OpcionSeleccionada.fromMap(Map<String, dynamic>.from(v as Map)))
          .toList(),
      complementos: ((data['complementos'] as List?) ?? [])
          .map((c) => OpcionSeleccionada.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
      notas: data['notas'] as String? ?? '',
      idNegocio: data['idNegocio'] as String? ?? '',
      fechaAgregado: ts?.toDate(),
    );
  }
}
