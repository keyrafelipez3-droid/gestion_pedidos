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
  });

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
