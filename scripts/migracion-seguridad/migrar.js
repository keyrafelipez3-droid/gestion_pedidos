// Migración de la rama fix/seguridad-lanzamiento. Se corre UNA vez, antes
// de desplegar las reglas nuevas.
//
// Qué hace:
//  1. Mueve el código de acceso de cada restaurante de negocios/{id}
//     (campo codigoAcceso) a negocios/{id}/privado/acceso (campo codigo),
//     y borra el campo viejo.
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

console.log(aplicar ? 'Aplicando la migración...' : 'Modo prueba (no cambia nada). Agrega --aplicar para hacerlo.');
await moverCodigos();
console.log('Listo.');
