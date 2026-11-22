# Manual técnico de Nami

## Arquitectura

- **App**: Flutter (web, Android). Código en `lib/`:
  - `config/` constantes (`app_config.dart`: nombre, URLs, App Check, correo de privacidad).
  - `models/` modelos (`pedido_models.dart`, etc.).
  - `services/` acceso a Firebase, un servicio por tema (pedidos, cupones, caja, auth...).
  - `screens/` pantallas por rol: `cliente`, `cajero`, `cocina`, `repartidor`, `admin`, `superadmin`, `cuenta`.
  - `l10n/` traducciones (en, pt, fr). La función `tr('texto en español')` traduce.
  - `legal/` textos legales y acuerdo del personal.
- **Backend**: Firebase en plan Spark (gratuito).
  - Authentication (correo y contraseña, verificación en dos pasos TOTP).
  - Cloud Firestore (base de datos) con `firestore.rules` y `firestore.indexes.json`.
  - Hosting (versión web, carpeta `build/web`).
  - `functions/` tiene funciones escritas pero **no desplegadas** (necesitan Blaze).

## Datos principales en Firestore

| Ruta | Contenido |
|---|---|
| `usuarios/{uid}` | Perfil, rol, negocio. Subcolecciones: direcciones, favoritos, `misNegocios` |
| `negocios/{id}` | Restaurante. Subcolecciones: sucursales, productos, categorías, cupones, clientes, mesas, cajas, horarios, reseñas, actividad |
| `negocios/{id}/cupones/{codigo}/usos/{uid}` | Marca que el cliente ya usó el cupón |
| `pedidos/{id}` | Pedido sin datos personales. Subcolecciones: `detalle`, `historialEstados` |
| `pedidos/{id}/privado/contacto` | Dirección, teléfono, NIT y razón social del cliente |
| `solicitudesNegocio/{uid}` | Pedido de alta de un restaurante |
| `plataforma/...` | Versión mínima, errores de la app |

## Reglas de seguridad (resumen)

- Cada rol solo lee y escribe lo de su negocio y su sucursal.
- El Administrador y el SuperAdmin deben entrar con el segundo paso (`sign_in_second_factor`).
- La cocina no puede leer `privado/contacto`. El repartidor solo mientras el pedido está Listo, En camino o En el lugar.
- Los clientes no pueden listar cupones (solo consultar uno por código), y cada cupón es de un solo uso por cliente.
- Los pedidos se validan al crearlos: precios, totales, cupón y control de cantidad.
- Al eliminar una cuenta se limpian los datos personales de sus pedidos terminados.

Las reglas no son filtros: cada consulta de la app debe llevar los mismos filtros que piden las reglas.

## Pruebas

```
flutter analyze
flutter test
cd test_reglas
npm test          (necesita Java 11 o más; probado con Java 23)
```

## Despliegue

```
flutter build web --release
firebase deploy --only firestore:rules,firestore:indexes,hosting --project gestion-pedidos-univalle
flutter build apk --release --split-per-abi
```

Cuando cambian las reglas de pedidos, publica juntas las reglas, la web y la APK nueva: una APK vieja no puede crear pedidos con reglas nuevas.

## Scripts (`scripts/`)

Todos necesitan `npm install` la primera vez y la llave de servicio.

| Script | Uso |
|---|---|
| `respaldo/respaldo.js` | `node respaldo.js ruta\serviceAccountKey.json` copia toda la base a JSON. Guarda la copia en un lugar seguro: tiene datos personales |
| `demo/datos_demo.js` | Datos de demostración. `--listar`, `--refrescar --negocio principal`, `--mover-fechas` |
| `migracion-seguridad/migrar-privacidad.js` | Mueve los datos de contacto de pedidos antiguos a `privado/contacto`. Sin `--aplicar` solo muestra lo que haría |

Límites del plan gratuito: 50.000 lecturas y 20.000 escrituras por día. No corras dos scripts grandes el mismo día.

## Respaldo y recuperación

1. Haz un respaldo antes de cada despliegue grande.
2. Si unas reglas nuevas fallan, vuelve a publicar las anteriores desde Firebase Console → Firestore → Reglas → historial.
3. Si se pierde un dato, búscalo en el último respaldo y vuelve a crearlo a mano o con un script.
