# Manual de usuario de Nami

Nami funciona en la web (https://gestion-pedidos-univalle.web.app) y en Android.
Cada persona ve solo las pantallas de su rol.

## Para todos: Mi cuenta

- **Cambiar idioma y tema**: desde Mi cuenta. El panel del personal está solo en español.
- **Verificación en dos pasos**: se activa con una app autenticadora (Google Authenticator, Microsoft Authenticator u otra). Es obligatoria para el personal. El Administrador y el SuperAdmin no pueden usar el sistema sin ella.
- **Descargar mis datos**: genera un archivo `mis-datos-nami.json` con tu perfil, direcciones, favoritos y pedidos. En el celular se copia al portapapeles.
- **Eliminar mi cuenta**: borra tu perfil y tus datos de contacto. Los pedidos ya entregados o cancelados se quedan sin tu nombre, teléfono ni dirección, porque el negocio los necesita para sus cuentas. Si no puedes entrar a la app, usa la página https://gestion-pedidos-univalle.web.app/eliminar-cuenta.html.

## Cliente

1. Crea tu cuenta y verifica tu correo (sin esto no puedes pedir).
2. Entra a un restaurante con su código o su QR.
3. Elige productos, variantes y complementos, y revisa el carrito.
4. En el pago elige retiro, mesa o delivery. Para delivery marca tu dirección en el mapa.
5. Si tienes un cupón, escríbelo. Cada cupón se usa una sola vez por cliente.
6. Si necesitas factura, marca la opción y llena el NIT y la razón social.
7. Sigue tu pedido en **Mis pedidos**. Al terminar puedes dejar una reseña.

Tu dirección y tu teléfono solo los ven el cajero, el administrador y el repartidor mientras lleva tu pedido. La cocina no los ve.

## Cajero

- **Pedidos**: acepta, cancela (pide tu contraseña) y cambia el estado de los pedidos.
- **Mesas**: abre una mesa y toma el pedido en el local.
- **Caja**: abre la caja al empezar el turno y registra los movimientos.
- **Rendición**: al cerrar la caja el sistema compara lo esperado con lo contado. El cierre pide tu contraseña.

## Cocina

- **Tablero**: los pedidos aparecen por estado. Pasa cada uno a "En preparación" y luego a "Listo".
- La cocina ve los productos y las notas, pero no los datos personales del cliente.

## Repartidor

- **Mis entregas**: toma un pedido "Listo". Desde ese momento ves la dirección y el teléfono.
- Cambia el estado a "En camino", "En el lugar" y "Entregado".
- Cuando el pedido termina, la dirección deja de estar visible para ti.

## Administrador (dueño del restaurante)

- **Negocio y sucursales**: datos, horarios, zonas de delivery, condiciones y QR del restaurante.
- **Catálogo**: categorías, productos, variantes, complementos y stock.
- **Empleados y roles**: crea cuentas del personal y define qué puede hacer cada rol. Cada empleado firma el acuerdo de uso y confidencialidad al entrar.
- **Cupones**: crea descuentos por porcentaje o monto fijo.
- **Clientes, ventas y reseñas**: reportes y exportación a Excel.
- **Actividad**: registro de quién hizo qué.

Recuerda: cada cuenta nueva cuenta para el límite de 99 usuarios.

## SuperAdmin (plataforma)

- **Solicitudes**: aprueba o rechaza los restaurantes que quieren entrar a Nami.
- **Negocios**: ve y administra todos los restaurantes.
- **Versiones**: indica la versión mínima de la app.
- **Errores**: revisa los errores que registra la app.
