# Guía de consola: App Check, llaves y plan

Todo esto se hace en la consola, no en el código (salvo App Check, que también necesita un cambio en `app_config.dart`).

## 1. App Check (protección contra bots)

Web:

1. En https://www.google.com/recaptcha/admin crea un sitio **reCAPTCHA v3** con los dominios `gestion-pedidos-univalle.web.app`, `gestion-pedidos-univalle.firebaseapp.com` y `localhost`.
2. Firebase Console → App Check → Apps → app web → reCAPTCHA v3 → pega la **clave secreta**.
3. En `lib/config/app_config.dart` pon la **clave del sitio** en `appCheckClaveWeb` y vuelve a publicar la web.

Android:

- Play Integrity solo funciona con la app publicada en Google Play. Con una APK instalada a mano deja `appCheckAndroid = false`.
- Cuando esté en Play: App Check → app Android → Play Integrity, registra la huella SHA-256 de la firma de Play y pon `appCheckAndroid = true`.

Activar:

- App Check → APIs → Cloud Firestore: déjalo varios días en **Supervisar**.
- Pulsa **Aplicar** solo cuando casi el 100 % de las solicitudes sean verificadas. Si algo falla, vuelve a Supervisar.

## 2. Restringir las llaves de API

Google Cloud Console (proyecto gestion-pedidos-univalle) → APIs y servicios → Credenciales.

- **Llave del navegador** (web): Restricciones de aplicación → Sitios web. Agrega:
  - `https://gestion-pedidos-univalle.web.app/*`
  - `https://gestion-pedidos-univalle.firebaseapp.com/*`
  - `http://localhost/*` (solo si se sigue probando en local)
- **Llave de Android**: Restricciones → Apps de Android → paquete `com.univalle.gestion_pedidos` y la huella SHA-1 (de la llave de subida y de la de Play).
- Restricciones de API (opcional, con cuidado): deja solo Identity Toolkit, Token Service, Cloud Firestore, Firebase Installations y Firebase App Check. Prueba entrar y hacer un pedido después de cada cambio.

Estas llaves no son secretas (van dentro de la app); la restricción evita que otros las usen desde otro sitio.

## 3. Rotar la llave de servicio (antes de entregar)

1. Firebase Console → Configuración del proyecto → Cuentas de servicio → **Generar nueva clave privada**.
2. Guarda el archivo nuevo fuera de la carpeta del proyecto o en `Claude outputs` (nunca en Git).
3. Google Cloud Console → IAM → Cuentas de servicio → `firebase-adminsdk-...` → Claves → **borra la clave antigua**.
4. Prueba un script (por ejemplo `node datos_demo.js --listar`) con la llave nueva.

Entrega la llave nueva a la dueña por un medio privado y bórrala de tu equipo si ya no la necesitas.

## 4. Plan Blaze con alertas (solo si las dueñas lo deciden)

Blaze permite Cloud Functions y SMS, pero cobra por uso. Si se decide:

1. Firebase Console → Uso y facturación → Cambiar a Blaze → vincula una cuenta de facturación.
2. Google Cloud Console → Facturación → Presupuestos y alertas → crea un presupuesto bajo (por ejemplo 5 USD) con alertas al 50 %, 90 % y 100 %.
3. Las alertas solo avisan, no detienen el gasto. Revisa el uso cada semana.
4. Recién ahí se pueden desplegar las funciones de `functions/`.
