/// Condiciones que cada restaurante ofrece a SUS clientes (las configura
/// su Administrador). Se guardan en `negocios/{id}.condiciones`. Cada vez
/// que el Administrador las cambia, sube [version] y los clientes deben
/// aceptarlas de nuevo antes de su próximo pedido.
class CondicionesNegocio {
  static const reembolsoMismoMedio = 'mismo_medio';
  static const reembolsoEfectivo = 'efectivo_local';
  static const reembolsoCupon = 'cupon';

  static const opcionesReembolso = {
    reembolsoMismoMedio: 'Por el mismo medio con el que pagaste',
    reembolsoEfectivo: 'En efectivo, en el local',
    reembolsoCupon: 'Con un cupón por el mismo monto para tu próximo pedido',
  };

  /// '' = el restaurante todavía no configuró sus condiciones (se usan las
  /// de base).
  final String version;
  final String reembolso;
  final int diasReembolso;
  final String tiempoEntrega; // texto libre: "30 a 45 minutos"
  final String contactoReclamos; // teléfono o correo para reclamos
  final String notas; // reglas propias del restaurante

  const CondicionesNegocio({
    this.version = '',
    this.reembolso = reembolsoMismoMedio,
    this.diasReembolso = 5,
    this.tiempoEntrega = '',
    this.contactoReclamos = '',
    this.notas = '',
  });

  String get textoReembolso => opcionesReembolso[reembolso] ?? opcionesReembolso[reembolsoMismoMedio]!;

  Map<String, dynamic> toMap() => {
        'version': version,
        'reembolso': reembolso,
        'diasReembolso': diasReembolso,
        'tiempoEntrega': tiempoEntrega,
        'contactoReclamos': contactoReclamos,
        'notas': notas,
      };

  factory CondicionesNegocio.desde(Object? valor) {
    if (valor is! Map) return const CondicionesNegocio();
    return CondicionesNegocio(
      version: valor['version'] as String? ?? '',
      reembolso: valor['reembolso'] as String? ?? reembolsoMismoMedio,
      diasReembolso: (valor['diasReembolso'] as num?)?.toInt() ?? 5,
      tiempoEntrega: valor['tiempoEntrega'] as String? ?? '',
      contactoReclamos: valor['contactoReclamos'] as String? ?? '',
      notas: valor['notas'] as String? ?? '',
    );
  }
}

/// Reglas internas que el restaurante agrega al acuerdo de su personal
/// (`negocios/{id}.reglasPersonal`). Si cambian, todo el personal firma
/// de nuevo.
class ReglasPersonal {
  final String version;
  final List<String> reglas;

  const ReglasPersonal({this.version = '', this.reglas = const []});

  Map<String, dynamic> toMap() => {'version': version, 'reglas': reglas};

  factory ReglasPersonal.desde(Object? valor) {
    if (valor is! Map) return const ReglasPersonal();
    return ReglasPersonal(
      version: valor['version'] as String? ?? '',
      reglas: [
        if (valor['reglas'] is List)
          for (final r in valor['reglas'] as List)
            if (r is String && r.trim().isNotEmpty) r.trim(),
      ],
    );
  }
}
