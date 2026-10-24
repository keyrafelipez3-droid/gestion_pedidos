# Funciones del servidor (preparadas, sin activar)

Estas funciones ya están escritas y probadas, pero **no están desplegadas**:
Cloud Functions solo funciona con el **plan Blaze** de Firebase (pago por
uso). Se activan cuando un negocio contrate el servicio.

| Función | Qué hace |
|---|---|
| `verificarTotalPedido` | Recalcula en el servidor el total de cada pedido con los precios del catálogo y marca (`revisionTotal`) los que no coinciden. |
| `descontarStockServidor` | Descuenta el stock en el servidor al pasar un pedido a "En preparación". |
| `avisarCambioDeEstado` | Notificación push al cliente cuando cambia el estado de su pedido. |
| `avisarPedidoNuevo` | Notificación push al personal del negocio cuando entra un pedido. |
| `limpiarErroresViejos` | Cada lunes borra los errores de la app de más de 30 días. |

## Costo estimado

Blaze cobra solo lo que pasa de la capa gratuita: 2 millones de
invocaciones, 400.000 GB-segundo y 200.000 CPU-segundo al mes. Un
restaurante con 300 pedidos al día usa unas 30.000 invocaciones al mes,
así que normalmente el costo es **0**. Igual conviene poner una
**alerta de presupuesto** (por ejemplo, 5 USD) en Google Cloud.

## Cómo activarlas (cuando se pase a Blaze)

1. En la consola de Firebase: **Configuración del proyecto → Uso y
   facturación → Modificar plan → Blaze**. Poner la alerta de presupuesto.
2. Agregar esto a `firebase.json` (al mismo nivel que `"hosting"`):

   ```json
   "functions": [{ "source": "functions", "codebase": "default" }]
   ```

3. En PowerShell:

   ```
   cd functions
   npm install
   npm run verificar
   cd ..
   firebase deploy --only functions
   ```

4. Cuando estén funcionando, se puede quitar de la app el descuento de
   stock que hoy hace el celular (`_descontarStock` en
   `lib/services/pedido_service.dart`), para que no se descuente dos veces.

## Notificaciones push: lo que falta en la app

Las funciones de push ya están listas. En la app falta agregar el paquete
`firebase_messaging`, pedir permiso de notificaciones y guardar el token
del dispositivo en `usuarios/{uid}/dispositivos/{token}` (clientes) o
suscribirse al tema `negocio_{idNegocio}_personal` (personal). También
hay que agregar esa subcolección a `firestore.rules`.
