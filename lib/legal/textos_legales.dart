import '../config/app_config.dart';
import '../models/condiciones_negocio.dart';
import '../models/negocio_model.dart';
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
/// que la app realmente hace; NO sustituyen la revisión de un abogado en
/// Bolivia. Si cambia el funcionamiento de la app (por ejemplo, se agrega
/// la ubicación del repartidor), hay que actualizar este archivo y subir
/// `AppConfig.versionTerminos`.
///
/// Todos los documentos usan los mismos términos: "el restaurante" (el
/// negocio que atiende), "la plataforma" (la app) y "tú" (quien lee).
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

  static List<String> resumenTerminos() => const [
        'La plataforma es la herramienta; el restaurante prepara y entrega tu pedido.',
        'Antes de confirmar ves el total exacto: no hay cobros escondidos.',
        'Le pagas directamente al restaurante.',
        'Marca tus alergias; si son graves, confirma con el local.',
        'Si tienes un problema, reclama primero al restaurante; si no se resuelve, a Defensa del Consumidor.',
      ];

  static List<SeccionLegal> politicaPrivacidad() => [
        SeccionLegal('1. Quién es responsable', enSimple: 'La plataforma es la herramienta; el restaurante atiende tu pedido. Si tienes dudas sobre tus datos, escríbenos.', [
          '${AppConfig.nombrePlataforma} es una plataforma ofrecida por '
              '${AppConfig.titularPlataforma} para que distintos negocios '
              'reciban y gestionen pedidos. Cada negocio aparece identificado '
              'en su ficha y es quien atiende tu pedido.',
          'Responsable del tratamiento de tus datos: '
              '${AppConfig.titularPlataforma}, con domicilio en '
              '${AppConfig.ciudadPais}. Para consultas sobre tus datos escribe a '
              '${AppConfig.correoPrivacidad}.',
          'Esta política cumple lo que exigen la Constitución Política del '
              'Estado (arts. 21 y 130) y el Reglamento de la Ley 164 '
              '(DS 1793, art. 56): pedir tu consentimiento, decirte para qué '
              'usamos tus datos y respetar tus derechos sobre ellos.',
        ]),
        SeccionLegal('2. Qué datos recopilamos', enSimple: 'Guardamos solo lo necesario para atender tus pedidos: tus datos de contacto, tus direcciones y tus pedidos.', [
          'Datos de tu cuenta: nombre, correo electrónico y teléfono. Tu '
              'contraseña la gestiona el servicio de autenticación de Google '
              'Firebase y nosotros no podemos verla.',
          'Datos de entrega: las direcciones que guardes en tu cuenta. Si '
              'eliges delivery, tu nombre y teléfono se guardan junto al '
              'pedido para que el repartidor pueda contactarte.',
          'Ubicación: el punto que marques en el mapa al guardar una dirección '
              'de entrega. Si usas "Mi ubicación", el dispositivo te pide '
              'permiso y la usamos solo para colocar ese punto; no la '
              'guardamos de forma continua.',
          'Ubicación del repartidor: mientras tu pedido de delivery va en '
              'camino, el repartidor comparte su posición con la plataforma '
              'y tú la ves en un mapa. Esa posición se borra cuando el pedido '
              'se entrega.',
          'Reseñas: si calificas un pedido, se publican tu nombre corto '
              '(por ejemplo "Ana P."), las estrellas y tu comentario para los '
              'demás clientes de ese negocio. Puedes borrarla cuando quieras.',
          'Datos de tus pedidos: productos, total, forma de pago, notas y '
              'estado, y el comprobante de pago si lo subes.',
          'Imágenes que subas: foto de perfil y comprobantes de pago.',
          'Alergias: si las marcas en tu cuenta o en un pedido, se guardan en '
              'tu cuenta y en el pedido para que la cocina las vea. Es un dato '
              'de salud: solo lo usamos para preparar tu pedido con seguridad y '
              'puedes quitarlo cuando quieras en "Mi cuenta".',
          'Datos para factura: si pides factura, el NIT o CI y la razón social '
              'se guardan en el pedido para el negocio y, para no volver a '
              'escribirlos, en tu dispositivo.',
          'Idioma, tamaño de letra y avisos: se guardan solo en tu dispositivo.',
          'Copia para usar sin internet: en la app del celular se guarda en tu '
              'teléfono una copia de los datos ya cargados, para que la app '
              'funcione si se corta la conexión. En la versión web no se guarda '
              'ninguna copia en el navegador.',
          'Informes de fallas: si la app tiene una falla inesperada, se guarda '
              'un informe técnico (mensaje de error, versión de la app, tipo de '
              'dispositivo, tu rol y tu identificador de usuario, sin tu nombre '
              'ni tus pedidos) para poder corregirla. Se borran periódicamente.',
          'No usamos tus datos para publicidad de terceros.',
        ]),
        SeccionLegal('3. Para qué los usamos', enSimple: 'Usamos tus datos para atender tus pedidos y nada más.', [
          'Para crear y mantener tu cuenta, procesar y entregar tus pedidos, '
              'permitir que el negocio te contacte sobre un pedido, atender '
              'reclamos, prevenir abusos (por ejemplo, el bloqueo de cuentas '
              'por parte de un negocio) y cumplir obligaciones legales.',
        ]),
        SeccionLegal('4. Con quién los compartimos', enSimple: 'Tu restaurante ve lo necesario para tu pedido. No vendemos tus datos ni los usamos para publicidad.', [
          'Con otros clientes del negocio: tus reseñas publicadas. El '
              'negocio puede ocultar reseñas ofensivas y bloquear cuentas que '
              'las escriban.',
          'Con el negocio al que le haces un pedido: ve tu nombre, tu '
              'teléfono, el contenido del pedido y, si eliges delivery, la '
              'dirección de entrega. Si es delivery, el repartidor del negocio '
              'que toma tu pedido ve tu nombre, teléfono y dirección para '
              'entregarlo, y tú ves el nombre y teléfono del repartidor '
              'mientras tu pedido va en camino. No compartimos tus datos con '
              'los demás negocios de la plataforma.',
          'Con proveedores técnicos que guardan o procesan la información por '
              'nosotros: Google Firebase (cuentas, base de datos y alojamiento '
              'de la web) y Cloudinary (imágenes). Para buscar direcciones y '
              'mostrar el mapa se usan los servicios de OpenStreetMap, que '
              'reciben el texto de la dirección que buscas.',
          'Estos proveedores tienen sus servidores fuera de Bolivia (por '
              'ejemplo, en Estados Unidos). Al aceptar esta política aceptas '
              'que tus datos se guarden allí, con las medidas de seguridad de '
              'esos proveedores.',
          'Traducción: si usas la app en otro idioma, el texto de tus notas y '
              'de la referencia de tu dirección se envía al servicio de '
              'traducción automática MyMemory para que el personal lo lea en '
              'español. No envíes datos sensibles en las notas: para las '
              'alergias usa la lista de la app, que no pasa por ese servicio.',
          'No vendemos tus datos.',
        ]),
        SeccionLegal('5. Cuánto tiempo los conservamos', enSimple: 'Mientras tengas tu cuenta. Si la eliminas, borramos tu perfil; los pedidos quedan sin tu nombre.', [
          'Mientras tengas tu cuenta activa. Si eliminas tu cuenta desde '
              '"Mi cuenta", borramos tu perfil, tus direcciones, tus favoritos, '
              'tus reseñas y tu carrito.',
          'Los registros de pedidos pasados se conservan sin tu identificador '
              'ni tu dirección, porque el negocio los necesita para su '
              'contabilidad y para atender reclamos. Pueden conservarse el '
              'comprobante de pago que hayas subido y el nombre que aparezca '
              'en él.',
          'Las imágenes guardadas en Cloudinary (foto de perfil y '
              'comprobantes) no se pueden borrar desde la app. Si quieres que '
              'las eliminemos, escríbenos a ${AppConfig.correoPrivacidad}.',
        ]),
        SeccionLegal('6. Tus derechos', enSimple: 'Puedes ver, corregir o borrar tus datos cuando quieras.', [
          'La Constitución Política del Estado reconoce tu derecho a la '
              'privacidad y a conocer, corregir y eliminar tus datos '
              'personales.',
          'Tienes derecho a: conocer qué datos tuyos tenemos (acceso), '
              'corregirlos (rectificación), pedir que los borremos '
              '(cancelación), oponerte a un uso concreto (oposición) y retirar '
              'tu consentimiento en cualquier momento. Retirarlo no afecta lo '
              'que se hizo antes con tu autorización.',
          'Puedes ver y corregir tu nombre y teléfono en "Mi cuenta", y '
              'eliminar tu cuenta en "Mi cuenta > Eliminar mi cuenta". Para '
              'cualquier otra solicitud escribe a ${AppConfig.correoPrivacidad}: '
              'te responderemos en un plazo máximo de 10 días hábiles.',
          'Si consideras que tus datos se usan de forma indebida, también '
              'puedes presentar una Acción de Protección de Privacidad ante un '
              'juez (Constitución, arts. 130 y 131).',
        ]),
        SeccionLegal('7. Seguridad', enSimple: 'Cada persona ve solo lo que le corresponde.', [
          'Los datos se guardan en servicios de Google Firebase con reglas '
              'de acceso por rol: tú ves tus datos y el personal de un '
              'negocio solo ve los pedidos de ese negocio. Ningún sistema es '
              'infalible, por eso te recomendamos usar una contraseña única.',
        ]),
        SeccionLegal('8. Menores de edad', enSimple: 'Necesitas 18 años, o el permiso de tu madre, padre o tutor.', [
          'Para crear una cuenta debes tener 18 años o más. Si eres menor de '
              'edad, solo puedes usar la plataforma con la autorización y '
              'supervisión de tu madre, padre o tutor, que es responsable de '
              'los pedidos que hagas.',
        ]),
        SeccionLegal('9. Tu consentimiento', enSimple: 'Al aceptar, nos autorizas a usar tus datos como dice esta política.', [
          'Al marcar la casilla de aceptación al crear tu cuenta das tu '
              'consentimiento previo, expreso e informado para que tratemos '
              'tus datos como explica esta política. Tus alergias (dato de '
              'salud) solo se guardan si tú las marcas, y solo para preparar '
              'tus pedidos con seguridad.',
        ]),
        SeccionLegal('10. Cambios en esta política', enSimple: 'Si algo cambia, te avisamos y te pedimos aceptar de nuevo.', [
          'Si cambiamos esta política, te pediremos aceptar la nueva versión '
              'antes de seguir usando la app. Versión: '
              '${AppConfig.versionTerminos}.',
        ]),
      ];

  static List<SeccionLegal> terminos() => [
        SeccionLegal('1. El servicio', enSimple: 'La plataforma te conecta con el restaurante; el restaurante prepara y entrega tu pedido.', [
          '${AppConfig.nombrePlataforma} permite hacer pedidos a negocios '
              'de comida. La plataforma conecta al cliente con el negocio; '
              'la compra se acuerda entre el cliente y el negocio, que es '
              'quien prepara y entrega el pedido.',
        ]),
        SeccionLegal('2. Tu cuenta', enSimple: 'Usa datos reales y cuida tu contraseña.', [
          'Debes dar datos verdaderos y mantenerlos actualizados. Eres '
              'responsable de cuidar tu contraseña y de lo que se haga con '
              'tu cuenta.',
          'Debes tener 18 años o más, o usar la plataforma con autorización y '
              'supervisión de tu madre, padre o tutor.',
        ]),
        SeccionLegal('3. Precios y pedidos', enSimple: 'El total que ves antes de confirmar es lo que pagas. Sin cobros escondidos.', [
          'Los precios se muestran en bolivianos (Bs) e incluyen los impuestos. '
              'Antes de confirmar ves el detalle completo: productos, descuento, '
              'costo de envío según tu zona y propina. El total que ves es el '
              'que corresponde pagar; no hay cobros ocultos (Ley 453, art. 14).',
          'El negocio puede rechazar o cancelar un pedido si no puede '
              'atenderlo; si ocurre, verás el motivo en el detalle del pedido.',
          'Puedes programar un pedido para más tarde, dentro del horario de '
              'atención del local. Los productos con cantidad limitada pueden '
              'agotarse antes de que confirmes.',
          'Los cupones de descuento los crea cada negocio, con sus propias '
              'condiciones (monto mínimo y fecha de vencimiento), que se '
              'muestran al aplicarlos. Un cupón vigente se respeta en los '
              'pedidos confirmados mientras estaba vigente.',
          'La propina para el repartidor es voluntaria, va completa para el '
              'repartidor y no forma parte del precio de los productos.',
        ]),
        SeccionLegal('4. Alergias', enSimple: 'Marca tus alergias; el restaurante hará lo posible, pero confirma con el local si tu alergia es grave.', [
          'Si marcas alergias, el negocio las verá destacadas y hará lo '
              'posible por preparar tu pedido sin esos ingredientes. La '
              'información de alérgenos de cada producto la carga el negocio. '
              'Si tu alergia es grave, confirma con el local antes de comer: '
              'la plataforma no puede garantizar que no haya contacto cruzado '
              'en la cocina.',
        ]),
        SeccionLegal('5. Pagos', enSimple: 'Le pagas directamente al restaurante.', [
          'Puedes pagar en efectivo, por transferencia o con el QR de pago '
              'del negocio, según lo que el negocio ofrezca. El pago se hace '
              'directamente al negocio: la plataforma no cobra ni retiene '
              'dinero.',
        ]),
        SeccionLegal('6. Facturas', enSimple: 'La factura la emite el restaurante, si la pides.', [
          'La plataforma no emite facturas fiscales. Si necesitas factura, '
              'marca "Quiero factura" al confirmar y escribe tu NIT o CI: esos '
              'datos llegan al negocio, que es quien emite la factura y '
              'responde por sus obligaciones tributarias.',
        ]),
        SeccionLegal('7. Uso adecuado', enSimple: 'Trata con respeto al personal y no hagas pedidos falsos.', [
          'No está permitido hacer pedidos falsos, ofender o amenazar al '
              'personal de un negocio, publicar reseñas con insultos, datos de '
              'otras personas o contenido racista o discriminatorio (Ley 045), '
              'ni usar la plataforma para fines ilegales. El Administrador de un negocio puede bloquear tu '
              'cuenta en ese negocio si lo incumples; el bloqueo no afecta '
              'a los demás negocios.',
        ]),
        SeccionLegal('8. Responsabilidad', enSimple: 'El restaurante responde por su comida; la plataforma, por que la app funcione.', [
          'Cada negocio es responsable de la calidad, preparación y '
              'entrega de sus productos. La plataforma procura que el '
              'servicio esté disponible, pero no puede garantizar que no '
              'haya interrupciones.',
        ]),
        SeccionLegal('9. Reclamos', enSimple: 'Primero reclama al restaurante; si no se resuelve, puedes acudir a Defensa del Consumidor.', [
          'Puedes presentar tu reclamo directamente al negocio, de forma '
              'verbal o escrita y sin formalidades. Los datos de contacto '
              'de cada negocio están en su ficha, en el menú del negocio. '
              'Para reclamos sobre la plataforma escribe a '
              '${AppConfig.correoPrivacidad}: te responderemos en un plazo '
              'máximo de 10 días hábiles.',
          'Si tu reclamo no se resuelve, puedes acudir al Viceministerio de '
              'Defensa de los Derechos del Usuario y del Consumidor (Ministerio '
              'de Justicia), conforme a la Ley 453. Presentar un reclamo es '
              'gratuito y no necesita abogado.',
        ]),
        SeccionLegal('10. Eliminar tu cuenta', enSimple: 'Puedes borrar tu cuenta cuando quieras.', [
          'Puedes eliminar tu cuenta en cualquier momento desde "Mi cuenta". '
              'Lo que se borra y lo que se conserva está explicado en la '
              'Política de privacidad.',
        ]),
        SeccionLegal('11. Ley aplicable', enSimple: 'Aplican las leyes de Bolivia.', [
          'Estos términos se rigen por las leyes del Estado Plurinacional '
              'de Bolivia. Ciudad de referencia: ${AppConfig.ciudadPais}.',
        ]),
        SeccionLegal('12. Cambios', enSimple: 'Ningún cambio vale sin que lo aceptes.', [
          'Si cambiamos estos términos, te pediremos aceptar la nueva versión '
              'antes de seguir usando la app; ningún cambio se aplica sin tu '
              'aceptación. Versión: ${AppConfig.versionTerminos}.',
        ]),
      ];
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

  /// Condiciones que cada restaurante ofrece a sus clientes. Combinan los
  /// datos del restaurante con lo que la app realmente permite hacer.
  static List<SeccionLegal> condicionesRestaurante(NegocioModel n) {
    final c = n.condiciones;
    final nit = n.nit.trim();
    final direccion = [n.direccion.trim(), n.ciudad.trim()].where((e) => e.isNotEmpty).join(', ');
    final secciones = <SeccionLegal>[
      SeccionLegal('Quién te vende', enSimple: 'Le compras a ${n.nombre}, no a la plataforma.', [
        'El restaurante que prepara y entrega tu pedido es ${_vendedor(n)}'
            '${nit.isEmpty ? '' : ' (NIT $nit)'}'
            '${direccion.isEmpty ? '' : ', con dirección en $direccion'}.',
        if (n.telefono.trim().isNotEmpty || n.correoContacto.trim().isNotEmpty)
          'Contacto: ${[n.telefono.trim(), n.correoContacto.trim()].where((e) => e.isNotEmpty).join(' · ')}.',
        '${AppConfig.nombrePlataforma} es la herramienta con la que ${n.nombre} recibe tus '
            'pedidos. La compra es entre tú y el restaurante.',
      ]),
      const SeccionLegal('Cómo pedir', enSimple: 'Pides desde la app y sigues tu pedido en ella.', [
        'Eliges los productos en el menú, la forma de entrega (en mesa, para recoger o a '
            'domicilio, según lo que ofrezca cada sucursal) y la forma de pago.',
        'Puedes programar un pedido para más tarde, dentro del horario de la sucursal. '
            'Si el restaurante pausó la recepción de pedidos, la app te lo avisa.',
        'Ves el estado de tu pedido en la app: pendiente, en preparación, listo, en camino '
            'y entregado.',
      ]),
      SeccionLegal('Precios y pagos', enSimple: 'Pagas lo que ves al confirmar, directo al restaurante.', [
        'Los precios están en bolivianos (Bs) e incluyen los impuestos. Si un producto está en '
            'promoción, se te cobra el precio de promoción mientras esté vigente.',
        'Antes de confirmar ves el detalle completo: productos, descuentos, costo de envío y '
            'propina. Ese total es lo que pagas; no hay cobros ocultos (Ley 453, art. 14).',
        'Puedes pagar ${_metodosPago(n)}. El pago es directo al restaurante.',
      ]),
      SeccionLegal('Entrega a domicilio',
          enSimple: 'El costo de envío depende de tu zona y lo ves antes de confirmar.', [
        'El costo de envío depende de tu zona y cada sucursal puede pedir un monto mínimo. '
            'Ambos se muestran antes de confirmar.',
        if (c.tiempoEntrega.trim().isNotEmpty)
          'Tiempo de entrega estimado: ${c.tiempoEntrega.trim()}. Puede variar en horas de '
              'mucho movimiento o por el clima.',
        'Mientras tu pedido va en camino ves al repartidor en el mapa y puedes llamarlo.',
      ]),
      const SeccionLegal('Cancelaciones',
          enSimple: 'Si necesitas cancelar, avisa al restaurante lo antes posible.', [
        'Si necesitas cancelar, comunícate con el restaurante lo antes posible. Si todavía no '
            'empezó a preparar tu pedido, lo cancela sin costo.',
        'El restaurante puede cancelar un pedido si no puede atenderlo (por ejemplo, si se '
            'agotó un producto). Verás el motivo en el detalle del pedido.',
      ]),
      SeccionLegal('Devoluciones',
          enSimple: 'Si pagaste y el pedido no se entrega, te devuelven tu dinero.', [
        'Si pagaste y el pedido se cancela, o llega incompleto o equivocado, el restaurante te '
            'devuelve lo que corresponda: ${c.textoReembolso.toLowerCase()}, en un plazo de hasta '
            '${c.diasReembolso} días hábiles.',
      ]),
      const SeccionLegal('Alergias',
          enSimple: 'Marca tus alergias; si son graves, confirma con el local.', [
        'Las alergias que marques aparecen destacadas para la cocina, que hará lo posible por '
            'preparar tu pedido sin esos ingredientes. Si tu alergia es grave, confirma con el '
            'restaurante antes de comer: no se puede garantizar que no haya contacto cruzado.',
      ]),
      const SeccionLegal('Facturas', enSimple: 'Si quieres factura, pídela al confirmar.', [
        'Si necesitas factura, marca "Quiero factura" al confirmar y escribe tu NIT o CI. La '
            'factura la emite el restaurante.',
      ]),
      SeccionLegal('Reclamos', enSimple: 'Reclama a ${contactoReclamos(n)}.', [
        'Presenta tu reclamo a ${contactoReclamos(n)}, de forma verbal o escrita y sin '
            'formalidades. El restaurante debe responderte en un plazo máximo de 10 días hábiles.',
        'Si no se resuelve, puedes acudir al Viceministerio de Defensa de los Derechos del '
            'Usuario y del Consumidor (Ley 453). Es gratuito y no necesitas abogado.',
      ]),
      if (c.notas.trim().isNotEmpty)
        SeccionLegal('Reglas propias de ${n.nombre}',
            enSimple: 'Reglas que agregó el restaurante.', [c.notas.trim()]),
      SeccionLegal('Cambios y aceptación',
          enSimple: 'Si el restaurante cambia estas condiciones, te las mostramos de nuevo.', [
        'Al tocar "Acepto" quedan registradas la fecha y la versión que aceptaste'
            '${c.version.isEmpty ? '' : ' (versión ${c.version})'}.',
        'Si el restaurante cambia estas condiciones, te pediremos aceptarlas antes de tu '
            'próximo pedido. Estas condiciones se suman a los Términos y condiciones y a la '
            'Política de privacidad de la plataforma.',
      ]),
    ];
    return _numerar(secciones);
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
  /// contrato de trabajo, que el restaurante firma aparte según la Ley
  /// General del Trabajo: regula el uso de la cuenta y la confidencialidad
  /// de los datos de los clientes. Está personalizado con los datos de la
  /// persona, su cargo, su sucursal y las reglas internas del restaurante.
  static List<SeccionLegal> acuerdoPersonal({
    required NegocioModel? negocio,
    required UsuarioModel usuario,
    String sucursal = '',
  }) {
    final restaurante = _nombreRestaurante(negocio);
    final nit = (negocio?.nit ?? '').trim();
    final rol = usuario.rol;
    final reglas = negocio?.reglasPersonal.reglas ?? const <String>[];
    final secciones = <SeccionLegal>[
      SeccionLegal('Datos de este acuerdo', enSimple: 'Quién firma y para qué restaurante.', [
        'Restaurante: $restaurante${nit.isEmpty ? '' : ' (NIT $nit)'}.',
        'Persona: ${usuario.nombre}. Su nombre completo y su carnet de identidad se registran '
            'al firmar.',
        'Cargo: $rol${sucursal.trim().isEmpty ? '' : ', en la sucursal ${sucursal.trim()}'}.',
        if (usuario.fechaRegistro != null)
          'Usa la plataforma desde el ${_fecha(usuario.fechaRegistro!)}.',
      ]),
      const SeccionLegal('Qué regula este acuerdo',
          enSimple: 'Cómo usar tu cuenta y cuidar los datos de los clientes. No es tu contrato de trabajo.', [
        'Regula el uso de tu cuenta en la plataforma y el cuidado de la información a la que '
            'accedes por tu trabajo.',
        'No reemplaza tu contrato de trabajo ni modifica tu sueldo, horario o beneficios: esos '
            'los acuerdas con el restaurante por separado, conforme a la Ley General del Trabajo.',
        'La plataforma, ofrecida por ${AppConfig.titularPlataforma}, es la herramienta con la '
            'que el restaurante gestiona sus pedidos.',
      ]),
      const SeccionLegal('Tu cuenta',
          enSimple: 'Tu cuenta es solo tuya; lo que se hace con ella queda a tu nombre.', [
        'Tu cuenta es personal e intransferible. No compartas tu contraseña ni el código de tu '
            'app autenticadora (verificación en dos pasos).',
        'Todo lo que se hace con tu cuenta queda registrado a tu nombre: cambios de estado de '
            'los pedidos, cobros, movimientos de caja y cancelaciones con su motivo.',
        'Si pierdes tu teléfono o crees que alguien usó tu cuenta, avisa de inmediato al '
            'Administrador del restaurante.',
      ]),
      const SeccionLegal('Confidencialidad de los datos de los clientes',
          enSimple: 'Los datos de los clientes son solo para atender sus pedidos.', [
        'Por tu trabajo puedes ver nombres, teléfonos, direcciones, alergias, notas y datos de '
            'factura de los clientes. Solo puedes usarlos para atender sus pedidos.',
        'Está prohibido copiarlos, guardarlos fuera de la plataforma, compartirlos con otras '
            'personas o usarlos para contactar a los clientes por motivos que no sean su pedido.',
        'Esta obligación sigue vigente aunque dejes de trabajar en el restaurante.',
      ]),
      _tareasDelRol(rol),
      if (reglas.isNotEmpty)
        SeccionLegal('Reglas internas de ${negocio?.nombre ?? 'tu restaurante'}',
            enSimple: 'Reglas que agregó tu restaurante.', reglas),
      const SeccionLegal('Tus datos como parte del personal',
          enSimple: 'Se guarda solo lo necesario para tu trabajo y lo ve tu Administrador.', [
        'Para este acuerdo y tu trabajo en la plataforma se guardan tu nombre, correo, teléfono, '
            'carnet de identidad (en la firma), el registro de tus acciones y, si eres '
            'repartidor, tu ubicación solo mientras tienes entregas en curso. Los ve el '
            'Administrador del restaurante y se usan para operar y para resolver diferencias de '
            'caja o reclamos. Puedes pedir acceso o corrección a tu Administrador.',
      ]),
      const SeccionLegal('Fin del acuerdo',
          enSimple: 'Si dejas de trabajar aquí, tu cuenta se desactiva; la confidencialidad sigue.', [
        'Cuando termina tu relación con el restaurante, el Administrador desactiva tu cuenta y '
            'ya no podrás entrar. La obligación de confidencialidad se mantiene.',
      ]),
      SeccionLegal('Firma electrónica',
          enSimple: 'Firmas escribiendo tu nombre y carnet; queda registrado con fecha y hora.', [
        'Al escribir tu nombre completo y tu carnet de identidad y pulsar "Firmar y continuar", '
            'aceptas este acuerdo. Queda registrado con la fecha y hora del servidor y la versión '
            '${versionAcuerdo(negocio)}. Esta aceptación electrónica es válida conforme a la '
            'Ley 164; el restaurante puede pedirte además una firma en papel.',
        'Puedes descargar una copia de tu acuerdo firmado en "Mi cuenta". Si el acuerdo o las '
            'reglas del restaurante cambian, se te pedirá firmar la nueva versión.',
      ]),
    ];
    return _numerar(secciones);
  }

  /// Lo que le toca a cada rol (solo lo suyo: el cajero no lee las reglas
  /// del repartidor).
  static SeccionLegal _tareasDelRol(String rol) {
    const comun = 'Registra en la plataforma lo que realmente ocurre con cada pedido y no '
        'canceles pedidos sin un motivo verdadero.';
    return switch (rol) {
      Rol.cocina => const SeccionLegal('Lo que te toca en cocina',
            enSimple: 'Prepara respetando las alergias y marca cada pedido a tiempo.', [
          comun,
          'Respeta siempre las alergias marcadas en los pedidos. Si un ingrediente no se puede '
              'quitar, avisa antes de preparar.',
          'Marca "En preparación" cuando empiezas y "Listo" cuando termina, para que el cliente '
              'y el resto del personal sepan en qué va cada pedido.',
        ]),
      Rol.cajero => const SeccionLegal('Lo que te toca en caja',
            enSimple: 'Abre y cierra tu caja en la app y registra cada cobro con honestidad.', [
          comun,
          'Abre y cierra tu caja en la plataforma, registra cada cobro, ingreso y egreso, y '
              'cuenta el efectivo con honestidad. Los movimientos no se pueden borrar.',
          'Recibe y registra el efectivo que te entregan los repartidores, y asigna los pedidos '
              'de delivery solo a repartidores disponibles.',
        ]),
      Rol.repartidor => const SeccionLegal('Lo que te toca en reparto',
            enSimple: 'Entrega con cuidado, cobra lo que dice la app y rinde el efectivo en caja.', [
          comun,
          'Mientras tienes entregas en curso, tu ubicación se comparte con el cliente de ese '
              'pedido y se borra al entregarlo.',
          'Cobra exactamente el monto que muestra la app y entrega el efectivo en caja el mismo '
              'día, según las normas del restaurante.',
          'Trata con respeto a los clientes y no uses su teléfono ni su dirección para nada más '
              'que la entrega.',
        ]),
      _ => const SeccionLegal('Lo que te toca como administrador',
            enSimple: 'Cuidas el acceso de tu personal y que los datos del restaurante sean correctos.', [
          comun,
          'Gestionas al personal y sus permisos. Desactiva de inmediato la cuenta de quien deje '
              'de trabajar en el restaurante.',
          'Mantén correctos los precios, las promociones, los horarios y las condiciones que ven '
              'los clientes.',
        ]),
    };
  }

  /// Pone "1. ", "2. "… delante de cada título, en orden.
  static List<SeccionLegal> _numerar(List<SeccionLegal> s) => [
        for (var i = 0; i < s.length; i++)
          SeccionLegal('${i + 1}. ${s[i].titulo}', s[i].parrafos, enSimple: s[i].enSimple),
      ];
}
