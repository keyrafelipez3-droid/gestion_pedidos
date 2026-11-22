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

  static List<String> resumenTerminos() => [
        'La plataforma es la herramienta; el restaurante prepara y entrega tu pedido.',
        'Antes de confirmar ves el total exacto: no hay cobros escondidos.',
        'Le pagas directamente al restaurante.',
        'Marca tus alergias; si son graves, confirma con el local.',
        'Si tienes un problema, reclama primero al restaurante; si no se resuelve, a '
            '${Paises.actual.autoridadConsumidor}.',
      ];

  static List<SeccionLegal> politicaPrivacidad() {
    final p = Paises.actual;
    return [
        SeccionLegal('1. Quién es responsable', enSimple: 'La plataforma es la herramienta; el restaurante atiende tu pedido. Si tienes dudas sobre tus datos, escríbenos.', [
          '${AppConfig.nombrePlataforma} es una plataforma ofrecida por '
              '${AppConfig.titularPlataforma} para que distintos negocios '
              'reciban y gestionen pedidos. Cada negocio aparece identificado '
              'en su ficha y es quien atiende tu pedido.',
          'Responsable del tratamiento de tus datos: '
              '${AppConfig.titularPlataforma}, con domicilio en '
              '${AppConfig.ciudadPais}. Para consultas sobre tus datos escribe a '
              '${AppConfig.correoPrivacidad}.',
          'Esta política sigue lo que exige ${p.leyDatos}, en ${p.nombre}: '
              'pedir tu consentimiento, decirte para qué usamos tus datos y '
              'respetar tus derechos sobre ellos.',
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
          'Datos para factura: si pides factura, tu número tributario o documento y la razón social '
              'se guardan en el pedido para el negocio y, para no volver a '
              'escribirlos, en tu dispositivo.',
          'Idioma, tamaño de letra, avisos y si ya viste el aviso de almacenamiento: se guardan '
              'solo en tu dispositivo (ver "Cookies y almacenamiento").',
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
              'nosotros (servicios de terceros):',
          '• Google Firebase (Google LLC): cuentas, base de datos, verificación '
              'de que la app es auténtica (App Check) y alojamiento de la web.',
          '• Cloudinary: guarda las imágenes (fotos de productos, de perfil y '
              'comprobantes).',
          '• OpenStreetMap y su buscador Nominatim: muestran el mapa y buscan '
              'direcciones; reciben el texto de la dirección que buscas y tu '
              'dirección IP.',
          '• MyMemory (Translated): traduce notas cuando usas la app en otro '
              'idioma (ver más abajo).',
          '• Google Fonts: algunas tipografías de los restaurantes se descargan '
              'de los servidores de Google, que reciben tu dirección IP.',
          'Estos proveedores pueden tener sus servidores fuera de tu país (por '
              'ejemplo, en Estados Unidos o Europa). Al aceptar esta política '
              'aceptas que tus datos se guarden allí, con las medidas de '
              'seguridad de esos proveedores.',
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
          'En ${p.nombre}, ${p.leyDatos} reconoce tu derecho a la privacidad y '
              'a conocer, corregir y eliminar tus datos personales.',
          'Tienes derecho a: conocer qué datos tuyos tenemos (acceso), '
              'corregirlos (rectificación), pedir que los borremos '
              '(cancelación), oponerte a un uso concreto (oposición) y retirar '
              'tu consentimiento en cualquier momento. Retirarlo no afecta lo '
              'que se hizo antes con tu autorización.',
          'Puedes ver y corregir tu nombre y teléfono en "Mi cuenta", y '
              'eliminar tu cuenta en "Mi cuenta > Eliminar mi cuenta". Para '
              'cualquier otra solicitud escribe a ${AppConfig.correoPrivacidad}: '
              'te responderemos en un plazo máximo de 10 días hábiles.',
          if (p.codigo == 'BO')
            'Si consideras que tus datos se usan de forma indebida, también '
                'puedes presentar una Acción de Protección de Privacidad ante un '
                'juez (Constitución, arts. 130 y 131).'
          else if (p.autoridadDatos.isNotEmpty)
            'Si consideras que tus datos se usan de forma indebida, también '
                'puedes presentar una queja ante ${p.autoridadDatos}.',
          ...p.notas.where((n) => !n.contains('menú') && !n.contains('impuestos')),
        ]),
        SeccionLegal('7. Seguridad', enSimple: 'Cada persona ve solo lo que le corresponde.', [
          'Los datos se guardan en servicios de Google Firebase con reglas '
              'de acceso por rol: tú ves tus datos y el personal de un '
              'negocio solo ve los pedidos de ese negocio. Ningún sistema es '
              'infalible, por eso te recomendamos usar una contraseña única.',
        ]),
        SeccionLegal('8. Menores de edad', enSimple: 'Necesitas 18 años, o el permiso de tu madre, padre o tutor. Menores de 13, no.', [
          'Para crear una cuenta debes tener 18 años o más. Si eres menor de '
              'edad, solo puedes usar la plataforma con la autorización y '
              'supervisión de tu madre, padre o tutor, que es responsable de '
              'los pedidos que hagas.',
          'La plataforma no está dirigida a menores de 13 años y no recopila '
              'a sabiendas sus datos. Si descubrimos una cuenta de un menor de 13 '
              'años, la eliminamos.',
        ]),
        const SeccionLegal('9. Cookies y almacenamiento',
            enSimple: 'Solo guardamos en tu dispositivo lo necesario para que la app funcione. Nada de publicidad.', [
          'La app guarda en tu navegador o en tu teléfono solo lo necesario para '
              'funcionar: tu sesión (para no pedirte la contraseña cada vez), tu '
              'idioma, el tamaño de letra, tus datos de factura si los recuerdas y '
              'si ya viste el aviso de almacenamiento.',
          'No usamos cookies de publicidad ni de seguimiento, ni herramientas de '
              'analítica de terceros. Por eso no te pedimos elegir cookies: solo te '
              'avisamos.',
          'Puedes borrar estos datos cuando quieras desde la configuración de tu '
              'navegador o cerrando sesión; la app volverá a pedirte entrar.',
        ]),
        SeccionLegal('10. Tu consentimiento', enSimple: 'Al aceptar, nos autorizas a usar tus datos como dice esta política.', [
          'Al marcar la casilla de aceptación al crear tu cuenta das tu '
              'consentimiento previo, expreso e informado para que tratemos '
              'tus datos como explica esta política. Tus alergias (dato de '
              'salud) solo se guardan si tú las marcas, y solo para preparar '
              'tus pedidos con seguridad.',
        ]),
        SeccionLegal('11. Cambios en esta política', enSimple: 'Si algo cambia, te avisamos y te pedimos aceptar de nuevo.', [
          'Si cambiamos esta política, te pediremos aceptar la nueva versión '
              'antes de seguir usando la app. Versión: '
              '${AppConfig.versionTerminos}.',
        ]),
      ];
  }

  static List<SeccionLegal> terminos() {
    final p = Paises.actual;
    return [
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
          'Los precios se muestran en ${p.nombreMoneda} (${p.simbolo}) '
              '${p.impuestosIncluidos ? 'e incluyen los impuestos' : 'sin los impuestos de venta, que se suman al cobrar según tu zona'}. '
              'Antes de confirmar ves el detalle completo: productos, descuento, '
              'costo de envío según tu zona y propina. El total que ves es el '
              'que corresponde pagar; no hay cobros ocultos, como exige '
              '${p.leyConsumidor}.',
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
          p.idFactura.isEmpty
              ? 'La plataforma no emite facturas ni recibos fiscales. El negocio '
                  'te entrega el comprobante de compra que corresponda y responde '
                  'por sus obligaciones tributarias.'
              : 'La plataforma no emite facturas fiscales. Si necesitas factura, '
                  'marca "Quiero factura" al confirmar y escribe tu ${p.idFactura}: '
                  'esos datos llegan al negocio, que es quien emite la factura y '
                  'responde por sus obligaciones tributarias.',
        ]),
        SeccionLegal('7. Uso adecuado', enSimple: 'Trata con respeto al personal y no hagas pedidos falsos.', [
          'No está permitido hacer pedidos falsos, ofender o amenazar al '
              'personal de un negocio, publicar reseñas con insultos, datos de '
              'otras personas o contenido racista o discriminatorio'
              '${p.codigo == 'BO' ? ' (Ley 045)' : ''}, '
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
        SeccionLegal('9. Reclamos', enSimple: 'Primero reclama al restaurante; si no se resuelve, puedes acudir a ${p.autoridadConsumidor}.', [
          'Puedes presentar tu reclamo directamente al negocio, de forma '
              'verbal o escrita y sin formalidades. Los datos de contacto '
              'de cada negocio están en su ficha, en el menú del negocio. '
              'Para reclamos sobre la plataforma escribe a '
              '${AppConfig.correoPrivacidad}: te responderemos en un plazo '
              'máximo de 10 días hábiles.',
          'Si tu reclamo no se resuelve, puedes acudir a ${p.autoridadConsumidor}, '
              'conforme a ${p.leyConsumidor}. Presentar un reclamo ante la autoridad '
              'de consumo suele ser gratuito y no necesita abogado.',
          if (p.codigo == 'PE')
            'En Perú, el restaurante debe tener un Libro de Reclamaciones a tu '
                'disposición, también en versión virtual.',
        ]),
        SeccionLegal('10. Eliminar tu cuenta', enSimple: 'Puedes borrar tu cuenta cuando quieras.', [
          'Puedes eliminar tu cuenta en cualquier momento desde "Mi cuenta". '
              'Lo que se borra y lo que se conserva está explicado en la '
              'Política de privacidad.',
        ]),
        SeccionLegal('11. Ley aplicable', enSimple: 'Aplican las leyes de ${p.nombre}, donde está tu restaurante.', [
          'Tus pedidos se rigen por las leyes de ${p.nombre}, el país del '
              'restaurante donde pides, sin quitarte los derechos que te den las '
              'leyes de tu país como consumidor.',
          'La plataforma tiene su domicilio en ${AppConfig.ciudadPais}.',
        ]),
        SeccionLegal('12. Cambios', enSimple: 'Ningún cambio vale sin que lo aceptes.', [
          'Si cambiamos estos términos, te pediremos aceptar la nueva versión '
              'antes de seguir usando la app; ningún cambio se aplica sin tu '
              'aceptación. Versión: ${AppConfig.versionTerminos}.',
        ]),
      ];
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

  /// Condiciones que cada restaurante ofrece a sus clientes. Combinan los
  /// datos del restaurante con lo que la app realmente permite hacer.
  static List<SeccionLegal> condicionesRestaurante(NegocioModel n) {
    final c = n.condiciones;
    final p = n.datosPais;
    final nit = n.nit.trim();
    final direccion = [n.direccion.trim(), n.ciudad.trim()].where((e) => e.isNotEmpty).join(', ');
    final secciones = <SeccionLegal>[
      SeccionLegal('Quién te vende', enSimple: 'Le compras a ${n.nombre}, no a la plataforma.', [
        'El restaurante que prepara y entrega tu pedido es ${_vendedor(n)}'
            '${nit.isEmpty ? '' : ' (${p.idFiscal} $nit)'}'
            '${direccion.isEmpty ? '' : ', con dirección en $direccion'}, en ${p.nombre}.',
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
        'Los precios están en ${p.nombreMoneda} (${p.simbolo}) '
            '${p.impuestosIncluidos ? 'e incluyen los impuestos' : 'sin los impuestos de venta, que se suman al cobrar'}. '
            'Si un producto está en promoción, se te cobra el precio de promoción mientras esté vigente.',
        'Antes de confirmar ves el detalle completo: productos, descuentos, costo de envío y '
            'propina. Ese total es lo que pagas; no hay cobros ocultos, como exige ${p.leyConsumidor}.',
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
      if (p.idFactura.isNotEmpty)
        SeccionLegal('Facturas', enSimple: 'Si quieres factura, pídela al confirmar.', [
          'Si necesitas factura, marca "Quiero factura" al confirmar y escribe tu ${p.idFactura}. '
              'La factura la emite el restaurante.',
        ]),
      SeccionLegal('Reclamos', enSimple: 'Reclama a ${contactoReclamos(n)}.', [
        'Presenta tu reclamo a ${contactoReclamos(n)}, de forma verbal o escrita y sin '
            'formalidades. El restaurante debe responderte en un plazo máximo de 10 días hábiles.',
        'Si no se resuelve, puedes acudir a ${p.autoridadConsumidor} (${Pais.sinArticulo(p.leyConsumidor)}).',
        if (p.codigo == 'PE')
          'También puedes dejar tu reclamo en el Libro de Reclamaciones del restaurante.',
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
          enSimple: 'Firmas con tu nombre y documento; queda registrado con fecha y hora.', [
        'LA PERSONA FIRMANTE acepta el presente acuerdo al escribir su nombre completo y su '
            '${p.docIdentidad} y pulsar "Firmar y continuar". La aceptación queda registrada con '
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

  /// Pone "PRIMERA.- (…)", "SEGUNDA.- (…)"… como en los acuerdos formales.
  static List<SeccionLegal> _numerarClausulas(List<SeccionLegal> s) => [
        for (var i = 0; i < s.length; i++)
          SeccionLegal('${_ordinales[i]}.- (${s[i].titulo})', s[i].parrafos, enSimple: s[i].enSimple),
      ];

  /// Pone "1. ", "2. "… delante de cada título, en orden.
  static List<SeccionLegal> _numerar(List<SeccionLegal> s) => [
        for (var i = 0; i < s.length; i++)
          SeccionLegal('${i + 1}. ${s[i].titulo}', s[i].parrafos, enSimple: s[i].enSimple),
      ];
}
