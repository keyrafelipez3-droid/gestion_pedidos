// Copia de seguridad de toda la base de datos de Firestore en archivos
// JSON (una carpeta por fecha). Funciona con el plan GRATUITO: solo lee
// documentos (cada documento cuenta como una lectura de la cuota diaria
// de 50.000).
//
// Uso (desde la carpeta scripts/respaldo):
//   npm install
//   node respaldo.js ruta/a/serviceAccountKey.json
//
// La llave de servicio NUNCA se sube a GitHub. Los respaldos quedan en
// scripts/respaldo/copias/AAAA-MM-DD_HH-MM/ (también ignorados por Git).
// Guárdalos en un lugar seguro (Google Drive, disco externo): contienen
// datos personales de los clientes.

import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import admin from 'firebase-admin';

const rutaLlave = process.argv[2];
if (!rutaLlave) {
  console.error('Falta la llave de servicio: node respaldo.js ruta/a/serviceAccountKey.json');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();

/** Convierte los tipos de Firestore a JSON que se pueda leer. */
function aJson(valor) {
  if (valor instanceof admin.firestore.Timestamp) return { _fecha: valor.toDate().toISOString() };
  if (valor instanceof admin.firestore.GeoPoint) return { _lat: valor.latitude, _lng: valor.longitude };
  if (valor instanceof admin.firestore.DocumentReference) return { _ref: valor.path };
  if (Array.isArray(valor)) return valor.map(aJson);
  if (valor && typeof valor === 'object') {
    return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, aJson(v)]));
  }
  return valor;
}

let total = 0;

/** Copia una colección y, dentro de cada documento, sus subcolecciones. */
async function copiarColeccion(coleccion) {
  const snap = await coleccion.get();
  const docs = [];
  for (const doc of snap.docs) {
    const subcolecciones = {};
    for (const sub of await doc.ref.listCollections()) {
      subcolecciones[sub.id] = await copiarColeccion(sub);
    }
    docs.push({
      id: doc.id,
      datos: aJson(doc.data()),
      ...(Object.keys(subcolecciones).length ? { subcolecciones } : {}),
    });
    total++;
  }
  return docs;
}

const ahora = new Date();
const dos = (n) => String(n).padStart(2, '0');
const carpeta = join(
  'copias',
  `${ahora.getFullYear()}-${dos(ahora.getMonth() + 1)}-${dos(ahora.getDate())}_${dos(ahora.getHours())}-${dos(ahora.getMinutes())}`,
);
mkdirSync(carpeta, { recursive: true });

for (const coleccion of await db.listCollections()) {
  process.stdout.write(`Copiando ${coleccion.id}... `);
  const docs = await copiarColeccion(coleccion);
  writeFileSync(join(carpeta, `${coleccion.id}.json`), JSON.stringify(docs, null, 2));
  console.log(`${docs.length} documentos`);
}

console.log(`\nListo: ${total} documentos copiados en ${carpeta}`);
process.exit(0);
