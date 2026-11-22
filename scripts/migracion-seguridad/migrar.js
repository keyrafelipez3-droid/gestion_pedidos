// Migración de la rama fix/seguridad-lanzamiento. Se corre UNA vez, antes
// de desplegar las reglas nuevas.
//
// Qué hace:
//  1. Mueve el código de acceso de cada restaurante de negocios/{id}
//     (campo codigoAcceso) a negocios/{id}/privado/acceso (campo codigo),
//     y borra el campo viejo.
//  2. Arma la lista de precios de cada negocio
//     (negocios/{id}/publico/precios) a partir de sus productos. Las
//     reglas nuevas la usan para validar los pedidos. Se puede volver a
//     correr cuando se quiera: la rehace desde los productos.
//
// Uso (desde la carpeta scripts/migracion-seguridad):
//   npm install
//   node migrar.js ruta/a/serviceAccountKey.json          (solo muestra lo que haría)
//   node migrar.js ruta/a/serviceAccountKey.json --aplicar
//
// La llave de servicio NUNCA se sube a GitHub. No crea usuarios.

import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const rutaLlave = process.argv[2];
const aplicar = process.argv.includes('--aplicar');
if (!rutaLlave) {
  console.error('Falta la llave de servicio: node migrar.js ruta/a/serviceAccountKey.json [--aplicar]');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();

async function moverCodigos() {
  const negocios = await db.collection('negocios').get();
  let movidos = 0;
  for (const doc of negocios.docs) {
    const codigo = doc.data().codigoAcceso;
    if (!codigo) continue;
    console.log(`  ${doc.id} (${doc.data().nombre ?? ''}): codigo ${codigo}`);
    if (aplicar) {
      const lote = db.batch();
      lote.set(doc.ref.collection('privado').doc('acceso'), { codigo });
      lote.update(doc.ref, { codigoAcceso: admin.firestore.FieldValue.delete() });
      await lote.commit();
    }
    movidos++;
  }
  console.log(`Códigos de acceso: ${movidos} ${aplicar ? 'movidos' : 'por mover'}.`);
}

async function armarPrecios() {
  const negocios = await db.collection('negocios').get();
  const ahora = new Date();
  for (const negocio of negocios.docs) {
    const productos = await db.collection('productos').where('idNegocio', '==', negocio.id).get();
    // Mismo formato que CatalogoService (lib/services/catalogo_service.dart).
    const normal = {};
    const promo = {};
    const hasta = {};
    for (const p of productos.docs) {
      const d = p.data();
      if (typeof d.precio !== 'number') continue;
      normal[p.id] = d.precio;
      const fin = d.promoHasta ? d.promoHasta.toDate() : null;
      const promoActiva = typeof d.precioPromo === 'number' && d.precioPromo > 0
        && d.precioPromo < d.precio && (fin === null || ahora < fin);
      if (promoActiva) {
        promo[p.id] = d.precioPromo;
        if (fin) hasta[p.id] = d.promoHasta;
      }
    }
    let promoHasta = null;
    for (const t of Object.values(hasta)) {
      if (promoHasta === null || t.toMillis() < promoHasta.toMillis()) promoHasta = t;
    }
    console.log(`  ${negocio.id} (${negocio.data().nombre ?? ''}): ${Object.keys(normal).length} productos, ${Object.keys(promo).length} en promoción`);
    if (aplicar) {
      await negocio.ref.collection('publico').doc('precios').set({ normal, promo, hasta, promoHasta });
    }
  }
  console.log(`Listas de precios: ${negocios.size} negocios ${aplicar ? 'listos' : 'por armar'}.`);
}

console.log(aplicar ? 'Aplicando la migración...' : 'Modo prueba (no cambia nada). Agrega --aplicar para hacerlo.');
await moverCodigos();
await armarPrecios();
console.log('Listo.');
