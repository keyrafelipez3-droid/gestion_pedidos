/**
 * Funciones del servidor de Caro (Cloud Functions de Firebase, 2.ª gen.).
 *
 * ESTADO: PREPARADAS, NO DESPLEGADAS. Cloud Functions necesita el plan
 * Blaze (pago por uso). Con el volumen de un restaurante mediano el costo
 * suele quedar dentro de la capa gratuita de Blaze (2 millones de
 * invocaciones al mes), pero Firebase exige registrar una tarjeta.
 * Cómo activarlas: ver functions/README.md.
 *
 * Qué agregan sobre lo que ya hace la app:
 *  1. verificarTotalPedido  → recalcula en el servidor el total de cada
 *     pedido con los precios del catálogo y marca los que no coinciden.
 *  2. descontarStockServidor → descuenta el stock en el servidor (hoy lo
 *     hace el celular de la cocina; así no depende de que tenga internet).
 *  3. avisarCambioDeEstado  → notificación push al cliente cuando su pedido
 *     cambia de estado, aunque tenga la app cerrada.
 *  4. avisarPedidoNuevo     → notificación push al personal del negocio
 *     cuando entra un pedido.
 *  5. limpiarErroresViejos  → borra cada semana los errores de la app de
 *     más de 30 días.
 */
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { setGlobalOptions, logger } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

// Región más cercana a Bolivia con Firestore/Functions.
setGlobalOptions({ region: 'southamerica-east1', maxInstances: 10 });

const redondear = (n) => Math.round(n * 100) / 100;

/** Precio actual de una opción (variante o complemento) del catálogo. */
async function precioOpcion(opcion) {
  const comp = await db.collection('complementos').doc(opcion.id).get();
  if (comp.exists) return Number(comp.get('precio') || 0);
  const vari = await db.collection('variantes').doc(opcion.id).get();
  if (vari.exists) return Number(vari.get('precioAdicional') || 0);
  return Number(opcion.precio || 0);
}

/**
 * Total que debería tener el pedido según el catálogo actual. Función pura
 * aparte para poder probarla.
 */
function totalEsperado(items) {
  return redondear(
    items.reduce((acc, i) => acc + (i.precioProducto + i.extras.reduce((a, x) => a + x, 0)) * i.cantidad, 0),
  );
}

// 1. El detalle del pedido se escribe junto con su primer "historial".
//    Cuando aparece ese historial, el detalle ya existe y se puede revisar.
exports.verificarTotalPedido = onDocumentCreated('pedidos/{idPedido}/historialEstados/{idHistorial}', async (event) => {
  const historial = event.data?.data();
  if (!historial || historial.estado !== 'Pendiente') return;
  const ref = db.collection('pedidos').doc(event.params.idPedido);
  const [pedido, detalle] = await Promise.all([ref.get(), ref.collection('detalle').get()]);
  if (!pedido.exists || pedido.get('origen') === 'cajero') return;

  const items = [];
  for (const d of detalle.docs) {
    const item = d.data();
    const producto = await db.collection('productos').doc(item.idProducto).get();
    const opciones = [...(item.variantes || []), ...(item.complementos || [])];
    items.push({
      cantidad: Number(item.cantidad || 1),
      precioProducto: Number(producto.get('precio') ?? item.precioUnitario ?? 0),
      extras: await Promise.all(opciones.map(precioOpcion)),
    });
  }
  const esperado = totalEsperado(items);
  const declarado = redondear(Number(pedido.get('total') || 0) + Number(pedido.get('descuento') || 0));
  // Tolerancia: un precio pudo cambiar mientras el cliente pedía.
  if (Math.abs(esperado - declarado) > 0.5) {
    logger.warn('Total distinto al del catálogo', { idPedido: ref.id, esperado, declarado });
    await ref.update({
      revisionTotal: { esperado, declarado, fecha: admin.firestore.FieldValue.serverTimestamp() },
    });
  }
});

// 2. Stock en el servidor al pasar a "En preparación".
exports.descontarStockServidor = onDocumentUpdated('pedidos/{idPedido}', async (event) => {
  const antes = event.data?.before.data();
  const despues = event.data?.after.data();
  if (!antes || !despues) return;
  if (antes.estado === despues.estado || despues.estado !== 'En preparación') return;
  const detalle = await event.data.after.ref.collection('detalle').get();
  const cantidades = new Map();
  for (const d of detalle.docs) {
    const id = d.get('idProducto');
    if (id) cantidades.set(id, (cantidades.get(id) || 0) + Number(d.get('cantidad') || 1));
  }
  for (const [id, cantidad] of cantidades) {
    await db.runTransaction(async (tx) => {
      const ref = db.collection('productos').doc(id);
      const snap = await tx.get(ref);
      const stock = snap.get('stock');
      if (!snap.exists || typeof stock !== 'number' || stock <= 0) return;
      const nuevo = Math.max(0, stock - cantidad);
      tx.update(ref, { stock: nuevo, ...(nuevo === 0 ? { disponible: false } : {}) });
    });
  }
});

/** Envía una notificación a los dispositivos registrados de un usuario. */
async function notificarUsuario(uid, titulo, cuerpo, datos = {}) {
  const dispositivos = await db.collection('usuarios').doc(uid).collection('dispositivos').get();
  const tokens = dispositivos.docs.map((d) => d.id);
  if (tokens.length === 0) return;
  const r = await admin.messaging().sendEachForMulticast({ tokens, notification: { title: titulo, body: cuerpo }, data: datos });
  // Se borran los tokens que ya no sirven (app desinstalada, etc.).
  await Promise.all(
    r.responses.map((resp, i) => (resp.success ? null : dispositivos.docs[i].ref.delete())),
  );
}

const MENSAJES = {
  'En preparación': 'Tu pedido ya se está preparando 👨‍🍳',
  Listo: 'Tu pedido está listo ✅',
  'En camino': 'Tu pedido va en camino 🛵',
  'En el lugar': 'El repartidor llegó 📍',
  Entregado: '¡Buen provecho! Pedido entregado',
  Cancelado: 'Tu pedido fue cancelado',
};

// 3. Push al cliente cuando cambia el estado de su pedido.
exports.avisarCambioDeEstado = onDocumentUpdated('pedidos/{idPedido}', async (event) => {
  const antes = event.data?.before.data();
  const despues = event.data?.after.data();
  if (!antes || !despues || antes.estado === despues.estado) return;
  const mensaje = MENSAJES[despues.estado];
  if (!mensaje || !despues.idCliente || despues.origen === 'cajero') return;
  await notificarUsuario(despues.idCliente, `Pedido #${event.params.idPedido.slice(0, 6)}`, mensaje, {
    idPedido: event.params.idPedido,
  });
});

// 4. Push al personal del negocio cuando entra un pedido (tema por negocio).
exports.avisarPedidoNuevo = onDocumentCreated('pedidos/{idPedido}', async (event) => {
  const p = event.data?.data();
  if (!p || !p.idNegocio) return;
  await admin.messaging().send({
    topic: `negocio_${p.idNegocio}_personal`,
    notification: {
      title: 'Nuevo pedido',
      body: `#${event.params.idPedido.slice(0, 6)} · ${p.modalidad} · Bs ${Number(p.total || 0).toFixed(2)}`,
    },
    data: { idPedido: event.params.idPedido },
  });
});

// 5. Limpieza semanal del registro de errores.
exports.limpiarErroresViejos = onSchedule({ schedule: 'every monday 04:00', timeZone: 'America/La_Paz' }, async () => {
  const limite = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 24 * 3600 * 1000);
  const viejos = await db.collection('erroresApp').where('fecha', '<', limite).limit(500).get();
  const batch = db.batch();
  viejos.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  logger.info(`Errores borrados: ${viejos.size}`);
});

exports._paraPruebas = { totalEsperado };
