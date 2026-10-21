/// Representa UN documento de la colección raíz `negocios`.
/// Desde la corrección pedida por el docente (multi-tenant real), pueden
/// existir VARIOS negocios: el SuperAdmin los crea y personaliza todos, y
/// cada Administrador queda asignado a uno solo (ver `idNegocio` en
/// `UsuarioModel`) para gestionar su operación diaria.
///
/// Fase 5 (HU-10, personalización): se agregaron 3 campos nuevos —
/// `colorFondo`, `bannerUrl` y `modoOscuro` — para cubrir lo que pide el
/// mockup de Susan (Fondo, Imagen principal/Banner, Modo claro/oscuro).
/// Son aditivos y con default seguro: un documento viejo que no los tenga
/// sigue funcionando exactamente igual que antes.
class NegocioModel {
  final String idNegocio;
  final String nombre;
  final String logoUrl;
  final String bannerUrl;
  final String descripcion;
  final String telefono;
  final String colorPrimario; // hex, ej. "#E65100"
  final String colorSecundario; // hex, ej. "#FFF3E0"
  final String colorFondo; // hex, o '' = usar el fondo por defecto del tema
  final bool modoOscuro;
  final bool estado;
  // Sprint 2 (HU-24/25/26/27): imagen del QR de pago del negocio (ej. QR
  // del banco), para que el cliente la vea y escanee al elegir "QR" como
  // método de pago en el checkout, antes de subir su comprobante. '' =
  // todavía no lo configuró el Administrador.
  final String qrPagoUrl;

  // Datos de identificación y contacto que el Administrador completa y que
  // el cliente ve en la ficha del negocio (razón social, NIT, dirección,
  // correo para reclamos). Opcionales: '' = no completado.
  final String razonSocial;
  final String nit;
  final String direccion;
  final String ciudad;
  final String correoContacto;
  // Personalización de estilo (SuperAdmin). Todos con default seguro: un
  // negocio viejo sin estos campos se ve "moderno / sans / redondeado".
  /// Preset base: moderno, minimal, premium, natural, vibrante, industrial.
  final String estiloBase;

  /// Tipografía: sans, slab, serif, gruesa, redondeada, condensada.
  final String tipografia;

  /// Forma de botones y tarjetas: cuadrado, redondeado, pildora.
  final String formaBotones;

  const NegocioModel({
    required this.idNegocio,
    required this.nombre,
    this.logoUrl = '',
    this.bannerUrl = '',
    this.descripcion = '',
    this.telefono = '',
    this.colorPrimario = '#FF7A00',
    this.colorSecundario = '#FFF3E0',
    this.colorFondo = '',
    this.modoOscuro = false,
    this.estado = true,
    this.qrPagoUrl = '',
    this.razonSocial = '',
    this.nit = '',
    this.direccion = '',
    this.ciudad = '',
    this.correoContacto = '',
    this.estiloBase = 'moderno',
    this.tipografia = 'sans',
    this.formaBotones = 'redondeado',
  });

  NegocioModel copyWith({
    String? nombre,
    String? logoUrl,
    String? bannerUrl,
    String? descripcion,
    String? telefono,
    String? colorPrimario,
    String? colorSecundario,
    String? colorFondo,
    bool? modoOscuro,
    bool? estado,
    String? qrPagoUrl,
    String? razonSocial,
    String? nit,
    String? direccion,
    String? ciudad,
    String? correoContacto,
    String? estiloBase,
    String? tipografia,
    String? formaBotones,
  }) {
    return NegocioModel(
      idNegocio: idNegocio,
      nombre: nombre ?? this.nombre,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      descripcion: descripcion ?? this.descripcion,
      telefono: telefono ?? this.telefono,
      colorPrimario: colorPrimario ?? this.colorPrimario,
      colorSecundario: colorSecundario ?? this.colorSecundario,
      colorFondo: colorFondo ?? this.colorFondo,
      modoOscuro: modoOscuro ?? this.modoOscuro,
      estado: estado ?? this.estado,
      qrPagoUrl: qrPagoUrl ?? this.qrPagoUrl,
      razonSocial: razonSocial ?? this.razonSocial,
      nit: nit ?? this.nit,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      correoContacto: correoContacto ?? this.correoContacto,
      estiloBase: estiloBase ?? this.estiloBase,
      tipografia: tipografia ?? this.tipografia,
      formaBotones: formaBotones ?? this.formaBotones,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombre': nombre,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'descripcion': descripcion,
      'telefono': telefono,
      'colorPrimario': colorPrimario,
      'colorSecundario': colorSecundario,
      'colorFondo': colorFondo,
      'modoOscuro': modoOscuro,
      'estado': estado,
      'qrPagoUrl': qrPagoUrl,
      'razonSocial': razonSocial,
      'nit': nit,
      'direccion': direccion,
      'ciudad': ciudad,
      'correoContacto': correoContacto,
      'estiloBase': estiloBase,
      'tipografia': tipografia,
      'formaBotones': formaBotones,
    };
  }

  factory NegocioModel.fromMap(String idNegocio, Map<String, dynamic> data) {
    return NegocioModel(
      idNegocio: idNegocio,
      nombre: (data['nombre'] ?? '') as String,
      logoUrl: (data['logoUrl'] ?? '') as String,
      bannerUrl: (data['bannerUrl'] ?? '') as String,
      descripcion: (data['descripcion'] ?? '') as String,
      telefono: (data['telefono'] ?? '') as String,
      colorPrimario: (data['colorPrimario'] ?? '#FF7A00') as String,
      colorSecundario: (data['colorSecundario'] ?? '#FFF3E0') as String,
      colorFondo: (data['colorFondo'] ?? '') as String,
      modoOscuro: (data['modoOscuro'] ?? false) as bool,
      estado: (data['estado'] ?? true) as bool,
      qrPagoUrl: (data['qrPagoUrl'] ?? '') as String,
      razonSocial: (data['razonSocial'] ?? '') as String,
      nit: (data['nit'] ?? '') as String,
      direccion: (data['direccion'] ?? '') as String,
      ciudad: (data['ciudad'] ?? '') as String,
      correoContacto: (data['correoContacto'] ?? '') as String,
      estiloBase: (data['estiloBase'] ?? 'moderno') as String,
      tipografia: (data['tipografia'] ?? 'sans') as String,
      formaBotones: (data['formaBotones'] ?? 'redondeado') as String,
    );
  }
}
