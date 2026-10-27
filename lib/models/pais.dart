/// País donde opera un restaurante: su moneda, cómo se llama su número de
/// identificación tributaria y las leyes que aplican a los datos
/// personales, a los consumidores y a la firma electrónica.
///
/// Cada restaurante elige su país (`negocios/{id}.pais`). La app usa el
/// país del restaurante que está abierto para mostrar precios, pedir datos
/// de factura y redactar los textos legales.
///
/// Los nombres de leyes y autoridades se revisaron en octubre de 2026.
/// Antes de operar en un país conviene que un abogado de ese país revise
/// los textos.
class Pais {
  final String codigo; // ISO 3166-1 alfa-2: 'BO', 'MX', 'US'...
  final String nombre;

  /// Código ISO 4217 de la moneda ('BOB', 'MXN', 'USD'...).
  final String moneda;
  final String nombreMoneda; // en plural: "bolivianos"
  final String simbolo; // 'Bs', '$', 'S/'...
  final int decimales;

  /// Billetes y monedas, de mayor a menor (para contar la caja).
  final List<double> denominaciones;

  /// Número tributario del negocio ("NIT", "RFC", "RUC", "EIN"...).
  final String idFiscal;

  /// Documento de identidad de las personas ("carnet de identidad", "DNI").
  final String docIdentidad;

  /// Qué escribe el cliente para su factura ("NIT o CI", "RFC", "CPF"...).
  /// Vacío si en el país no se acostumbra pedir factura con un número.
  final String idFactura;

  /// true si los precios se muestran con los impuestos incluidos (en
  /// EE.UU. y Canadá los impuestos se suman al cobrar).
  final bool impuestosIncluidos;

  final double latitud;
  final double longitud;

  // ------------------------------------------------------------- leyes
  /// Ley o leyes de protección de datos personales.
  final String leyDatos;

  /// Autoridad de protección de datos ('' si no hay una específica).
  final String autoridadDatos;

  /// Ley de protección al consumidor.
  final String leyConsumidor;

  /// Dónde reclamar como consumidor.
  final String autoridadConsumidor;

  /// Ley que reconoce la firma o aceptación electrónica.
  final String leyFirma;

  /// Normas laborales (el acuerdo del personal no reemplaza el contrato).
  final String leyTrabajo;

  /// Obligaciones o derechos propios del país, en una frase cada uno.
  final List<String> notas;

  const Pais({
    required this.codigo,
    required this.nombre,
    required this.moneda,
    required this.nombreMoneda,
    required this.simbolo,
    this.decimales = 2,
    required this.denominaciones,
    required this.idFiscal,
    required this.idFactura,
    this.docIdentidad = 'documento de identidad',
    this.impuestosIncluidos = true,
    required this.latitud,
    required this.longitud,
    required this.leyDatos,
    this.autoridadDatos = '',
    required this.leyConsumidor,
    required this.autoridadConsumidor,
    required this.leyFirma,
    required this.leyTrabajo,
    this.notas = const [],
  });

  /// "Bs 12.50", "$12.50", "S/ 12.50" o "$12.500" (monedas sin centavos).
  String formatear(double valor) {
    final negativo = valor < 0;
    final absoluto = negativo ? -valor : valor;
    var numero = absoluto.toStringAsFixed(decimales);
    if (decimales == 0) numero = _agrupar(numero);
    final pegado = simbolo.endsWith(r'$');
    return '${negativo ? '-' : ''}$simbolo${pegado ? '' : ' '}$numero';
  }

  /// Agrupa los miles con punto: 12500 → 12.500.
  static String _agrupar(String entero) {
    final b = StringBuffer();
    for (var i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) b.write('.');
      b.write(entero[i]);
    }
    return b.toString();
  }

  /// "Bs 200", "$20" o "50 ctvs" para contar la caja.
  String etiquetaDenominacion(double d) {
    if (d >= 1) return formatear(d).replaceAll(RegExp(r'[.,]00$'), '');
    return '${(d * 100).round()} ctvs';
  }

  /// Nombre de la ley o autoridad sin el artículo inicial, para títulos.
  static String sinArticulo(String texto) => texto.replaceFirst(RegExp(r'^(el|la|los|las) '), '');
}

class Paises {
  Paises._();

  static const bolivia = Pais(
    codigo: 'BO',
    nombre: 'Bolivia',
    moneda: 'BOB',
    nombreMoneda: 'bolivianos',
    simbolo: 'Bs',
    denominaciones: [200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.2, 0.1],
    idFiscal: 'NIT',
    idFactura: 'NIT o CI',
    docIdentidad: 'carnet de identidad',
    latitud: -17.3935,
    longitud: -66.1570,
    leyDatos: 'la Constitución Política del Estado (arts. 21 y 130) y el Reglamento de la Ley 164 (DS 1793)',
    leyConsumidor: 'la Ley 453 General de los Derechos de las Usuarias y los Usuarios y de las Consumidoras y los Consumidores',
    autoridadConsumidor: 'el Viceministerio de Defensa de los Derechos del Usuario y del Consumidor',
    leyFirma: 'la Ley 164 General de Telecomunicaciones, Tecnologías de Información y Comunicación',
    leyTrabajo: 'la Ley General del Trabajo',
    notas: [
      'El menú muestra el mensaje de alimentación saludable que pide la Ley 775.',
    ],
  );

  static const mexico = Pais(
    codigo: 'MX',
    nombre: 'México',
    moneda: 'MXN',
    nombreMoneda: 'pesos mexicanos',
    simbolo: r'$',
    denominaciones: [1000, 500, 200, 100, 50, 20, 10, 5, 2, 1, 0.5],
    idFiscal: 'RFC',
    idFactura: 'RFC',
    docIdentidad: 'CURP',
    latitud: 19.4326,
    longitud: -99.1332,
    leyDatos: 'la Ley Federal de Protección de Datos Personales en Posesión de los Particulares',
    autoridadDatos: 'la Secretaría Anticorrupción y Buen Gobierno',
    leyConsumidor: 'la Ley Federal de Protección al Consumidor',
    autoridadConsumidor: 'la Procuraduría Federal del Consumidor (PROFECO)',
    leyFirma: 'el Código de Comercio (mensajes de datos y firma electrónica)',
    leyTrabajo: 'la Ley Federal del Trabajo',
    notas: [
      'Puedes ejercer tus derechos ARCO (acceso, rectificación, cancelación y oposición) escribiendo al correo de privacidad.',
      'Esta política es el aviso de privacidad integral que pide la ley.',
    ],
  );

  static const estadosUnidos = Pais(
    codigo: 'US',
    nombre: 'Estados Unidos',
    moneda: 'USD',
    nombreMoneda: 'dólares estadounidenses',
    simbolo: r'$',
    denominaciones: [100, 50, 20, 10, 5, 1, 0.25, 0.1, 0.05, 0.01],
    idFiscal: 'EIN',
    idFactura: '',
    impuestosIncluidos: false,
    latitud: 38.9072,
    longitud: -77.0369,
    leyDatos: 'las leyes de privacidad de tu estado (por ejemplo, la CCPA/CPRA de California) y la ley '
        'COPPA de protección de la privacidad de los niños en línea',
    autoridadDatos: 'la Comisión Federal de Comercio (FTC) o la autoridad de tu estado',
    leyConsumidor: 'la Ley de la Comisión Federal de Comercio y las leyes de protección al consumidor de tu estado',
    autoridadConsumidor: 'la FTC o la oficina del Fiscal General (Attorney General) de tu estado',
    leyFirma: 'la ley federal E-SIGN y la ley UETA de tu estado',
    leyTrabajo: 'las leyes laborales federales y de tu estado',
    notas: [
      'No vendemos ni compartimos tus datos personales para publicidad. Si vives en California, '
          'puedes pedir saber, corregir o borrar tus datos (CCPA/CPRA).',
      'La app no está dirigida a menores de 13 años (COPPA).',
      'Los impuestos de venta se suman al cobrar, según tu estado y ciudad.',
    ],
  );

  static const canada = Pais(
    codigo: 'CA',
    nombre: 'Canadá',
    moneda: 'CAD',
    nombreMoneda: 'dólares canadienses',
    simbolo: r'$',
    denominaciones: [100, 50, 20, 10, 5, 2, 1, 0.25, 0.1, 0.05],
    idFiscal: 'BN (Business Number)',
    idFactura: '',
    impuestosIncluidos: false,
    latitud: 45.4215,
    longitud: -75.6972,
    leyDatos: 'la Ley de Protección de la Información Personal y los Documentos Electrónicos (PIPEDA) y, '
        'en Quebec, la Ley 25',
    autoridadDatos: 'la Oficina del Comisionado de Privacidad de Canadá (en Quebec, la Commission d’accès à l’information)',
    leyConsumidor: 'la Ley de Competencia y las leyes de protección al consumidor de tu provincia',
    autoridadConsumidor: 'la oficina de protección al consumidor de tu provincia',
    leyFirma: 'PIPEDA (parte 2) y las leyes de comercio electrónico de tu provincia',
    leyTrabajo: 'las normas laborales de tu provincia',
    notas: [
      'El precio que ves incluye todos los cargos obligatorios del restaurante; los impuestos se suman al cobrar.',
      'En Quebec, la app y sus textos están disponibles en francés.',
    ],
  );

  static const peru = Pais(
    codigo: 'PE',
    nombre: 'Perú',
    moneda: 'PEN',
    nombreMoneda: 'soles',
    simbolo: 'S/',
    denominaciones: [200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.2, 0.1],
    idFiscal: 'RUC',
    idFactura: 'RUC o DNI',
    docIdentidad: 'DNI',
    latitud: -12.0464,
    longitud: -77.0428,
    leyDatos: 'la Ley 29733 de Protección de Datos Personales y su Reglamento',
    autoridadDatos: 'la Autoridad Nacional de Protección de Datos Personales (Ministerio de Justicia y Derechos Humanos)',
    leyConsumidor: 'el Código de Protección y Defensa del Consumidor (Ley 29571)',
    autoridadConsumidor: 'el INDECOPI',
    leyFirma: 'la Ley 27269 de Firmas y Certificados Digitales',
    leyTrabajo: 'la legislación laboral peruana',
    notas: [
      'El restaurante debe tener a tu disposición un Libro de Reclamaciones, también en versión virtual.',
    ],
  );

  static const argentina = Pais(
    codigo: 'AR',
    nombre: 'Argentina',
    moneda: 'ARS',
    nombreMoneda: 'pesos argentinos',
    simbolo: r'$',
    decimales: 0,
    denominaciones: [20000, 10000, 2000, 1000, 500, 200, 100],
    idFiscal: 'CUIT',
    idFactura: 'CUIT o DNI',
    docIdentidad: 'DNI',
    latitud: -34.6037,
    longitud: -58.3816,
    leyDatos: 'la Ley 25.326 de Protección de los Datos Personales',
    autoridadDatos: 'la Agencia de Acceso a la Información Pública (AAIP)',
    leyConsumidor: 'la Ley 24.240 de Defensa del Consumidor',
    autoridadConsumidor: 'Defensa del Consumidor (nacional o de tu provincia)',
    leyFirma: 'la Ley 25.506 de Firma Digital',
    leyTrabajo: 'la Ley de Contrato de Trabajo',
  );

  static const chile = Pais(
    codigo: 'CL',
    nombre: 'Chile',
    moneda: 'CLP',
    nombreMoneda: 'pesos chilenos',
    simbolo: r'$',
    decimales: 0,
    denominaciones: [20000, 10000, 5000, 2000, 1000, 500, 100, 50, 10],
    idFiscal: 'RUT',
    idFactura: 'RUT',
    docIdentidad: 'RUT',
    latitud: -33.4489,
    longitud: -70.6693,
    leyDatos: 'la Ley 19.628 sobre protección de la vida privada (y la Ley 21.719, desde que entre en vigencia)',
    leyConsumidor: 'la Ley 19.496 sobre protección de los derechos de los consumidores',
    autoridadConsumidor: 'el Servicio Nacional del Consumidor (SERNAC)',
    leyFirma: 'la Ley 19.799 sobre documentos electrónicos y firma electrónica',
    leyTrabajo: 'el Código del Trabajo',
  );

  static const colombia = Pais(
    codigo: 'CO',
    nombre: 'Colombia',
    moneda: 'COP',
    nombreMoneda: 'pesos colombianos',
    simbolo: r'$',
    decimales: 0,
    denominaciones: [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100, 50],
    idFiscal: 'NIT',
    idFactura: 'NIT o cédula',
    docIdentidad: 'cédula',
    latitud: 4.7110,
    longitud: -74.0721,
    leyDatos: 'la Ley 1581 de 2012 de Protección de Datos Personales',
    autoridadDatos: 'la Superintendencia de Industria y Comercio (SIC)',
    leyConsumidor: 'el Estatuto del Consumidor (Ley 1480 de 2011)',
    autoridadConsumidor: 'la Superintendencia de Industria y Comercio (SIC)',
    leyFirma: 'la Ley 527 de 1999 de comercio electrónico',
    leyTrabajo: 'el Código Sustantivo del Trabajo',
  );

  static const ecuador = Pais(
    codigo: 'EC',
    nombre: 'Ecuador',
    moneda: 'USD',
    nombreMoneda: 'dólares',
    simbolo: r'$',
    denominaciones: [100, 50, 20, 10, 5, 1, 0.5, 0.25, 0.1, 0.05, 0.01],
    idFiscal: 'RUC',
    idFactura: 'RUC o cédula',
    docIdentidad: 'cédula',
    latitud: -0.1807,
    longitud: -78.4678,
    leyDatos: 'la Ley Orgánica de Protección de Datos Personales',
    autoridadDatos: 'la Superintendencia de Protección de Datos Personales',
    leyConsumidor: 'la Ley Orgánica de Defensa del Consumidor',
    autoridadConsumidor: 'la Defensoría del Pueblo',
    leyFirma: 'la Ley de Comercio Electrónico, Firmas Electrónicas y Mensajes de Datos',
    leyTrabajo: 'el Código del Trabajo',
  );

  static const brasil = Pais(
    codigo: 'BR',
    nombre: 'Brasil',
    moneda: 'BRL',
    nombreMoneda: 'reales',
    simbolo: r'R$',
    denominaciones: [200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.25, 0.1, 0.05],
    idFiscal: 'CNPJ',
    idFactura: 'CPF o CNPJ',
    docIdentidad: 'CPF',
    latitud: -15.7939,
    longitud: -47.8828,
    leyDatos: 'la Ley General de Protección de Datos (LGPD, Ley 13.709/2018)',
    autoridadDatos: 'la Autoridad Nacional de Protección de Datos (ANPD)',
    leyConsumidor: 'el Código de Defensa del Consumidor (Ley 8.078/1990)',
    autoridadConsumidor: 'el Procon de tu estado',
    leyFirma: 'la Medida Provisoria 2.200-2/2001 y la Ley 14.063/2020',
    leyTrabajo: 'la Consolidación de las Leyes del Trabajo (CLT)',
  );

  static const uruguay = Pais(
    codigo: 'UY',
    nombre: 'Uruguay',
    moneda: 'UYU',
    nombreMoneda: 'pesos uruguayos',
    simbolo: r'$',
    denominaciones: [2000, 1000, 500, 200, 100, 50, 20, 10, 5, 2, 1],
    idFiscal: 'RUT',
    idFactura: 'RUT o CI',
    docIdentidad: 'cédula de identidad',
    latitud: -34.9011,
    longitud: -56.1645,
    leyDatos: 'la Ley 18.331 de Protección de Datos Personales',
    autoridadDatos: 'la Unidad Reguladora y de Control de Datos Personales (URCDP)',
    leyConsumidor: 'la Ley 17.250 de Relaciones de Consumo',
    autoridadConsumidor: 'el Área de Defensa del Consumidor',
    leyFirma: 'la Ley 18.600 de documento y firma electrónica',
    leyTrabajo: 'la legislación laboral uruguaya',
  );

  static const paraguay = Pais(
    codigo: 'PY',
    nombre: 'Paraguay',
    moneda: 'PYG',
    nombreMoneda: 'guaraníes',
    simbolo: '₲',
    decimales: 0,
    denominaciones: [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 100, 50],
    idFiscal: 'RUC',
    idFactura: 'RUC o CI',
    docIdentidad: 'cédula de identidad',
    latitud: -25.2637,
    longitud: -57.5759,
    leyDatos: 'la Ley 7593/2025 de Protección de Datos Personales',
    leyConsumidor: 'la Ley 1334/98 de Defensa del Consumidor y del Usuario',
    autoridadConsumidor: 'la Secretaría de Defensa del Consumidor y el Usuario (SEDECO)',
    leyFirma: 'la Ley 4017/2010 de firma electrónica y documentos electrónicos',
    leyTrabajo: 'el Código del Trabajo',
  );

  static const costaRica = Pais(
    codigo: 'CR',
    nombre: 'Costa Rica',
    moneda: 'CRC',
    nombreMoneda: 'colones',
    simbolo: '₡',
    decimales: 0,
    denominaciones: [20000, 10000, 5000, 2000, 1000, 500, 100, 50, 25, 10, 5],
    idFiscal: 'Cédula jurídica',
    idFactura: 'Cédula',
    docIdentidad: 'cédula',
    latitud: 9.9281,
    longitud: -84.0907,
    leyDatos: 'la Ley 8968 de Protección de la Persona frente al Tratamiento de sus Datos Personales',
    autoridadDatos: 'la Agencia de Protección de Datos de los Habitantes (PRODHAB)',
    leyConsumidor: 'la Ley 7472 de Promoción de la Competencia y Defensa Efectiva del Consumidor',
    autoridadConsumidor: 'el Ministerio de Economía, Industria y Comercio (MEIC)',
    leyFirma: 'la Ley 8454 de Certificados, Firmas Digitales y Documentos Electrónicos',
    leyTrabajo: 'el Código de Trabajo',
  );

  static const panama = Pais(
    codigo: 'PA',
    nombre: 'Panamá',
    moneda: 'USD',
    nombreMoneda: 'dólares (balboas)',
    simbolo: r'$',
    denominaciones: [100, 50, 20, 10, 5, 1, 0.5, 0.25, 0.1, 0.05, 0.01],
    idFiscal: 'RUC',
    idFactura: 'RUC o cédula',
    docIdentidad: 'cédula',
    latitud: 8.9824,
    longitud: -79.5199,
    leyDatos: 'la Ley 81 de 2019 de Protección de Datos Personales',
    autoridadDatos: 'la Autoridad Nacional de Transparencia y Acceso a la Información (ANTAI)',
    leyConsumidor: 'la Ley 45 de 2007 de protección al consumidor',
    autoridadConsumidor: 'la Autoridad de Protección al Consumidor y Defensa de la Competencia (ACODECO)',
    leyFirma: 'la Ley 51 de 2008 de documentos y firmas electrónicas',
    leyTrabajo: 'el Código de Trabajo',
  );

  static const republicaDominicana = Pais(
    codigo: 'DO',
    nombre: 'República Dominicana',
    moneda: 'DOP',
    nombreMoneda: 'pesos dominicanos',
    simbolo: r'RD$',
    denominaciones: [2000, 1000, 500, 200, 100, 50, 25, 10, 5, 1],
    idFiscal: 'RNC',
    idFactura: 'RNC o cédula',
    docIdentidad: 'cédula',
    latitud: 18.4861,
    longitud: -69.9312,
    leyDatos: 'la Ley 172-13 de protección de datos personales',
    leyConsumidor: 'la Ley 358-05 de Protección de los Derechos del Consumidor',
    autoridadConsumidor: 'Pro Consumidor',
    leyFirma: 'la Ley 126-02 de Comercio Electrónico, Documentos y Firmas Digitales',
    leyTrabajo: 'el Código de Trabajo',
  );

  static const guatemala = Pais(
    codigo: 'GT',
    nombre: 'Guatemala',
    moneda: 'GTQ',
    nombreMoneda: 'quetzales',
    simbolo: 'Q',
    denominaciones: [200, 100, 50, 20, 10, 5, 1, 0.5, 0.25, 0.1, 0.05],
    idFiscal: 'NIT',
    idFactura: 'NIT',
    docIdentidad: 'DPI',
    latitud: 14.6349,
    longitud: -90.5069,
    leyDatos: 'la Constitución y las leyes de Guatemala sobre la privacidad de las personas',
    leyConsumidor: 'la Ley de Protección al Consumidor y Usuario',
    autoridadConsumidor: 'la Dirección de Atención y Asistencia al Consumidor (DIACO)',
    leyFirma: 'la Ley para el Reconocimiento de las Comunicaciones y Firmas Electrónicas',
    leyTrabajo: 'el Código de Trabajo',
  );

  static const nicaragua = Pais(
    codigo: 'NI',
    nombre: 'Nicaragua',
    moneda: 'NIO',
    nombreMoneda: 'córdobas',
    simbolo: r'C$',
    denominaciones: [1000, 500, 200, 100, 50, 20, 10, 5, 1, 0.5, 0.25, 0.1],
    idFiscal: 'RUC',
    idFactura: 'RUC o cédula',
    docIdentidad: 'cédula',
    latitud: 12.1150,
    longitud: -86.2362,
    leyDatos: 'la Ley 787 de Protección de Datos Personales',
    leyConsumidor: 'la Ley 842 de Protección de los Derechos de las Personas Consumidoras y Usuarias',
    autoridadConsumidor: 'la autoridad de protección al consumidor de Nicaragua',
    leyFirma: 'la Ley 729 de Firma Electrónica',
    leyTrabajo: 'el Código del Trabajo',
  );

  static const elSalvador = Pais(
    codigo: 'SV',
    nombre: 'El Salvador',
    moneda: 'USD',
    nombreMoneda: 'dólares',
    simbolo: r'$',
    denominaciones: [100, 50, 20, 10, 5, 1, 0.25, 0.1, 0.05, 0.01],
    idFiscal: 'NIT',
    idFactura: 'NIT o DUI',
    docIdentidad: 'DUI',
    latitud: 13.6929,
    longitud: -89.2182,
    leyDatos: 'las leyes de protección de datos personales de El Salvador',
    leyConsumidor: 'la Ley de Protección al Consumidor',
    autoridadConsumidor: 'la Defensoría del Consumidor',
    leyFirma: 'la Ley de Firma Electrónica',
    leyTrabajo: 'el Código de Trabajo',
  );

  static const honduras = Pais(
    codigo: 'HN',
    nombre: 'Honduras',
    moneda: 'HNL',
    nombreMoneda: 'lempiras',
    simbolo: 'L',
    denominaciones: [500, 200, 100, 50, 20, 10, 5, 2, 1, 0.5, 0.2, 0.1],
    idFiscal: 'RTN',
    idFactura: 'RTN',
    docIdentidad: 'DNI',
    latitud: 14.0723,
    longitud: -87.1921,
    leyDatos: 'las leyes de Honduras sobre la privacidad de las personas',
    leyConsumidor: 'la Ley de Protección al Consumidor',
    autoridadConsumidor: 'la Dirección General de Protección al Consumidor',
    leyFirma: 'la Ley sobre Firmas Electrónicas',
    leyTrabajo: 'el Código del Trabajo',
  );

  /// Países disponibles, con Bolivia primero (donde empezó la app).
  static const todos = <Pais>[
    bolivia,
    argentina,
    brasil,
    canada,
    chile,
    colombia,
    costaRica,
    ecuador,
    elSalvador,
    estadosUnidos,
    guatemala,
    honduras,
    mexico,
    nicaragua,
    panama,
    paraguay,
    peru,
    republicaDominicana,
    uruguay,
  ];

  /// País por su código; si no se conoce, Bolivia.
  static Pais porCodigo(String? codigo) {
    final c = (codigo ?? '').trim().toUpperCase();
    for (final p in todos) {
      if (p.codigo == c) return p;
    }
    return bolivia;
  }

  /// País del restaurante que está abierto (se actualiza al cargar el
  /// restaurante). Por defecto, Bolivia.
  static Pais actual = bolivia;
}
