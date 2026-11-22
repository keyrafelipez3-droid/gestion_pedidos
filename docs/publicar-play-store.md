# Publicar Nami en Google Play

## Antes de empezar: decidir el identificador

El paquete actual es `com.univalle.gestion_pedidos`. **No se puede cambiar después de publicar.** Si se quiere otro (por ejemplo uno con "nami"), hay que cambiarlo antes de la primera subida, en `android/app/build.gradle.kts` y en Firebase (registrar la app Android nueva y bajar su `google-services.json`).

## 1. Crear la llave de subida (una sola vez)

En una terminal (necesita Java). Las contraseñas las eliges tú y no se comparten:

```
keytool -genkey -v -keystore D:\llaves\nami-subida.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nami
```

Guarda una copia del `.jks` y de las contraseñas en un lugar seguro. Si se pierde, hay que pedir a Google un cambio de llave.

## 2. Crear `android/key.properties`

```
storePassword=TU_CONTRASEÑA
keyPassword=TU_CONTRASEÑA
keyAlias=nami
storeFile=D:\\llaves\\nami-subida.jks
```

Este archivo ya está en `android/.gitignore`, igual que los `.keystore`. `build.gradle.kts` ya lo usa: si existe, firma con tu llave; si no, firma con la de pruebas.

## 3. Compilar

- Para Google Play (paquete AAB): `flutter build appbundle --release`
- Para instalar a mano (APK por procesador): `flutter build apk --release --split-per-abi`

Sube el número de versión en `pubspec.yaml` (`version: 1.0.0+1` → `1.0.1+2`) cada vez que publiques.

## 4. Play Console

1. Crea la app y activa **Firma de apps de Play** (Google guarda la llave final).
2. Sube el `.aab` a una prueba interna primero.
3. Copia la huella SHA-1 y SHA-256 de la firma de Play (Configuración → Integridad de la app) y agrégalas en Firebase (Configuración del proyecto → app Android) y en la restricción de la llave de API.

## 5. Formulario de Seguridad de los datos

| Pregunta | Respuesta para Nami |
|---|---|
| ¿Recolecta datos? | Sí |
| Datos personales | Nombre, correo, teléfono, dirección |
| Ubicación | Precisa y aproximada (para la dirección de entrega en el mapa) |
| Historial de compras | Sí (pedidos) |
| Datos financieros | NIT y razón social si pide factura. No se guardan tarjetas |
| ¿Se comparten con terceros? | No se venden. El restaurante donde pides ve los datos de tu pedido |
| Cifrado en tránsito | Sí (Firebase usa HTTPS) |
| ¿El usuario puede pedir que se borren? | Sí, desde la app y en https://gestion-pedidos-univalle.web.app/eliminar-cuenta.html |

Revisa esta tabla con el abogado antes de enviarla (ver `revision-abogado.md`).

Política de privacidad: Play pide una URL pública. Publica el texto de `lib/legal/textos_legales.dart` en una página de la web (igual que `eliminar-cuenta.html`) antes de enviar la app.
