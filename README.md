# Caro · Pedidos de comida

Aplicación multi-negocio para tomar y gestionar pedidos de comida: menú digital para el cliente, pedidos en mesa, para recoger o a domicilio, cocina, caja y reparto con seguimiento en mapa. Proyecto académico de UNIVALLE (Cochabamba, Bolivia), desarrollado con Flutter y Firebase.

## Qué hace

- **Cliente:** elige un negocio, mira el menú con fotos, marca favoritos, arma su carrito y confirma el pedido (en mesa, para recoger o delivery). Paga en efectivo, por transferencia o con el QR del negocio, y sigue el estado del pedido; en delivery ve al repartidor en el mapa. Puede dejar una reseña de pedidos entregados.
- **Cajero:** recibe los pedidos, atiende mesas y maneja su caja (apertura, cobros, ingresos, egresos y cierre).
- **Cocina:** ve los pedidos pendientes y los marca como en preparación o listos.
- **Repartidor:** toma pedidos de delivery listos, comparte su ubicación mientras va en camino, llama al cliente y marca la entrega.
- **Administrador (de un negocio):** gestiona sucursales y horarios, catálogo, empleados, clientes (con bloqueo por negocio), reseñas (con moderación) y consulta ventas del día y del historial.
- **SuperAdmin:** crea negocios, los personaliza (logo, banner, colores) y designa a su administrador.

Cada negocio usa su propio color de marca en la app. Los horarios de la sucursal se respetan: fuera de horario no se pueden hacer pedidos.

## Tecnología

- Flutter (Material 3) con Dart 3.9
- Firebase Authentication y Cloud Firestore (reglas de seguridad por rol y por negocio)
- flutter_map y OpenStreetMap para direcciones y seguimiento, geolocator, url_launcher y phone_numbers_parser
- Tipografía Poppins incluida como archivos (licencia SIL OFL, ver `assets/fonts/OFL.txt`)

No usa Cloud Functions: toda la lógica corre en la app y la seguridad depende de las reglas de Firestore.

## Cómo ejecutarla

1. Instala Flutter (versión estable reciente) y verifica con `flutter doctor`.
2. Clona el repositorio y ejecuta `flutter pub get`.
3. El proyecto ya incluye la configuración de Firebase (`lib/firebase_options.dart`) del proyecto `gestion-pedidos-univalle`. Si usas otro proyecto de Firebase, genera tu configuración con `flutterfire configure`.
4. Publica las reglas e índices de Firestore (desde la consola de Firebase, o con `firebase deploy --only firestore:rules,firestore:indexes`): archivos `firestore.rules` y `firestore.indexes.json`.
5. Ejecuta `flutter run -d chrome` (o el dispositivo que prefieras).

## Estructura del proyecto

```
lib/
  config/      datos de la plataforma (AppConfig)
  legal/       términos y política de privacidad
  models/      modelos de datos
  screens/     pantallas, agrupadas por rol (cliente, cajero, cocina, repartidor, admin, superadmin)
  services/    acceso a Firebase y lógica de negocio
  theme/       tokens de diseño y marca
  utils/       utilidades (teléfonos, colores, errores, formato)
  widgets/     componentes reutilizables
assets/        imágenes y fuentes
firestore.rules / firestore.indexes.json   seguridad e índices de Firestore
```

## Flujo de trabajo con Git

Se trabaja en ramas `feature/...` o `fix/...` que salen de `develop` y vuelven por Pull Request. No se hace commit directo a `main` ni a `develop`.

## Pendiente antes de publicar

- Reemplazar OpenStreetMap/Nominatim por un proveedor de mapas y búsqueda con licencia comercial (las constantes están en `lib/config/app_config.dart`); el servicio público de OpenStreetMap es solo para desarrollo.
- Completar los datos legales de la plataforma en `lib/config/app_config.dart` (titular, correo de privacidad, enlace de eliminación de cuenta) y que un abogado revise los textos legales.
- Consultar a un contador sobre facturación y obligaciones tributarias.
- Restringir la clave de API de Firebase y el preset de subida de imágenes.
- Las notificaciones push y el rastreo con la app cerrada requieren Cloud Functions (plan Blaze de Firebase) y servicios en segundo plano; hoy el seguimiento solo funciona con la app abierta.
- Configurar la firma de la app para publicar en tiendas.
