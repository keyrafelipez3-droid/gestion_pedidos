/// Permisos que el Administrador puede ajustar para los roles de SU
/// negocio. Se guardan en `negocios/{id}.permisos` y las reglas de
/// Firestore los hacen cumplir en el servidor (no solo en la pantalla).
class PermisosNegocio {
  /// El Cajero puede cancelar pedidos (con motivo).
  final bool cajeroCancelaPedidos;

  /// El Cajero puede registrar egresos (salidas de dinero) de su caja.
  final bool cajeroRegistraEgresos;

  /// El Cajero puede tomar pedidos en mesa.
  final bool cajeroTomaPedidosMesa;

  /// La Cocina puede cancelar pedidos (por ejemplo, si falta un insumo).
  final bool cocinaCancelaPedidos;

  const PermisosNegocio({
    this.cajeroCancelaPedidos = true,
    this.cajeroRegistraEgresos = true,
    this.cajeroTomaPedidosMesa = true,
    this.cocinaCancelaPedidos = false,
  });

  static const porDefecto = PermisosNegocio();

  /// Nombre, título y explicación de cada permiso (para la pantalla).
  static const descripciones = <(String, String, String)>[
    ('cajeroCancelaPedidos', 'Cajero: cancelar pedidos', 'Puede cancelar un pedido indicando el motivo.'),
    ('cajeroRegistraEgresos', 'Cajero: registrar egresos', 'Puede sacar dinero de la caja (compras, cambio, etc.).'),
    ('cajeroTomaPedidosMesa', 'Cajero: tomar pedidos en mesa', 'Puede registrar pedidos de los clientes en las mesas.'),
    ('cocinaCancelaPedidos', 'Cocina: cancelar pedidos', 'Puede cancelar un pedido, por ejemplo si falta un insumo.'),
  ];

  factory PermisosNegocio.desde(Object? raw) {
    final m = raw is Map ? raw : const {};
    bool b(String k, bool def) => m[k] is bool ? m[k] as bool : def;
    return PermisosNegocio(
      cajeroCancelaPedidos: b('cajeroCancelaPedidos', true),
      cajeroRegistraEgresos: b('cajeroRegistraEgresos', true),
      cajeroTomaPedidosMesa: b('cajeroTomaPedidosMesa', true),
      cocinaCancelaPedidos: b('cocinaCancelaPedidos', false),
    );
  }

  Map<String, bool> toMap() => {
        'cajeroCancelaPedidos': cajeroCancelaPedidos,
        'cajeroRegistraEgresos': cajeroRegistraEgresos,
        'cajeroTomaPedidosMesa': cajeroTomaPedidosMesa,
        'cocinaCancelaPedidos': cocinaCancelaPedidos,
      };

  bool valor(String clave) => toMap()[clave] ?? false;

  PermisosNegocio con(String clave, bool valor) => PermisosNegocio.desde({...toMap(), clave: valor});
}
