import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriaModel {
  final String id;
  final String nombre;
  final String descripcion;
  final bool estado;

  const CategoriaModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.estado = true,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'estado': estado,
      };

  factory CategoriaModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CategoriaModel(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      descripcion: data['descripcion'] as String? ?? '',
      estado: data['estado'] as bool? ?? true,
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

  const ProductoModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.precio = 0,
    this.idCategoria = '',
    this.imagenUrl = '',
    this.estado = true,
    this.disponible = true,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'idCategoria': idCategoria,
        'imagenUrl': imagenUrl,
        'estado': estado,
        'disponible': disponible,
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
    );
  }
}

class ComplementoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final bool estado;

  const ComplementoModel({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.precio = 0,
    this.estado = true,
  });

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'estado': estado,
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
    );
  }
}

class VarianteModel {
  final String id;
  final String idProducto;
  final String nombre;
  final double precioAdicional;
  final bool estado;

  const VarianteModel({
    required this.id,
    required this.idProducto,
    required this.nombre,
    this.precioAdicional = 0,
    this.estado = true,
  });

  Map<String, dynamic> toMap() => {
        'idProducto': idProducto,
        'nombre': nombre,
        'precioAdicional': precioAdicional,
        'estado': estado,
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
    );
  }
}
