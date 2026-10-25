import 'package:cloud_firestore/cloud_firestore.dart';

import 'alergenos.dart';

// Las 4 clases de este archivo llevan `idNegocio` (nullable, por
// compatibilidad con documentos antiguos) desde la corrección pedida por
// el docente: el sistema es multi-tenant y cada Administrador solo debe
// ver/editar el catálogo de SU propio negocio (CatalogoService filtra
// los streams por este campo).

class CategoriaModel {
  final String id;
  final String nombre;
  final String descripcion;
  final String imagenUrl;
  final bool estado;
  final String? idNegocio;

  const CategoriaModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.imagenUrl = '',
    this.estado = true,
    this.idNegocio,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'imagenUrl': imagenUrl,
        'estado': estado,
        'idNegocio': idNegocio,
      };

  factory CategoriaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CategoriaModel(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      imagenUrl: data['imagenUrl'] as String? ?? '',
      estado: data['estado'] as bool? ?? true,
      idNegocio: data['idNegocio'] as String?,
    );
  }
}

class ProductoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String idCategoria;
  final String imagenUrl;
  final bool estado;
  final bool disponible;
  final String? idNegocio;

  /// Códigos de alérgenos que contiene (ver `Alergenos`). Los marca el
  /// Administrador; el cliente ve un aviso si alguno es de sus alergias.
  final List<String> alergenos;

  /// Control de stock (opcional). null = sin control (siempre hay). Se
  /// descuenta cuando la cocina empieza a preparar un pedido; al llegar a
  /// 0 el producto queda "No disponible" solo.
  final int? stock;

  /// Por debajo de esta cantidad se avisa "Poco stock".
  final int stockMinimo;

  /// HU-35: precio de promoción (null = sin promoción) y hasta cuándo
  /// dura (null = hasta que el Administrador la quite).
  final double? precioPromo;
  final DateTime? promoHasta;

  /// HU-37: un combo es un producto con su propio precio que incluye
  /// otros productos del catálogo (sus ids, en orden).
  final bool esCombo;
  final List<String> comboIds;

  const ProductoModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.precio = 0,
    this.idCategoria = '',
    this.imagenUrl = '',
    this.estado = true,
    this.disponible = true,
    this.idNegocio,
    this.alergenos = const [],
    this.stock,
    this.stockMinimo = 5,
    this.precioPromo,
    this.promoHasta,
    this.esCombo = false,
    this.comboIds = const [],
  });

  /// ¿La promoción está vigente? Solo si es más barata que el precio
  /// normal y no venció.
  bool promoActiva([DateTime? ahora]) {
    final p = precioPromo;
    if (p == null || p <= 0 || p >= precio) return false;
    final fin = promoHasta;
    return fin == null || (ahora ?? DateTime.now()).isBefore(fin);
  }

  /// Precio que se cobra hoy (el de promoción si está vigente).
  double precioVigente([DateTime? ahora]) => promoActiva(ahora) ? precioPromo! : precio;

  /// Descuento de la promoción en % (redondeado), 0 si no hay.
  int porcentajePromo([DateTime? ahora]) =>
      promoActiva(ahora) && precio > 0 ? ((1 - precioPromo! / precio) * 100).round() : 0;

  /// Productos que incluye el combo, buscados en [catalogo] (los que ya
  /// no existen se omiten).
  List<ProductoModel> contenidoCombo(Iterable<ProductoModel> catalogo) {
    final porId = {for (final p in catalogo) p.id: p};
    return [for (final id in comboIds) if (porId[id] != null) porId[id]!];
  }

  /// Nombre con el que entra al pedido: un combo lleva lo que incluye, así
  /// la cocina, el ticket y los reportes saben qué preparar.
  String nombreParaPedido(Iterable<ProductoModel> catalogo) {
    if (!esCombo) return nombre;
    final contenido = contenidoCombo(catalogo).map((p) => p.nombre).join(' + ');
    return contenido.isEmpty ? nombre : '$nombre ($contenido)';
  }

  /// Un combo solo se vende si todo lo que incluye se puede vender.
  bool comboDisponible(Iterable<ProductoModel> catalogo) {
    if (!esCombo) return true;
    final contenido = contenidoCombo(catalogo);
    return contenido.length == comboIds.length &&
        contenido.every((p) => p.estado && p.disponible && !p.agotado);
  }

  bool get controlaStock => stock != null;
  bool get agotado => stock != null && stock! <= 0;
  bool get pocoStock => stock != null && stock! > 0 && stock! <= stockMinimo;

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'idCategoria': idCategoria,
        'imagenUrl': imagenUrl,
        'estado': estado,
        'disponible': disponible,
        'idNegocio': idNegocio,
        'alergenos': alergenos,
        'stock': stock,
        'stockMinimo': stockMinimo,
        'precioPromo': precioPromo,
        'promoHasta': promoHasta == null ? null : Timestamp.fromDate(promoHasta!),
        'esCombo': esCombo,
        'comboIds': comboIds,
      };

  factory ProductoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrecio = data['precio'];
    return ProductoModel(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      precio: rawPrecio is num ? rawPrecio.toDouble() : 0,
      idCategoria: data['idCategoria'] as String? ?? '',
      imagenUrl: data['imagenUrl'] as String? ?? '',
      estado: data['estado'] as bool? ?? true,
      disponible: data['disponible'] as bool? ?? true,
      idNegocio: data['idNegocio'] as String?,
      alergenos: Alergenos.desdeFirestore(data['alergenos']),
      stock: (data['stock'] as num?)?.toInt(),
      stockMinimo: (data['stockMinimo'] as num?)?.toInt() ?? 5,
      precioPromo: (data['precioPromo'] as num?)?.toDouble(),
      promoHasta: (data['promoHasta'] as Timestamp?)?.toDate(),
      esCombo: data['esCombo'] as bool? ?? false,
      comboIds: [
        if (data['comboIds'] is List)
          for (final id in data['comboIds'] as List)
            if (id is String) id,
      ],
    );
  }
}

class ComplementoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final bool estado;
  final String? idNegocio;

  const ComplementoModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.precio = 0,
    this.estado = true,
    this.idNegocio,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'estado': estado,
        'idNegocio': idNegocio,
      };

  factory ComplementoModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrecio = data['precio'];
    return ComplementoModel(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      precio: rawPrecio is num ? rawPrecio.toDouble() : 0,
      estado: data['estado'] as bool? ?? true,
      idNegocio: data['idNegocio'] as String?,
    );
  }
}

class VarianteModel {
  final String id;
  final String idProducto;
  final String nombre;
  final double precioAdicional;
  final bool estado;
  final String? idNegocio;

  const VarianteModel({
    required this.id,
    required this.idProducto,
    required this.nombre,
    this.precioAdicional = 0,
    this.estado = true,
    this.idNegocio,
  });

  Map<String, dynamic> toMap() => {
        'idProducto': idProducto,
        'nombre': nombre,
        'precioAdicional': precioAdicional,
        'estado': estado,
        'idNegocio': idNegocio,
      };

  factory VarianteModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final rawPrecio = data['precioAdicional'];
    return VarianteModel(
      id: doc.id,
      idProducto: data['idProducto'] as String? ?? '',
      nombre: data['nombre'] as String? ?? '',
      precioAdicional: rawPrecio is num ? rawPrecio.toDouble() : 0,
      estado: data['estado'] as bool? ?? true,
      idNegocio: data['idNegocio'] as String?,
    );
  }
}
