// Migración de la rama fix/proteger-datos. Se corre UNA vez, justo después
// de desplegar las reglas nuevas.
//
// Qué hace: en los pedidos ANTERIORES, la dirección, el teléfono y los datos
// de factura estaban dentro del propio pedido (y la Cocina los podía leer).
// Este script los pasa a pedidos/{id}/privado/contacto y los borra del
// pedido. Los pedidos nuevos ya se crean así.
//
// Escrituras: 2 por cada pedido que tenga esos datos (el plan gratis
// permite 20.000 escrituras por día). Primero corre sin --aplicar para ver
// cuántos son.
//
// Uso (desde la carpeta scripts/migracion-seguridad, que ya tiene
// firebase-admin instalado):
//   node migrar-privacidad.js ruta/a/serviceAccountKey.json            (solo cuenta)
//   node migrar-privacidad.js ruta/a/serviceAccountKey.json --aplicar
//
// La llave de servicio NUNCA se sube a GitHub. No crea usuarios.

import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const rutaLlave = process.argv[2];
const aplicar = process.argv.includes('--aplicar');
if (!rutaLlave || rutaLlave.startsWith('--')) {
  console.error('Falta la llave: node migrar-privacidad.js ruta/a/serviceAccountKey.json [--aplicar]');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();
const borrar = admin.firestore.FieldValue.delete();
const CAMPOS = ['direccionEntrega', 'telefonoCliente', 'facturaNit', 'facturaRazonSocial'];

const pedidos = await db.collection('pedidos').get();
let porMover = 0;
let lote = db.batch();
let enLote = 0;

for (const doc of pedidos.docs) {
  const datos = doc.data();
  const contacto = {};
  for (const campo of CAMPOS) {
    if (datos[campo] !== undefined && datos[campo] !== null && datos[campo] !== '') contacto[campo] = datos[campo];
  }
  const tieneCampos = CAMPOS.some((c) => c in datos);
  if (!tieneCampos) continue;
  porMover++;
  if (!aplicar) continue;

  if (Object.keys(contacto).length > 0) {
    // merge: si el pedido ya tenía privado/contacto, no se pierde nada.
    lote.set(doc.ref.collection('privado').doc('contacto'), contacto, { merge: true });
    enLote++;
  }
  lote.update(doc.ref, Object.fromEntries(CAMPOS.map((c) => [c, borrar])));
  enLote++;
  if (enLote >= 400) {
    await lote.commit();
    lote = db.batch();
    enLote = 0;
  }
}
if (aplicar && enLote > 0) await lote.commit();

console.log(`Pedidos revisados: ${pedidos.size}.`);
console.log(`Pedidos con datos de contacto dentro: ${porMover} ${aplicar ? '(ya movidos a privado/contacto)' : '(corre con --aplicar para moverlos)'}.`);
process.exit(0);
