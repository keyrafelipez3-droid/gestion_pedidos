// Publica la lista pública de restaurantes (colección `directorio`) que
// se ve en el inicio de sesión: nombre, logo, color, ciudad y el CÓDIGO
// para entrar de cada restaurante activo. Así las tarjetas muestran el
// código sin esperar a que el SuperAdmin abra su panel.
//
// - Si un restaurante activo todavía no tiene código, le crea uno (igual
//   que el botón del SuperAdmin: codigosNegocio/{codigo} y
//   negocios/{id}/privado/acceso).
// - Quita de la lista los restaurantes desactivados o sin nombre.
// - Limpia los espacios de más en el nombre y la ciudad.
// - Escribe poco: 1 escritura por restaurante (3 si hay que crearle código).
//
// Uso (desde la carpeta scripts/demo):
//   node publicar_directorio.js LLAVE            publicar
//   node publicar_directorio.js LLAVE --probar   solo mostrar lo que haría
//
// LLAVE = ruta a serviceAccountKey.json (NUNCA se sube a GitHub).

import { randomInt } from 'node:crypto';
import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const args = process.argv.slice(2);
const rutaLlave = args[0];
const soloProbar = args.includes('--probar');
if (!rutaLlave || rutaLlave.startsWith('--')) {
  console.error('Uso: node publicar_directorio.js LLAVE [--probar]');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();

// Mismo alfabeto que la app (sin 0/O, 1/I/L): fácil de dictar.
const ALFABETO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const generar = () => Array.from({ length: 6 }, () => ALFABETO[randomInt(ALFABETO.length)]).join('');
const limpio = (t) => (typeof t === 'string' ? t.replace(/\s+/g, ' ').trim() : '');

async function codigoNuevo() {
  for (let i = 0; i < 10; i++) {
    const c = generar();
    if (!(await db.collection('codigosNegocio').doc(c).get()).exists) return c;
  }
  throw new Error('No se pudo generar un código libre.');
}

const negocios = await db.collection('negocios').get();
let publicados = 0;
let quitados = 0;
let creados = 0;

for (const doc of negocios.docs) {
  const n = doc.data();
  const nombre = limpio(n.nombre);
  const directorio = db.collection('directorio').doc(doc.id);

  if (n.estado !== true || !nombre) {
    if ((await directorio.get()).exists) {
      console.log(`- quitar   ${nombre || doc.id} (desactivado o sin nombre)`);
      if (!soloProbar) await directorio.delete();
      quitados++;
    }
    continue;
  }

  const acceso = doc.ref.collection('privado').doc('acceso');
  let codigo = (await acceso.get()).data()?.codigo;
  if (!codigo) {
    codigo = await codigoNuevo();
    console.log(`+ código   ${nombre}: ${codigo} (no tenía)`);
    if (!soloProbar) {
      const lote = db.batch();
      lote.set(db.collection('codigosNegocio').doc(codigo), {
        idNegocio: doc.id,
        nombre,
        logoUrl: n.logoUrl ?? '',
        colorPrimario: n.colorPrimario ?? '',
      });
      lote.set(acceso, { codigo });
      await lote.commit();
    }
    creados++;
  }

  const datos = {
    nombre: nombre.slice(0, 80),
    logoUrl: typeof n.logoUrl === 'string' ? n.logoUrl.trim().slice(0, 2048) : '',
    colorPrimario: typeof n.colorPrimario === 'string' ? n.colorPrimario.trim().slice(0, 20) : '',
    ciudad: limpio(n.ciudad).slice(0, 60),
    codigo,
  };
  console.log(`✓ publicar ${datos.nombre}${datos.ciudad ? ` (${datos.ciudad})` : ''}: ${codigo}`);
  if (!soloProbar) await directorio.set(datos);
  publicados++;
}

console.log(
  `\n${soloProbar ? '[prueba, no se escribió nada] ' : ''}` +
    `${publicados} publicados, ${creados} códigos nuevos, ${quitados} quitados.`,
);
