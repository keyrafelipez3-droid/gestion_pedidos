# Caro · Pedidos de comida

[![CI](https://github.com/keyrafelipez3-droid/gestion_pedidos/actions/workflows/ci.yml/badge.svg)](https://github.com/keyrafelipez3-droid/gestion_pedidos/actions/workflows/ci.yml)

Plataforma **multi-negocio** para tomar y gestionar pedidos de comida: menú digital, pedidos en mesa, para recoger o a domicilio, cocina, caja, reparto con seguimiento en mapa y panel de administración. Desarrollada con **Flutter** y **Firebase** en Cochabamba, Bolivia.

**Pruébala:** <https://gestion-pedidos-univalle.web.app> (web) · APK para Android.

Autoras: Alaitz Keyra Felipez Ledezma y Susan Dilana Romero Valdez.

## Qué hace

| Rol | Funciones principales |
|---|---|
| **Cliente** | Menú con fotos y alérgenos, carrito, pedido en mesa, para recoger o delivery (por zonas con costo de envío), pedidos programados, cupones, propina, datos de factura (NIT), pago en efectivo, transferencia o QR, seguimiento en vivo con mapa, avisos de estado, "volver a pedir", reseñas. App en español, inglés, portugués y francés. |
| **Cocina** | Lista y **tablero para tablet** con tiempo de espera por colores, alergias resaltadas, notas traducidas automáticamente y **comanda para impresora térmica** (sin precios). |
| **Cajero** | Pedidos recibidos, mesas, caja con cierre ciego, cobros y **rendición del efectivo de los repartidores**. |
| **Repartidor** | Toma pedidos listos, comparte su ubicación, ve lo que debe cobrar y entregar en caja, y sus propinas del día. |
| **Administrador** | Sucursales, horarios, zonas de delivery, catálogo con stock, empleados, **permisos ajustables por rol**, clientes, reseñas, cupones, ventas con exportación a **Excel**, registro de actividad. |
| **SuperAdmin** | Negocios, personalización de marca, **solicitudes de restaurantes nuevos**, versiones de la app (aviso de actualización) y errores de la app. |

## Seguridad

- Reglas de Firestore por rol y por negocio (multi-tenant): cada escritura valida **quién** y **qué campos**; el servidor rechaza precios de envío alterados, descuentos mayores al cupón, estados inventados, etc.
- Verificación en dos pasos (TOTP) obligatoria para el personal, contraseñas fuertes, cierre por inactividad, confirmación de identidad para acciones sensibles, verificación de correo para clientes.
- Acuerdo de confidencialidad firmado por el personal y aceptación de términos por los clientes, con versión y fecha del servidor.
- Registro de actividad que no se puede editar ni borrar.

## Calidad

- **Pruebas automáticas:** unas 50 pruebas en Dart (`test/`) y 60 pruebas de las reglas de seguridad (más de 120 comprobaciones) en el emulador de Firestore (`test_reglas/`).
- **Integración continua:** GitHub Actions ejecuta en cada Pull Request el análisis, las pruebas, la compilación web y las pruebas de reglas (`.github/workflows/ci.yml`).
- Modo sin conexión, registro automático de errores y listas que se cargan por partes.

## Tecnología

- Flutter (Material 3) · Dart 3.9
- Firebase: Authentication (con MFA), Cloud Firestore, Hosting, App Check (preparado)
- flutter_map + OpenStreetMap, geolocator, url_launcher, phone_numbers_parser, archive (Excel)
- Funciona con el **plan gratuito** de Firebase. Las funciones de servidor que necesitan el plan Blaze ya están escritas en `functions/` y se activan cuando haga falta (ver `functions/README.md`).

## Cómo ejecutarla

1. Instala Flutter estable y verifica con `flutter doctor`.
2. `flutter pub get`
3. La configuración de Firebase del proyecto `gestion-pedidos-univalle` ya está incluida (`lib/firebase_options.dart`). Para otro proyecto: `flutterfire configure`.
4. Publica reglas e índices: `firebase deploy --only firestore`
5. `flutter run -d chrome` (o el dispositivo que prefieras).

**Pruebas:** `flutter test` · reglas: `cd test_reglas && npm install && npm test` (necesita Node 24 y Java 21).

**Publicar la web:** `flutter build web --release` y `firebase deploy --only hosting`.

**APK firmada:** crea `android/key.properties` con los datos de tu llave (nunca se sube a GitHub) y ejecuta `flutter build apk --release`.

**Copia de seguridad:** `cd scripts/respaldo && npm install && node respaldo.js ruta/a/serviceAccountKey.json`.

## Estructura

```
lib/
  config/      datos de la plataforma (AppConfig)
  l10n/        traducciones (es, en, pt, fr)
  legal/       términos, privacidad y acuerdo del personal
  models/      modelos de datos
  screens/     pantallas por rol (cliente, cajero, cocina, repartidor, admin, superadmin, cuenta)
  services/    acceso a Firebase y lógica de negocio
  theme/       tokens de diseño y marca
  utils/       utilidades (teléfonos, reportes, formato, comanda)
  widgets/     componentes reutilizables
test/              pruebas unitarias (Dart)
test_reglas/       pruebas de las reglas de seguridad (emulador)
functions/         funciones del servidor (preparadas para el plan Blaze)
scripts/respaldo/  copia de seguridad de Firestore
firestore.rules / firestore.indexes.json
```

## Flujo de trabajo con Git

Ramas `feature/...` o `fix/...` desde `develop`, Pull Request a `develop` con las revisiones de CI en verde, y luego `develop` → `main`. No se hace commit directo a `main` ni a `develop`.

## Antes de vender a un negocio

- Cambiar OpenStreetMap/Nominatim por un proveedor de mapas con licencia comercial (constantes en `lib/config/app_config.dart`).
- Revisión de los textos legales por un abogado y de la facturación por un contador.
- Restringir la clave de API de Firebase y activar App Check.
- Pasar al plan Blaze para notificaciones push y validación de totales en el servidor (`functions/`).
