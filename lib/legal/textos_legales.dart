import '../config/app_config.dart';
import '../models/negocio_model.dart';
import '../models/pais.dart';
import '../models/usuario_model.dart';

/// Un apartado de un texto legal: título, uno o más párrafos y, arriba,
/// una línea "En simple" con lo esencial en palabras de todos los días.
class SeccionLegal {
  final String titulo;
  final List<String> parrafos;
  final String? enSimple;
  const SeccionLegal(this.titulo, this.parrafos, {this.enSimple});
}

/// Textos legales de la plataforma. Son una base redactada a partir de lo
/// que la app realmente hace; NO sustituyen la revisión de un abogado del
/// país donde opera cada restaurante. Las leyes, la moneda y las
/// autoridades se toman del país del restaurante (ver `Pais`). Si cambia el funcionamiento de la app (por ejemplo, se agrega
/// la ubicación del repartidor), hay que actualizar este archivo y subir
/// `AppConfig.versionTerminos`.
///
/// Los documentos están redactados en forma formal, en tercera persona y
/// por cláusulas (PRIMERA.-, SEGUNDA.-…), para poder imprimirlos y firmarlos:
/// "EL TITULAR", "LA PLATAFORMA", "EL USUARIO", "EL RESTAURANTE" y "EL
/// CLIENTE". Cada cláusula tiene su "En simple" para leerla en la pantalla;
/// la versión impresa va sin esas ayudas.
class TextosLegales {
  TextosLegales._();

  static const String tituloPolitica = 'Política de privacidad';
  static const String tituloTerminos = 'Términos y condiciones';
  static const String tituloAcuerdo = 'Acuerdo de uso y confidencialidad del personal';
  static String tituloCondiciones(NegocioModel n) => 'Condiciones de ${n.nombre}';

  // ------------------------------------------------------------ resúmenes

  static List<String> resumenPrivacidad() => const [
        'Guardamos solo lo necesario para atender tus pedidos.',
        'Tu restaurante ve tu nombre, tu teléfono y, si pides delivery, tu dirección.',
        'No vendemos tus datos ni los usamos para publicidad.',
        'Puedes ver, corregir o borrar tus datos cuando quieras.',
        'Si algo cambia, te pedimos aceptar de nuevo.',
      ];

  static List<String> resumenTerminos() => [
        'La plataforma es la herramienta; el restaurante prepara y entrega tu pedido.',
        'Antes de confirmar ves el total exacto: no hay cobros escondidos.',
        'Le pagas directamente al restaurante.',
        'Marca tus alergias; si son graves, confirma con el local.',
        'Si tienes un problema, reclama primero al restaurante; si no se resuelve, a '
            '${Paises.actual.autoridadConsumidor}.',
      ];

  /// Política de privacidad, redactada en forma de documento formal (tercera
  /// persona y cláusulas PRIMERA.-, SEGUNDA.-…), lista para imprimir y
  /// firmar. Cada cláusula conserva su "En simple" para la pantalla.
  static List<SeccionLegal> politicaPrivacidad() {
    final p = Paises.actual;
    final plataforma = AppConfig.nombrePlataforma;
    return _numerarClausulas([
      SeccionLegal('PARTES Y RESPONSABLE DEL TRATAMIENTO',
          enSimple: 'La plataforma es la herramienta; el restaurante atiende tu pedido. Si tienes dudas sobre tus datos, escríbenos.', [
        'La presente Política de Privacidad regula el tratamiento de los datos personales en la '
            'plataforma $plataforma, en adelante "LA PLATAFORMA", ofrecida por '
            '${AppConfig.titularPlataforma}, con domicilio en ${AppConfig.ciudadPais}, en adelante '
            '"EL TITULAR", que actúa como responsable del tratamiento.',
        'Se denomina "EL USUARIO" a toda persona que crea una cuenta en LA PLATAFORMA, sea como '
            'cliente o como personal de un negocio, y "EL RESTAURANTE" a cada negocio que recibe y '
            'gestiona pedidos por medio de LA PLATAFORMA. Cada restaurante aparece identificado en '
            'su ficha y es quien atiende los pedidos que se le hacen.',
        'Las consultas y solicitudes sobre datos personales se dirigen a EL TITULAR al correo '
            '${AppConfig.correoPrivacidad}.',
        'La presente política se ajusta a lo que exige ${p.leyDatos}, en ${p.nombre}: obtener el '
            'consentimiento de EL USUARIO, informarle la finalidad del tratamiento y respetar sus '
            'derechos sobre sus datos.',
      ]),
      SeccionLegal('DATOS QUE SE RECOPILAN',
          enSimple: 'Guardamos solo lo necesario para atender tus pedidos: tus datos de contacto, tus direcciones y tus pedidos.', [
        'LA PLATAFORMA recopila únicamente los siguientes datos:',
        'a) Datos de la cuenta: nombre, correo electrónico y teléfono. La contraseña la gestiona el '
            'servicio de autenticación de Google Firebase; EL TITULAR no tiene acceso a ella.',
        'b) Datos de entrega: las direcciones que EL USUARIO guarde en su cuenta. Si elige '
            'delivery, su nombre y teléfono se guardan junto al pedido para que el repartidor pueda '
            'contactarlo.',
        'c) Ubicación: el punto que EL USUARIO marque en el mapa al guardar una dirección de '
            'entrega. Si utiliza la opción "Mi ubicación", el dispositivo le solicita permiso y la '
            'ubicación se usa solo para colocar ese punto; no se guarda de forma continua.',
        'd) Ubicación del repartidor: mientras un pedido de delivery va en camino, el repartidor '
            'comparte su posición con LA PLATAFORMA y el cliente la ve en un mapa. Esa posición se '
            'borra cuando el pedido se entrega.',
        'e) Reseñas: si EL USUARIO califica un pedido, se publican su nombre corto (por ejemplo, '
            '"Ana P."), las estrellas y su comentario. Las reseñas visibles las ven los demás '
            'clientes del negocio y, además, las mejor calificadas pueden mostrarse a cualquier '
            'persona en la pantalla de inicio de sesión de LA PLATAFORMA, antes de entrar, sin '
            'indicar el correo, el teléfono ni el pedido. EL USUARIO puede borrar su reseña cuando '
            'lo desee.',
        'f) Datos de los pedidos: productos, total, forma de pago, notas y estado, y el '
            'comprobante de pago si EL USUARIO lo sube.',
        'g) Imágenes: foto de perfil y comprobantes de pago que EL USUARIO suba.',
        'h) Alergias: si EL USUARIO las marca en su cuenta o en un pedido, se guardan en su cuenta '
            'y en el pedido para que la cocina las vea. Por tratarse de un dato de salud, se usan '
            'únicamente para preparar el pedido con seguridad, y EL USUARIO puede quitarlas en '
            'cualquier momento en "Mi cuenta".',
        'i) Datos para factura: si EL USUARIO pide factura, su número tributario o documento y la '
            'razón social se guardan en el pedido para el negocio y, para no volver a escribirlos, '
            'en su dispositivo.',
        'j) Preferencias: idioma, tamaño de letra, avisos y si ya vio el aviso de almacenamiento; '
            'se guardan solo en el dispositivo de EL USUARIO (cláusula de cookies y almacenamiento).',
        'k) Copia para usar sin internet: en la aplicación del celular se guarda en el teléfono '
            'una copia de los datos ya cargados, para que LA PLATAFORMA funcione si se corta la '
            'conexión. En la versión web no se guarda ninguna copia en el navegador.',
        'l) Informes de fallas: si LA PLATAFORMA tiene una falla inesperada, se guarda un informe '
            'técnico (mensaje de error, versión, tipo de dispositivo, rol e identificador de '
            'usuario, sin nombre ni pedidos) para corregirla. Estos informes se borran '
            'periódicamente.',
        'Los datos no se utilizan para publicidad de terceros.',
      ]),
      const SeccionLegal('FINALIDAD DEL TRATAMIENTO',
          enSimple: 'Usamos tus datos para atender tus pedidos y nada más.', [
        'Los datos se tratan exclusivamente para crear y mantener la cuenta de EL USUARIO, '
            'procesar y entregar sus pedidos, permitir que el negocio lo contacte sobre un pedido, '
            'atender reclamos, prevenir abusos (por ejemplo, el bloqueo de cuentas por parte de un '
            'negocio, siempre con un motivo registrado) y cumplir obligaciones legales.',
      ]),
      SeccionLegal('DESTINATARIOS DE LOS DATOS',
          enSimple: 'Tu restaurante ve lo necesario para tu pedido. No vendemos tus datos ni los usamos para publicidad.', [
        'Los datos de EL USUARIO se comunican únicamente a:',
        'a) Otros clientes del negocio y visitantes de la pantalla de inicio de sesión: las '
            'reseñas visibles, en los términos del inciso e) de la cláusula anterior. El negocio '
            'puede ocultar reseñas ofensivas y bloquear, con un motivo, las cuentas que las escriban.',
        'b) EL RESTAURANTE al que EL USUARIO hace un pedido: ve su nombre, su teléfono, el '
            'contenido del pedido y, si elige delivery, la dirección de entrega. Si es delivery, el '
            'repartidor que toma el pedido ve el nombre, teléfono y dirección para entregarlo, y '
            'el cliente ve el nombre y teléfono del repartidor mientras el pedido va en camino. Los '
            'datos no se comparten con los demás negocios de LA PLATAFORMA.',
        'c) Proveedores técnicos que guardan o procesan la información por cuenta de EL TITULAR '
            '(servicios de terceros):',
        '• Google Firebase (Google LLC): cuentas, base de datos, verificación de que la '
            'aplicación es auténtica (App Check) y alojamiento de la web.',
        '• Cloudinary: almacenamiento de imágenes (fotos de productos, de perfil y comprobantes).',
        '• OpenStreetMap y su buscador Nominatim: muestran el mapa y buscan direcciones; reciben '
            'el texto de la dirección buscada y la dirección IP.',
        '• MyMemory (Translated): traduce notas cuando LA PLATAFORMA se usa en otro idioma.',
        '• Google Fonts: algunas tipografías de los restaurantes se descargan de los servidores '
            'de Google, que reciben la dirección IP.',
        'Estos proveedores pueden tener sus servidores fuera del país de EL USUARIO (por ejemplo, '
            'en Estados Unidos o Europa). Al aceptar la presente política, EL USUARIO consiente que '
            'sus datos se guarden allí, con las medidas de seguridad de dichos proveedores.',
        'Traducción: si EL USUARIO usa LA PLATAFORMA en otro idioma, el texto de sus notas y de la '
            'referencia de su dirección se envía al servicio de traducción automática MyMemory '
            'para que el personal lo lea en español. Se recomienda no incluir datos sensibles en '
            'las notas; las alergias se indican con la lista de LA PLATAFORMA, que no pasa por ese '
            'servicio.',
        'EL TITULAR no vende los datos de EL USUARIO.',
      ]),
      SeccionLegal('PLAZO DE CONSERVACIÓN',
          enSimple: 'Mientras tengas tu cuenta. Si la eliminas, borramos tu perfil; los pedidos quedan sin tu nombre.', [
        'Los datos se conservan mientras la cuenta de EL USUARIO esté activa. Si EL USUARIO elimina '
            'su cuenta desde "Mi cuenta", se borran su perfil, sus direcciones, sus favoritos, sus '
            'reseñas y su carrito.',
        'Los registros de pedidos pasados se conservan sin el identificador ni la dirección de EL '
            'USUARIO, porque el negocio los necesita para su contabilidad y para atender reclamos. '
            'Pueden conservarse el comprobante de pago subido y el nombre que figure en él.',
        'Las imágenes guardadas en Cloudinary (foto de perfil y comprobantes) no se pueden borrar '
            'desde la aplicación; EL USUARIO puede solicitar su eliminación a '
            '${AppConfig.correoPrivacidad}.',
      ]),
      SeccionLegal('DERECHOS DEL USUARIO',
          enSimple: 'Puedes ver, corregir o borrar tus datos cuando quieras.', [
        'En ${p.nombre}, ${p.leyDatos} reconoce el derecho a la privacidad y a conocer, corregir y '
            'eliminar los datos personales.',
        'EL USUARIO tiene derecho a: conocer qué datos suyos se tratan (acceso), corregirlos '
            '(rectificación), solicitar su eliminación (cancelación), oponerse a un uso concreto '
            '(oposición) y retirar su consentimiento en cualquier momento. El retiro no afecta el '
            'tratamiento realizado antes con su autorización.',
        'EL USUARIO puede ver y corregir su nombre y teléfono en "Mi cuenta", y eliminar su cuenta '
            'en "Mi cuenta > Eliminar mi cuenta". Cualquier otra solicitud se dirige a '
            '${AppConfig.correoPrivacidad} y se responde en un plazo máximo de diez (10) días hábiles.',
        if (p.codigo == 'BO')
          'Si EL USUARIO considera que sus datos se usan de forma indebida, puede además interponer '
              'una Acción de Protección de Privacidad ante la autoridad judicial (Constitución '
              'Política del Estado, arts. 130 y 131).'
        else if (p.autoridadDatos.isNotEmpty)
          'Si EL USUARIO considera que sus datos se usan de forma indebida, puede además presentar '
              'una queja ante ${p.autoridadDatos}.',
        ...p.notas.where((n) => !n.contains('menú') && !n.contains('impuestos')),
      ]),
      const SeccionLegal('SEGURIDAD', enSimple: 'Cada persona ve solo lo que le corresponde.', [
        'Los datos se guardan en servicios de Google Firebase con reglas de acceso por rol: cada '
            'usuario ve sus propios datos y el personal de un negocio solo ve los pedidos de ese '
            'negocio. Ningún sistema es infalible; por ello se recomienda a EL USUARIO utilizar una '
            'contraseña única.',
      ]),
      const SeccionLegal('MENORES DE EDAD',
          enSimple: 'Necesitas 18 años, o el permiso de tu madre, padre o tutor. Menores de 13, no.', [
        'Para crear una cuenta se requiere tener 18 años o más. Las personas menores de edad solo '
            'pueden usar LA PLATAFORMA con la autorización y supervisión de su madre, padre o '
            'tutor, quien responde por los pedidos que realicen.',
        'LA PLATAFORMA no está dirigida a menores de 13 años y no recopila a sabiendas sus datos. '
            'Si se detecta la cuenta de un menor de 13 años, será eliminada.',
      ]),
      const SeccionLegal('COOKIES Y ALMACENAMIENTO',
          enSimple: 'Solo guardamos en tu dispositivo lo necesario para que la app funcione. Nada de publicidad.', [
        'LA PLATAFORMA guarda en el navegador o en el teléfono de EL USUARIO solo lo necesario para '
            'funcionar: la sesión (para no solicitar la contraseña cada vez), el idioma, el tamaño '
            'de letra, los datos de factura si EL USUARIO decide recordarlos y si ya vio el aviso '
            'de almacenamiento.',
        'No se usan cookies de publicidad ni de seguimiento, ni herramientas de analítica de '
            'terceros; por ello no se solicita elegir cookies y solo se informa su uso.',
        'EL USUARIO puede borrar estos datos en cualquier momento desde la configuración de su '
            'navegador o cerrando sesión; LA PLATAFORMA volverá a solicitarle que ingrese.',
      ]),
      const SeccionLegal('CONSENTIMIENTO',
          enSimple: 'Al aceptar, nos autorizas a usar tus datos como dice esta política.', [
        'Al marcar la casilla de aceptación al crear su cuenta, EL USUARIO otorga su consentimiento '
            'previo, expreso e informado para el tratamiento de sus datos conforme a la presente '
            'política. Las alergias (dato de salud) solo se guardan si EL USUARIO las indica, y '
            'solo para preparar sus pedidos con seguridad.',
      ]),
      const SeccionLegal('MODIFICACIONES',
          enSimple: 'Si algo cambia, te avisamos y te pedimos aceptar de nuevo.', [
        'Si la presente política cambia, se solicitará a EL USUARIO aceptar la nueva versión antes '
            'de continuar usando LA PLATAFORMA. Versión vigente: ${AppConfig.versionTerminos}.',
      ]),
    ]);
  }

  /// Términos y condiciones de uso, en forma de documento formal (tercera
  /// persona y cláusulas), listos para imprimir y firmar.
  static List<SeccionLegal> terminos() {
    final p = Paises.actual;
    return _numerarClausulas([
      SeccionLegal('PARTES Y OBJETO',
          enSimple: 'La plataforma te conecta con el restaurante; el restaurante prepara y entrega tu pedido.', [
        'Los presentes Términos y Condiciones regulan el uso de la plataforma '
            '${AppConfig.nombrePlataforma}, en adelante "LA PLATAFORMA", ofrecida por '
            '${AppConfig.titularPlataforma}, en adelante "EL TITULAR", por parte de toda persona '
            'que crea una cuenta en ella, en adelante "EL USUARIO".',
        'LA PLATAFORMA permite hacer pedidos a negocios de comida, en adelante "EL RESTAURANTE". '
            'LA PLATAFORMA conecta al cliente con el negocio; la compra se acuerda entre el cliente '
            'y EL RESTAURANTE, que es quien prepara y entrega el pedido.',
      ]),
      const SeccionLegal('CUENTA DEL USUARIO', enSimple: 'Usa datos reales y cuida tu contraseña.', [
        'EL USUARIO se obliga a proporcionar datos verdaderos y a mantenerlos actualizados. Es '
            'responsable de custodiar su contraseña y de todo lo que se realice con su cuenta.',
        'EL USUARIO declara tener 18 años o más, o usar LA PLATAFORMA con la autorización y '
            'supervisión de su madre, padre o tutor.',
      ]),
      SeccionLegal('PRECIOS Y PEDIDOS',
          enSimple: 'El total que ves antes de confirmar es lo que pagas. Sin cobros escondidos.', [
        'Los precios se expresan en ${p.nombreMoneda} (${p.simbolo}) '
            '${p.impuestosIncluidos ? 'e incluyen los impuestos' : 'sin los impuestos de venta, que se suman al cobrar según la zona de EL USUARIO'}. '
            'Antes de confirmar, EL USUARIO ve el detalle completo: productos, descuento, costo de '
            'envío según su zona y propina. El total mostrado es el que corresponde pagar; no '
            'existen cobros ocultos, conforme a ${p.leyConsumidor}.',
        'EL RESTAURANTE puede rechazar o cancelar un pedido si no puede atenderlo; en tal caso, el '
            'motivo queda registrado y EL USUARIO lo ve en el detalle del pedido.',
        'EL USUARIO puede programar un pedido para más tarde, dentro del horario de atención del '
            'local. Los productos con cantidad limitada pueden agotarse antes de la confirmación. '
            'Si la sucursal pausó la recepción de pedidos, LA PLATAFORMA se lo informa.',
        'Los cupones de descuento los crea cada negocio, con sus propias condiciones (monto mínimo '
            'y fecha de vencimiento), que se muestran al aplicarlos. Un cupón vigente se respeta en '
            'los pedidos confirmados mientras estaba vigente.',
        'La propina para el repartidor es voluntaria, corresponde íntegramente al repartidor y no '
            'forma parte del precio de los productos.',
      ]),
      const SeccionLegal('ALERGIAS',
          enSimple: 'Marca tus alergias; el restaurante hará lo posible, pero confirma con el local si tu alergia es grave.', [
        'Si EL USUARIO indica alergias, EL RESTAURANTE las verá destacadas y hará lo posible por '
            'preparar el pedido sin esos ingredientes. La información de alérgenos de cada producto '
            'la carga el negocio. Si la alergia es grave, EL USUARIO debe confirmarlo con el local '
            'antes de consumir: LA PLATAFORMA no puede garantizar la ausencia de contacto cruzado '
            'en la cocina.',
      ]),
      const SeccionLegal('PAGOS', enSimple: 'Le pagas directamente al restaurante.', [
        'EL USUARIO puede pagar en efectivo, por transferencia o con el QR de pago del negocio, '
            'según lo que este ofrezca. El pago se realiza directamente a EL RESTAURANTE: LA '
            'PLATAFORMA no cobra ni retiene dinero.',
      ]),
      SeccionLegal('FACTURACIÓN', enSimple: 'La factura la emite el restaurante, si la pides.', [
        p.idFactura.isEmpty
            ? 'LA PLATAFORMA no emite facturas ni recibos fiscales. EL RESTAURANTE entrega el '
                'comprobante de compra que corresponda y responde por sus obligaciones tributarias.'
            : 'LA PLATAFORMA no emite facturas fiscales. Si EL USUARIO necesita factura, debe '
                'marcar "Quiero factura" al confirmar e indicar su ${p.idFactura}; esos datos llegan '
                'a EL RESTAURANTE, que es quien emite la factura y responde por sus obligaciones '
                'tributarias.',
      ]),
      SeccionLegal('USO ADECUADO', enSimple: 'Trata con respeto al personal y no hagas pedidos falsos.', [
        'Queda prohibido realizar pedidos falsos, ofender o amenazar al personal de un negocio, '
            'publicar reseñas con insultos, datos de otras personas o contenido racista o '
            'discriminatorio${p.codigo == 'BO' ? ' (Ley 045)' : ''}, y usar LA PLATAFORMA para '
            'fines ilegales.',
        'El Administrador de un negocio puede bloquear la cuenta de EL USUARIO en ese negocio solo '
            'por un incumplimiento de esta cláusula y registrando el motivo; el bloqueo no afecta a '
            'los demás negocios.',
      ]),
      const SeccionLegal('RESPONSABILIDAD',
          enSimple: 'El restaurante responde por su comida; la plataforma, por que la app funcione.', [
        'Cada negocio es responsable de la calidad, preparación y entrega de sus productos. EL '
            'TITULAR procura que LA PLATAFORMA esté disponible, pero no garantiza la ausencia de '
            'interrupciones.',
      ]),
      SeccionLegal('RECLAMOS',
          enSimple: 'Primero reclama al restaurante; si no se resuelve, puedes acudir ${_a(p.autoridadConsumidor)}.', [
        'EL USUARIO puede presentar su reclamo directamente a EL RESTAURANTE, de forma verbal o '
            'escrita y sin formalidades. Los datos de contacto de cada negocio figuran en su ficha, '
            'en el menú del negocio. Los reclamos sobre LA PLATAFORMA se dirigen a '
            '${AppConfig.correoPrivacidad} y se responden en un plazo máximo de diez (10) días hábiles.',
        'Si el reclamo no se resuelve, EL USUARIO puede acudir ${_a(p.autoridadConsumidor)}, '
            'conforme a ${p.leyConsumidor}. Presentar un reclamo ante la autoridad de consumo suele '
            'ser gratuito y no requiere abogado.',
        if (p.codigo == 'PE')
          'En Perú, EL RESTAURANTE debe tener a disposición de EL USUARIO un Libro de '
              'Reclamaciones, también en versión virtual.',
      ]),
      const SeccionLegal('ELIMINACIÓN DE LA CUENTA', enSimple: 'Puedes borrar tu cuenta cuando quieras.', [
        'EL USUARIO puede eliminar su cuenta en cualquier momento desde "Mi cuenta". Lo que se '
            'borra y lo que se conserva se detalla en la Política de Privacidad.',
      ]),
      SeccionLegal('LEY APLICABLE Y DOMICILIO',
          enSimple: 'Aplican las leyes de ${p.nombre}, donde está tu restaurante.', [
        'Los pedidos se rigen por las leyes de ${p.nombre}, país del restaurante donde se realiza '
            'el pedido, sin perjuicio de los derechos que las leyes del país de EL USUARIO le '
            'reconozcan como consumidor.',
        'EL TITULAR fija su domicilio en ${AppConfig.ciudadPais}.',
      ]),
      const SeccionLegal('MODIFICACIONES Y ACEPTACIÓN',
          enSimple: 'Ningún cambio vale sin que lo aceptes.', [
        'Si los presentes términos cambian, se solicitará a EL USUARIO aceptar la nueva versión '
            'antes de continuar usando LA PLATAFORMA; ningún cambio se aplica sin su aceptación. '
            'Versión vigente: ${AppConfig.versionTerminos}.',
        'EL USUARIO acepta estos términos al marcar la casilla de aceptación en LA PLATAFORMA. Si '
            'lo requiere, puede imprimir el presente documento y firmarlo en el espacio previsto '
            'al final.',
      ]),
    ]);
  }
  // ------------------------------------------------- condiciones del restaurante

  /// Contacto para reclamos: el que configuró el restaurante o, si no, su
  /// teléfono y correo.
  static String contactoReclamos(NegocioModel n) {
    final c = n.condiciones.contactoReclamos.trim();
    if (c.isNotEmpty) return c;
    final partes = [n.telefono.trim(), n.correoContacto.trim()].where((e) => e.isNotEmpty);
    return partes.isEmpty ? 'el personal del restaurante, en el local' : partes.join(' · ');
  }

  static String _vendedor(NegocioModel n) =>
      n.razonSocial.trim().isNotEmpty ? n.razonSocial.trim() : n.nombre;

  static String _metodosPago(NegocioModel n) => n.qrPagoUrl.trim().isEmpty
      ? 'en efectivo'
      : 'en efectivo, con el QR de pago del restaurante o por transferencia (subiendo tu comprobante)';

  static List<String> resumenCondiciones(NegocioModel n) => [
        'Le compras a ${n.nombre}: ellos preparan y entregan tu pedido.',
        'Antes de confirmar ves el total exacto, con el envío y la propina por separado.',
        'Si necesitas cancelar, avisa al restaurante lo antes posible.',
        'Si corresponde una devolución: ${n.condiciones.textoReembolso.toLowerCase()}, '
            'en hasta ${n.condiciones.diasReembolso} días hábiles.',
        'Reclamos: ${contactoReclamos(n)}.',
      ];

  /// Condiciones que cada restaurante ofrece a sus clientes, en forma de
  /// documento formal (tercera persona y cláusulas). Combinan los datos del
  /// restaurante con lo que la app realmente permite hacer.
  static List<SeccionLegal> condicionesRestaurante(NegocioModel n) {
    final c = n.condiciones;
    final p = n.datosPais;
    final nit = n.nit.trim();
    final direccion = [n.direccion.trim(), n.ciudad.trim()].where((e) => e.isNotEmpty).join(', ');
    final secciones = <SeccionLegal>[
      SeccionLegal('PARTES', enSimple: 'Le compras a ${n.nombre}, no a la plataforma.', [
        'Las presentes condiciones regulan la compra de productos a ${_vendedor(n)}'
            '${nit.isEmpty ? '' : ' (${p.idFiscal} $nit)'}'
            '${direccion.isEmpty ? '' : ', con dirección en $direccion'}, en ${p.nombre}, en adelante '
            '"EL RESTAURANTE", por parte de la persona que realiza un pedido, en adelante "EL CLIENTE".',
        if (n.telefono.trim().isNotEmpty || n.correoContacto.trim().isNotEmpty)
          'Contacto de EL RESTAURANTE: '
              '${[n.telefono.trim(), n.correoContacto.trim()].where((e) => e.isNotEmpty).join(' · ')}.',
        '${AppConfig.nombrePlataforma}, en adelante "LA PLATAFORMA", es la herramienta con la que '
            'EL RESTAURANTE recibe los pedidos. La compra se celebra entre EL CLIENTE y EL RESTAURANTE.',
      ]),
      const SeccionLegal('FORMA DE REALIZAR LOS PEDIDOS',
          enSimple: 'Pides desde la app y sigues tu pedido en ella.', [
        'EL CLIENTE elige los productos en el menú, la forma de entrega (en mesa, para recoger o a '
            'domicilio, según lo que ofrezca cada sucursal) y la forma de pago.',
        'EL CLIENTE puede programar un pedido para más tarde, dentro del horario de la sucursal. Si '
            'EL RESTAURANTE pausó la recepción de pedidos, LA PLATAFORMA se lo informa.',
        'EL CLIENTE puede seguir el estado de su pedido en la aplicación: pendiente, en '
            'preparación, listo, en camino y entregado.',
      ]),
      SeccionLegal('PRECIOS Y PAGOS', enSimple: 'Pagas lo que ves al confirmar, directo al restaurante.', [
        'Los precios se expresan en ${p.nombreMoneda} (${p.simbolo}) '
            '${p.impuestosIncluidos ? 'e incluyen los impuestos' : 'sin los impuestos de venta, que se suman al cobrar'}. '
            'Si un producto está en promoción, se cobra el precio de promoción mientras esté vigente.',
        'Antes de confirmar, EL CLIENTE ve el detalle completo: productos, descuentos, costo de '
            'envío y propina. Ese total es el que se paga; no existen cobros ocultos, conforme a '
            '${p.leyConsumidor}.',
        'EL CLIENTE puede pagar ${_metodosPago(n)}. El pago se realiza directamente a EL RESTAURANTE.',
      ]),
      SeccionLegal('ENTREGA A DOMICILIO',
          enSimple: 'El costo de envío depende de tu zona y lo ves antes de confirmar.', [
        'El costo de envío depende de la zona de EL CLIENTE y cada sucursal puede exigir un monto '
            'mínimo. Ambos se muestran antes de confirmar.',
        if (c.tiempoEntrega.trim().isNotEmpty)
          'Tiempo de entrega estimado: ${c.tiempoEntrega.trim()}. Puede variar en horas de mucho '
              'movimiento o por el clima.',
        'Mientras el pedido va en camino, EL CLIENTE ve al repartidor en el mapa y puede llamarlo.',
      ]),
      const SeccionLegal('CANCELACIONES',
          enSimple: 'Si necesitas cancelar, avisa al restaurante lo antes posible.', [
        'Si EL CLIENTE necesita cancelar, debe comunicarse con EL RESTAURANTE lo antes posible. Si '
            'la preparación aún no comenzó, EL RESTAURANTE lo cancela sin costo.',
        'EL RESTAURANTE puede cancelar un pedido si no puede atenderlo (por ejemplo, si se agotó '
            'un producto), registrando el motivo, que EL CLIENTE ve en el detalle del pedido.',
      ]),
      SeccionLegal('DEVOLUCIONES',
          enSimple: 'Si pagaste y el pedido no se entrega, te devuelven tu dinero.', [
        'Si EL CLIENTE pagó y el pedido se cancela, o llega incompleto o equivocado, EL RESTAURANTE '
            'devuelve lo que corresponda: ${c.textoReembolso.toLowerCase()}, en un plazo de hasta '
            '${c.diasReembolso} días hábiles.',
      ]),
      const SeccionLegal('ALERGIAS', enSimple: 'Marca tus alergias; si son graves, confirma con el local.', [
        'Las alergias que EL CLIENTE indique aparecen destacadas para la cocina, que hará lo posible '
            'por preparar el pedido sin esos ingredientes. Si la alergia es grave, EL CLIENTE debe '
            'confirmarlo con EL RESTAURANTE antes de consumir: no se puede garantizar la ausencia de '
            'contacto cruzado.',
      ]),
      if (p.idFactura.isNotEmpty)
        SeccionLegal('FACTURACIÓN', enSimple: 'Si quieres factura, pídela al confirmar.', [
          'Si EL CLIENTE necesita factura, debe marcar "Quiero factura" al confirmar e indicar su '
              '${p.idFactura}. La factura la emite EL RESTAURANTE.',
        ]),
      SeccionLegal('RECLAMOS', enSimple: 'Reclama a ${contactoReclamos(n)}.', [
        'EL CLIENTE puede presentar su reclamo a ${contactoReclamos(n)}, de forma verbal o escrita '
            'y sin formalidades. EL RESTAURANTE debe responder en un plazo máximo de diez (10) días '
            'hábiles.',
        'Si el reclamo no se resuelve, EL CLIENTE puede acudir ${_a(p.autoridadConsumidor)} '
            '(${Pais.sinArticulo(p.leyConsumidor)}).',
        if (p.codigo == 'PE')
          'EL CLIENTE también puede dejar su reclamo en el Libro de Reclamaciones de EL RESTAURANTE.',
      ]),
      if (c.notas.trim().isNotEmpty)
        SeccionLegal('REGLAS PROPIAS DE ${n.nombre.toUpperCase()}',
            enSimple: 'Reglas que agregó el restaurante.', [c.notas.trim()]),
      SeccionLegal('MODIFICACIONES Y ACEPTACIÓN',
          enSimple: 'Si el restaurante cambia estas condiciones, te las mostramos de nuevo.', [
        'Al pulsar "Acepto" quedan registradas la fecha y la versión aceptada'
            '${c.version.isEmpty ? '' : ' (versión ${c.version})'}.',
        'Si EL RESTAURANTE modifica estas condiciones, se solicitará a EL CLIENTE aceptarlas antes '
            'de su próximo pedido. Estas condiciones se suman a los Términos y Condiciones y a la '
            'Política de Privacidad de la plataforma.',
      ]),
    ];
    return _numerarClausulas(secciones);
  }

  // ------------------------------------------------------ acuerdo del personal

  /// Versión del acuerdo que debe tener firmada cada persona del personal:
  /// la de la plataforma más la de las reglas internas de su restaurante.
  static String versionAcuerdo(NegocioModel? n) {
    final reglas = n?.reglasPersonal.version ?? '';
    return reglas.isEmpty
        ? AppConfig.versionAcuerdoPersonal
        : '${AppConfig.versionAcuerdoPersonal}+$reglas';
  }

  /// true si la versión firmada es la vigente. Si todavía no se sabe el
  /// restaurante, alcanza con la versión de la plataforma.
  static bool acuerdoAlDia(String? firmada, NegocioModel? negocio) {
    if (firmada == null) return false;
    if (negocio == null) return firmada.split('+').first == AppConfig.versionAcuerdoPersonal;
    return firmada == versionAcuerdo(negocio);
  }

  static String _nombreRestaurante(NegocioModel? n) => n == null
      ? 'el restaurante al que perteneces'
      : (n.razonSocial.trim().isNotEmpty ? n.razonSocial.trim() : n.nombre);

  static List<String> resumenAcuerdo({required NegocioModel? negocio, required String rol}) => [
        'Tu cuenta es solo tuya: no compartas tu contraseña ni tu código de verificación.',
        'Todo lo que haces en la app queda registrado a tu nombre.',
        'Los datos de los clientes son solo para atender sus pedidos, también después de que '
            'dejes de trabajar aquí.',
        switch (rol) {
          Rol.cocina => 'En cocina, las alergias de los clientes se respetan siempre.',
          Rol.cajero => 'En caja, cada cobro y movimiento se registra y no se puede borrar.',
          Rol.repartidor =>
            'En reparto, tu ubicación se comparte solo mientras llevas un pedido.',
          _ => 'Como administrador, cuidas el acceso de tu personal y los datos de tu restaurante.',
        },
        'Este acuerdo no reemplaza tu contrato de trabajo.',
      ];

  static String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  /// Acuerdo que firma cada persona del personal (Administrador, Cajero,
  /// Cocina, Repartidor) al entrar por primera vez. NO reemplaza el
  /// contrato de trabajo, que el restaurante firma aparte según la ley
  /// laboral del país: regula el uso de la cuenta y la confidencialidad.
  ///
  /// Está escrito como un acuerdo formal (en tercera persona y con
  /// cláusulas PRIMERA.-, SEGUNDA.-…). Cada cláusula tiene su "En simple"
  /// para que se entienda fácil. Se personaliza con los datos de la
  /// persona, su cargo, su sucursal y las reglas internas del restaurante.
  static List<SeccionLegal> acuerdoPersonal({
    required NegocioModel? negocio,
    required UsuarioModel usuario,
    String sucursal = '',
  }) {
    final restaurante = _nombreRestaurante(negocio);
    final nit = (negocio?.nit ?? '').trim();
    final p = negocio?.datosPais ?? Paises.actual;
    final rol = usuario.rol;
    final reglas = negocio?.reglasPersonal.reglas ?? const <String>[];
    final firma = usuario.acuerdo;
    final nombre = firma != null && firma.nombre.trim().isNotEmpty ? firma.nombre.trim() : usuario.nombre;
    final documento = firma != null && firma.ci.trim().isNotEmpty
        ? 'con ${p.docIdentidad} ${firma.ci.trim()}'
        : 'cuyo ${p.docIdentidad} se registra al momento de firmar';
    final enSucursal = sucursal.trim().isEmpty ? '' : ', en la sucursal ${sucursal.trim()}';

    final clausulas = <SeccionLegal>[
      SeccionLegal('PARTES', enSimple: 'Quién firma, con qué restaurante y qué papel tiene la plataforma.', [
        'Intervienen en el presente acuerdo:',
        '1. $restaurante${nit.isEmpty ? '' : ', con ${p.idFiscal} $nit'}, con domicilio en ${p.nombre}, '
            'en adelante "EL RESTAURANTE".',
        '2. $nombre, $documento, que desempeña el cargo de $rol$enSucursal, en adelante '
            '"LA PERSONA FIRMANTE".',
        'La plataforma ${AppConfig.nombrePlataforma}, cuyos titulares son ${AppConfig.titularPlataforma}, '
            'en adelante "LA PLATAFORMA", es la herramienta tecnológica con la que EL RESTAURANTE '
            'gestiona sus pedidos. LA PLATAFORMA no es empleadora de LA PERSONA FIRMANTE.',
        if (usuario.fechaRegistro != null)
          'LA PERSONA FIRMANTE usa LA PLATAFORMA desde el ${_fecha(usuario.fechaRegistro!)}.',
      ]),
      const SeccionLegal('DEFINICIONES', enSimple: 'Qué significa cada palabra importante de este acuerdo.', [
        'Para efectos del presente acuerdo se entiende por:',
        'a) Cuenta: el usuario personal con el que LA PERSONA FIRMANTE ingresa a LA PLATAFORMA, '
            'protegido con contraseña y, cuando corresponda, verificación en dos pasos.',
        'b) Datos de los clientes: nombres, teléfonos, direcciones, alergias, notas, datos de '
            'factura y cualquier otra información de las personas que hacen pedidos.',
        'c) Información confidencial: los datos de los clientes y la información interna de EL '
            'RESTAURANTE, como ventas, precios de costo, recetas, proveedores, movimientos de caja '
            'y reportes.',
        'd) Incidente de seguridad: cualquier pérdida, robo, acceso no autorizado o uso indebido '
            'de una cuenta o de información confidencial.',
      ]),
      SeccionLegal('OBJETO', enSimple: 'Este acuerdo regula tu cuenta y la confidencialidad. No es tu contrato de trabajo.', [
        'El presente acuerdo tiene por objeto regular el uso de la cuenta de LA PERSONA FIRMANTE '
            'en LA PLATAFORMA y el tratamiento de la información confidencial a la que accede por '
            'su trabajo.',
        'Este acuerdo no reemplaza ni modifica el contrato de trabajo de LA PERSONA FIRMANTE. '
            'Sueldo, horario y beneficios se rigen por lo que acuerde con EL RESTAURANTE, conforme '
            'a ${p.leyTrabajo}.',
      ]),
      const SeccionLegal('USO DE LA CUENTA', enSimple: 'Tu cuenta es solo tuya y todo lo que se hace con ella queda a tu nombre.', [
        'La cuenta es personal e intransferible. LA PERSONA FIRMANTE se compromete a no '
            'compartir su contraseña ni el código de su app autenticadora, y a cerrar sesión en '
            'equipos que usen otras personas.',
        'Todas las acciones realizadas con la cuenta quedan registradas a nombre de LA PERSONA '
            'FIRMANTE: cambios de estado de los pedidos, cobros, movimientos de caja y '
            'cancelaciones con su motivo. Estos registros no se pueden borrar.',
        'LA PERSONA FIRMANTE usará LA PLATAFORMA solo para las tareas de su cargo y no intentará '
            'acceder a funciones o información que no le correspondan.',
      ]),
      const SeccionLegal('CONFIDENCIALIDAD DE LOS DATOS DE LOS CLIENTES',
          enSimple: 'Los datos de los clientes son solo para atender sus pedidos.', [
        'LA PERSONA FIRMANTE usará los datos de los clientes únicamente para atender sus pedidos.',
        'Queda prohibido copiarlos, fotografiarlos, guardarlos fuera de LA PLATAFORMA, '
            'compartirlos con terceros o usarlos para contactar a los clientes por motivos ajenos '
            'a su pedido.',
      ]),
      const SeccionLegal('INFORMACIÓN CONFIDENCIAL DEL RESTAURANTE',
          enSimple: 'Lo interno del restaurante (ventas, precios, recetas) no se comparte.', [
        'LA PERSONA FIRMANTE mantendrá en reserva la información interna de EL RESTAURANTE a la '
            'que acceda, como ventas, precios de costo, recetas, proveedores, movimientos de caja '
            'y reportes, y no la divulgará a terceros sin autorización escrita de EL RESTAURANTE.',
      ]),
      _tareasDelRol(rol),
      if (reglas.isNotEmpty)
        SeccionLegal('REGLAS INTERNAS DE ${(negocio?.nombre ?? 'EL RESTAURANTE').toUpperCase()}',
            enSimple: 'Reglas que agregó tu restaurante.', [
          'LA PERSONA FIRMANTE cumplirá además las siguientes reglas internas de EL RESTAURANTE:',
          for (var i = 0; i < reglas.length; i++) '${i + 1}. ${reglas[i]}',
        ]),
      const SeccionLegal('INCIDENTES DE SEGURIDAD',
          enSimple: 'Si pierdes tu teléfono o alguien usó tu cuenta, avisa enseguida.', [
        'LA PERSONA FIRMANTE informará al Administrador de EL RESTAURANTE de inmediato, y como '
            'máximo dentro de las 24 horas, cualquier incidente de seguridad: pérdida o robo de '
            'su teléfono, sospecha de que otra persona conoce su contraseña o uso indebido de '
            'información confidencial.',
      ]),
      SeccionLegal('DATOS PERSONALES DE LA PERSONA FIRMANTE',
          enSimple: 'Se guarda solo lo necesario para tu trabajo y lo ve tu Administrador.', [
        'Para este acuerdo y su trabajo en LA PLATAFORMA se registran el nombre, correo, '
            'teléfono y ${p.docIdentidad} de LA PERSONA FIRMANTE, el historial de sus acciones y, '
            'en el caso del cargo de Repartidor, su ubicación solo mientras tiene entregas en curso.',
        'Estos datos los ve el Administrador de EL RESTAURANTE y se usan para operar y para '
            'resolver diferencias de caja o reclamos, conforme a ${p.leyDatos}. LA PERSONA '
            'FIRMANTE puede pedir acceso o corrección de sus datos a su Administrador.',
      ]),
      SeccionLegal('INCUMPLIMIENTO', enSimple: 'Si no cumples este acuerdo, tu cuenta puede suspenderse.', [
        'Ante el incumplimiento de este acuerdo, EL RESTAURANTE podrá suspender o desactivar la '
            'cuenta de LA PERSONA FIRMANTE y aplicar las medidas previstas en su reglamento '
            'interno y en el contrato de trabajo, conforme a ${p.leyTrabajo}.',
        'Lo anterior no excluye las acciones legales que correspondan por los daños causados, '
            'conforme a las leyes de ${p.nombre}.',
      ]),
      const SeccionLegal('VIGENCIA Y TERMINACIÓN',
          enSimple: 'Vale desde que firmas. Si dejas de trabajar aquí, la confidencialidad sigue.', [
        'El presente acuerdo entra en vigencia en la fecha de su firma y se mantiene mientras LA '
            'PERSONA FIRMANTE tenga una cuenta activa en EL RESTAURANTE.',
        'Al terminar la relación con EL RESTAURANTE, el Administrador desactivará la cuenta. Las '
            'obligaciones de confidencialidad se mantienen vigentes después de la terminación.',
      ]),
      SeccionLegal('LEY APLICABLE Y CONTROVERSIAS',
          enSimple: 'Se aplican las leyes del país del restaurante.', [
        'El presente acuerdo se rige por las leyes de ${p.nombre}. Cualquier controversia se '
            'intentará resolver primero de buena fe entre las partes y, de no lograrse, se '
            'someterá a las autoridades competentes de ${p.nombre}.',
      ]),
      SeccionLegal('ACEPTACIÓN Y FIRMA ELECTRÓNICA',
          enSimple: 'Firmas con tu nombre, tu documento y tu firma dibujada; queda registrado con fecha y hora.', [
        'LA PERSONA FIRMANTE acepta el presente acuerdo al escribir su nombre completo y su '
            '${p.docIdentidad}, dibujar su firma en la pantalla y pulsar "Firmar y continuar". La aceptación queda registrada con '
            'la fecha y hora del servidor y la versión ${versionAcuerdo(negocio)}, y es válida '
            'conforme a ${p.leyFirma}. EL RESTAURANTE puede pedir además una firma en papel.',
        'LA PERSONA FIRMANTE puede descargar una copia del acuerdo firmado en "Mi cuenta". Si '
            'el acuerdo o las reglas internas cambian, se le pedirá firmar la nueva versión.',
      ]),
    ];
    return _numerarClausulas(clausulas);
  }

  /// Obligaciones de cada cargo (solo las suyas: el cajero no lee las del
  /// repartidor).
  static SeccionLegal _tareasDelRol(String rol) {
    const comun = 'LA PERSONA FIRMANTE registrará en LA PLATAFORMA lo que realmente ocurre con '
        'cada pedido y no cancelará pedidos sin un motivo verdadero.';
    return switch (rol) {
      Rol.cocina => const SeccionLegal('OBLIGACIONES EN COCINA',
            enSimple: 'Prepara respetando las alergias y marca cada pedido a tiempo.', [
          comun,
          'Respetará siempre las alergias indicadas en los pedidos. Si un ingrediente no se '
              'puede quitar, avisará antes de preparar.',
          'Marcará "En preparación" al empezar y "Listo" al terminar cada pedido, para que el '
              'cliente y el resto del personal conozcan su avance.',
        ]),
      Rol.cajero => const SeccionLegal('OBLIGACIONES EN CAJA',
            enSimple: 'Abre y cierra tu caja en la app y registra cada cobro con honestidad.', [
          comun,
          'Abrirá y cerrará su caja en LA PLATAFORMA, registrará cada cobro, ingreso y egreso, y '
              'contará el efectivo con honestidad. Los movimientos registrados no se pueden borrar.',
          'Recibirá y registrará el efectivo que entreguen los repartidores, y asignará los '
              'pedidos de delivery solo a repartidores disponibles.',
        ]),
      Rol.repartidor => const SeccionLegal('OBLIGACIONES EN REPARTO',
            enSimple: 'Entrega con cuidado, cobra lo que dice la app y rinde el efectivo en caja.', [
          comun,
          'Acepta que, mientras tenga entregas en curso, su ubicación se comparta con el cliente '
              'de ese pedido. La ubicación deja de compartirse al entregarlo.',
          'Cobrará exactamente el monto que muestra LA PLATAFORMA y entregará el efectivo en caja '
              'el mismo día, según las normas de EL RESTAURANTE.',
          'Tratará con respeto a los clientes y no usará su teléfono ni su dirección para nada '
              'distinto de la entrega.',
        ]),
      _ => const SeccionLegal('OBLIGACIONES DEL ADMINISTRADOR',
            enSimple: 'Cuidas el acceso de tu personal y que los datos del restaurante sean correctos.', [
          comun,
          'Gestionará al personal y sus permisos, y desactivará de inmediato la cuenta de quien '
              'deje de trabajar en EL RESTAURANTE.',
          'Mantendrá correctos los precios, las promociones, los horarios y las condiciones que '
              'ven los clientes.',
        ]),
    };
  }

  static const _ordinales = [
    'PRIMERA', 'SEGUNDA', 'TERCERA', 'CUARTA', 'QUINTA', 'SEXTA', 'SÉPTIMA', 'OCTAVA', 'NOVENA',
    'DÉCIMA', 'DÉCIMA PRIMERA', 'DÉCIMA SEGUNDA', 'DÉCIMA TERCERA', 'DÉCIMA CUARTA',
    'DÉCIMA QUINTA', 'DÉCIMA SEXTA',
  ];

  /// "a" + autoridad, con la contracción: "al Viceministerio…", "a la PROFECO".
  static String _a(String autoridad) =>
      autoridad.startsWith('el ') ? 'al ${autoridad.substring(3)}' : 'a $autoridad';

  /// Pone "PRIMERA.- (…)", "SEGUNDA.- (…)"… como en los acuerdos formales.
  static List<SeccionLegal> _numerarClausulas(List<SeccionLegal> s) => [
        for (var i = 0; i < s.length; i++)
          SeccionLegal('${_ordinales[i]}.- (${s[i].titulo})', s[i].parrafos, enSimple: s[i].enSimple),
      ];
}
