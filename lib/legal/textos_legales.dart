import '../config/app_config.dart';
import '../models/negocio_model.dart';
import '../models/usuario_model.dart';

/// Un apartado de un texto legal: título y uno o más párrafos.
class SeccionLegal {
  final String titulo;
  final List<String> parrafos;
  const SeccionLegal(this.titulo, this.parrafos);
}

/// Textos legales de la plataforma. Son una base redactada a partir de lo
/// que la app realmente hace; NO sustituyen la revisión de un abogado en
/// Bolivia. Si cambia el funcionamiento de la app (por ejemplo, se agrega
/// la ubicación del repartidor), hay que actualizar este archivo y subir
/// `AppConfig.versionTerminos`.
class TextosLegales {
  TextosLegales._();

  static const String tituloPolitica = 'Política de privacidad';
  static const String tituloTerminos = 'Términos y condiciones';
  static const String tituloAcuerdo = 'Acuerdo de uso y confidencialidad del personal';

  static List<SeccionLegal> politicaPrivacidad() => [
        SeccionLegal('1. Quién es responsable', [
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
        SeccionLegal('2. Qué datos recopilamos', [
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
        SeccionLegal('3. Para qué los usamos', [
          'Para crear y mantener tu cuenta, procesar y entregar tus pedidos, '
              'permitir que el negocio te contacte sobre un pedido, atender '
              'reclamos, prevenir abusos (por ejemplo, el bloqueo de cuentas '
              'por parte de un negocio) y cumplir obligaciones legales.',
        ]),
        SeccionLegal('4. Con quién los compartimos', [
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
        SeccionLegal('5. Cuánto tiempo los conservamos', [
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
        SeccionLegal('6. Tus derechos', [
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
        SeccionLegal('7. Seguridad', [
          'Los datos se guardan en servicios de Google Firebase con reglas '
              'de acceso por rol: tú ves tus datos y el personal de un '
              'negocio solo ve los pedidos de ese negocio. Ningún sistema es '
              'infalible, por eso te recomendamos usar una contraseña única.',
        ]),
        SeccionLegal('8. Menores de edad', [
          'Para crear una cuenta debes tener 18 años o más. Si eres menor de '
              'edad, solo puedes usar la plataforma con la autorización y '
              'supervisión de tu madre, padre o tutor, que es responsable de '
              'los pedidos que hagas.',
        ]),
        SeccionLegal('9. Tu consentimiento', [
          'Al marcar la casilla de aceptación al crear tu cuenta das tu '
              'consentimiento previo, expreso e informado para que tratemos '
              'tus datos como explica esta política. Tus alergias (dato de '
              'salud) solo se guardan si tú las marcas, y solo para preparar '
              'tus pedidos con seguridad.',
        ]),
        SeccionLegal('10. Cambios en esta política', [
          'Si cambiamos esta política, te pediremos aceptar la nueva versión '
              'antes de seguir usando la app. Versión: '
              '${AppConfig.versionTerminos}.',
        ]),
      ];

  static List<SeccionLegal> terminos() => [
        SeccionLegal('1. El servicio', [
          '${AppConfig.nombrePlataforma} permite hacer pedidos a negocios '
              'de comida. La plataforma conecta al cliente con el negocio; '
              'la compra se acuerda entre el cliente y el negocio, que es '
              'quien prepara y entrega el pedido.',
        ]),
        SeccionLegal('2. Tu cuenta', [
          'Debes dar datos verdaderos y mantenerlos actualizados. Eres '
              'responsable de cuidar tu contraseña y de lo que se haga con '
              'tu cuenta.',
          'Debes tener 18 años o más, o usar la plataforma con autorización y '
              'supervisión de tu madre, padre o tutor.',
        ]),
        SeccionLegal('3. Precios y pedidos', [
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
        SeccionLegal('4. Alergias', [
          'Si marcas alergias, el negocio las verá destacadas y hará lo '
              'posible por preparar tu pedido sin esos ingredientes. La '
              'información de alérgenos de cada producto la carga el negocio. '
              'Si tu alergia es grave, confirma con el local antes de comer: '
              'la plataforma no puede garantizar que no haya contacto cruzado '
              'en la cocina.',
        ]),
        SeccionLegal('5. Pagos', [
          'Puedes pagar en efectivo, por transferencia o con el QR de pago '
              'del negocio, según lo que el negocio ofrezca. El pago se hace '
              'directamente al negocio: la plataforma no cobra ni retiene '
              'dinero.',
        ]),
        SeccionLegal('6. Facturas', [
          'La plataforma no emite facturas fiscales. Si necesitas factura, '
              'marca "Quiero factura" al confirmar y escribe tu NIT o CI: esos '
              'datos llegan al negocio, que es quien emite la factura y '
              'responde por sus obligaciones tributarias.',
        ]),
        SeccionLegal('7. Uso adecuado', [
          'No está permitido hacer pedidos falsos, ofender o amenazar al '
              'personal de un negocio, publicar reseñas con insultos, datos de '
              'otras personas o contenido racista o discriminatorio (Ley 045), '
              'ni usar la plataforma para fines ilegales. El Administrador de un negocio puede bloquear tu '
              'cuenta en ese negocio si lo incumples; el bloqueo no afecta '
              'a los demás negocios.',
        ]),
        SeccionLegal('8. Responsabilidad', [
          'Cada negocio es responsable de la calidad, preparación y '
              'entrega de sus productos. La plataforma procura que el '
              'servicio esté disponible, pero no puede garantizar que no '
              'haya interrupciones.',
        ]),
        SeccionLegal('9. Reclamos', [
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
        SeccionLegal('10. Eliminar tu cuenta', [
          'Puedes eliminar tu cuenta en cualquier momento desde "Mi cuenta". '
              'Lo que se borra y lo que se conserva está explicado en la '
              'Política de privacidad.',
        ]),
        SeccionLegal('11. Ley aplicable', [
          'Estos términos se rigen por las leyes del Estado Plurinacional '
              'de Bolivia. Ciudad de referencia: ${AppConfig.ciudadPais}.',
        ]),
        SeccionLegal('12. Cambios', [
          'Si cambiamos estos términos, te pediremos aceptar la nueva versión '
              'antes de seguir usando la app; ningún cambio se aplica sin tu '
              'aceptación. Versión: ${AppConfig.versionTerminos}.',
        ]),
      ];

  /// Acuerdo que firma cada persona del personal (Administrador, Cajero,
  /// Cocina, Repartidor) al entrar por primera vez. NO reemplaza el
  /// contrato de trabajo, que el negocio firma aparte según la Ley General
  /// del Trabajo: regula el uso de la cuenta y la confidencialidad de los
  /// datos de los clientes.
  static List<SeccionLegal> acuerdoPersonal({
    required NegocioModel? negocio,
    required UsuarioModel usuario,
  }) {
    final nombreNegocio = negocio == null
        ? 'el negocio al que perteneces'
        : (negocio.razonSocial.trim().isNotEmpty ? negocio.razonSocial.trim() : negocio.nombre);
    final nit = (negocio?.nit ?? '').trim();
    final rol = usuario.rol;
    return [
      SeccionLegal('1. Partes', [
        'Este acuerdo se celebra entre $nombreNegocio'
            '${nit.isEmpty ? '' : ' (NIT $nit)'} —en adelante, "el Negocio"— '
            'y la persona que lo firma con su nombre y documento de identidad, '
            'que trabaja para el Negocio con el rol de $rol.',
        'La plataforma ${AppConfig.nombrePlataforma}, ofrecida por '
            '${AppConfig.titularPlataforma}, es la herramienta con la que el '
            'Negocio gestiona sus pedidos.',
      ]),
      const SeccionLegal('2. Qué regula este acuerdo', [
        'Regula el uso de tu cuenta en la plataforma y el cuidado de la '
            'información a la que accedes por tu trabajo.',
        'No reemplaza tu contrato de trabajo ni modifica tu sueldo, horario o '
            'beneficios: esos los acuerdas con el Negocio por separado, '
            'conforme a la Ley General del Trabajo.',
      ]),
      const SeccionLegal('3. Tu cuenta', [
        'Tu cuenta es personal e intransferible. No compartas tu contraseña '
            'ni el código de tu app autenticadora (verificación en dos pasos).',
        'Todo lo que se hace con tu cuenta queda registrado a tu nombre: '
            'cambios de estado de los pedidos, cobros, movimientos de caja y '
            'cancelaciones con su motivo.',
        'Si pierdes tu teléfono o crees que alguien usó tu cuenta, avisa de '
            'inmediato al Administrador del Negocio.',
      ]),
      const SeccionLegal('4. Confidencialidad de los datos de los clientes', [
        'Por tu trabajo puedes ver nombres, teléfonos, direcciones, alergias, '
            'notas y datos de factura de los clientes. Solo puedes usarlos para '
            'atender sus pedidos.',
        'Está prohibido copiarlos, guardarlos fuera de la plataforma, '
            'compartirlos con otras personas o usarlos para contactar a los '
            'clientes por motivos que no sean su pedido.',
        'Esta obligación sigue vigente aunque dejes de trabajar en el Negocio.',
      ]),
      SeccionLegal('5. Responsabilidades de tu rol', [
        'Registra en la plataforma lo que realmente ocurre con cada pedido y '
            'no canceles pedidos sin un motivo verdadero.',
        if (rol == Rol.cocina || rol == Rol.administrador)
          'Cocina: respeta las alergias marcadas en los pedidos. Si un '
              'ingrediente no se puede quitar, avisa antes de preparar.',
        if (rol == Rol.cajero || rol == Rol.administrador)
          'Caja: abre y cierra tu caja en la plataforma, registra cada cobro, '
              'ingreso y egreso, y cuenta el efectivo con honestidad. Los '
              'movimientos no se pueden borrar.',
        if (rol == Rol.repartidor || rol == Rol.administrador)
          'Reparto: mientras tienes entregas en curso, tu ubicación se comparte '
              'con el cliente de ese pedido y se borra al entregarlo. Entrega '
              'el dinero cobrado según las normas del Negocio.',
        if (rol == Rol.administrador)
          'Administración: gestionas al personal y los datos del Negocio. '
              'Desactiva la cuenta de quien deje de trabajar en el Negocio.',
      ]),
      const SeccionLegal('6. Tus datos como parte del personal', [
        'Para este acuerdo y tu trabajo en la plataforma se guardan tu nombre, '
            'correo, teléfono, documento de identidad (en la firma), el '
            'registro de tus acciones y, si eres repartidor, tu ubicación solo '
            'mientras tienes entregas en curso. Los ve el Administrador del '
            'Negocio y se usan para operar y para resolver diferencias de caja '
            'o reclamos. Puedes pedir acceso o corrección a tu Administrador.',
      ]),
      const SeccionLegal('7. Fin del acuerdo', [
        'Cuando termina tu relación con el Negocio, el Administrador desactiva '
            'tu cuenta y ya no podrás entrar. La obligación de confidencialidad '
            'se mantiene.',
      ]),
      SeccionLegal('8. Firma electrónica', [
        'Al escribir tu nombre completo y tu documento de identidad y pulsar '
            '"Firmar y continuar", aceptas este acuerdo. Queda registrado con la '
            'fecha y hora del servidor y la versión ${AppConfig.versionAcuerdoPersonal}. '
            'Esta aceptación electrónica es válida conforme a la Ley 164; el '
            'Negocio puede pedirte además una firma en papel.',
        'Si el acuerdo cambia, se te pedirá firmar la nueva versión.',
      ]),
    ];
  }
}
