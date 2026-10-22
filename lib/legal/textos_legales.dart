import '../config/app_config.dart';

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

  static List<SeccionLegal> politicaPrivacidad() => [
        SeccionLegal('1. Quién es responsable', [
          '${AppConfig.nombrePlataforma} es una plataforma ofrecida por '
              '${AppConfig.titularPlataforma} para que distintos negocios '
              'reciban y gestionen pedidos. Cada negocio aparece identificado '
              'en su ficha y es quien atiende tu pedido.',
          'Para consultas sobre tus datos puedes escribir a '
              '${AppConfig.correoPrivacidad}.',
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
          'Con proveedores técnicos que almacenan la información por '
              'nosotros: Google Firebase (cuentas y base de datos) y '
              'Cloudinary (imágenes).',
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
          'Puedes ver y corregir tu nombre y teléfono en "Mi cuenta", y '
              'eliminar tu cuenta en "Mi cuenta > Eliminar mi cuenta". Para '
              'cualquier otra solicitud sobre tus datos, escribe a '
              '${AppConfig.correoPrivacidad}.',
        ]),
        SeccionLegal('7. Seguridad', [
          'Los datos se guardan en servicios de Google Firebase con reglas '
              'de acceso por rol: tú ves tus datos y el personal de un '
              'negocio solo ve los pedidos de ese negocio. Ningún sistema es '
              'infalible, por eso te recomendamos usar una contraseña única.',
        ]),
        SeccionLegal('8. Menores de edad', [
          'La plataforma no está dirigida a menores de edad sin la '
              'supervisión de un adulto responsable.',
        ]),
        SeccionLegal('9. Cambios en esta política', [
          'Si cambiamos esta política, publicaremos la nueva versión aquí '
              'y, si el cambio es importante, te pediremos aceptarla de '
              'nuevo. Versión: ${AppConfig.versionTerminos}.',
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
        ]),
        SeccionLegal('3. Precios y pedidos', [
          'Los precios se muestran en bolivianos (Bs). El total que ves '
              'antes de confirmar tu pedido es el que corresponde pagar, '
              'incluidos los cargos que el negocio haya informado.',
          'El negocio puede rechazar o cancelar un pedido si no puede '
              'atenderlo; si ocurre, se te avisará en el estado del pedido.',
        ]),
        SeccionLegal('4. Pagos', [
          'Puedes pagar en efectivo, por transferencia o con el QR de pago '
              'del negocio, según lo que el negocio ofrezca. El pago se hace '
              'directamente al negocio: la plataforma no cobra ni retiene '
              'dinero.',
        ]),
        SeccionLegal('5. Facturas', [
          'La plataforma no emite facturas fiscales. Si necesitas factura, '
              'pídesela al negocio, que es responsable de sus propias '
              'obligaciones tributarias.',
        ]),
        SeccionLegal('6. Uso adecuado', [
          'No está permitido hacer pedidos falsos, ofender o amenazar al '
              'personal de un negocio, ni usar la plataforma para fines '
              'ilegales. El Administrador de un negocio puede bloquear tu '
              'cuenta en ese negocio si lo incumples; el bloqueo no afecta '
              'a los demás negocios.',
        ]),
        SeccionLegal('7. Responsabilidad', [
          'Cada negocio es responsable de la calidad, preparación y '
              'entrega de sus productos. La plataforma procura que el '
              'servicio esté disponible, pero no puede garantizar que no '
              'haya interrupciones.',
        ]),
        SeccionLegal('8. Reclamos', [
          'Puedes presentar tu reclamo directamente al negocio, de forma '
              'verbal o escrita y sin formalidades. Los datos de contacto '
              'de cada negocio están en su ficha, en el menú del negocio. '
              'También puedes escribir a ${AppConfig.correoPrivacidad}.',
        ]),
        SeccionLegal('9. Eliminar tu cuenta', [
          'Puedes eliminar tu cuenta en cualquier momento desde "Mi cuenta". '
              'Lo que se borra y lo que se conserva está explicado en la '
              'Política de privacidad.',
        ]),
        SeccionLegal('10. Ley aplicable', [
          'Estos términos se rigen por las leyes del Estado Plurinacional '
              'de Bolivia. Ciudad de referencia: ${AppConfig.ciudadPais}.',
        ]),
        SeccionLegal('11. Cambios', [
          'Podemos actualizar estos términos. Versión: '
              '${AppConfig.versionTerminos}.',
        ]),
      ];
}
