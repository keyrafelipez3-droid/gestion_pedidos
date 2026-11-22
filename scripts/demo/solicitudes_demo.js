// Solicitudes de negocios DE EJEMPLO para que el panel del SuperAdmin no
// se vea vacío en las demostraciones.
//
// Cada solicitud necesita una cuenta de cliente real (al aprobarla, esa
// cuenta pasa a ser el Administrador del negocio nuevo). Por eso el script
// crea cuentas de ejemplo con correos @example.com, SIN contraseña y
// DESACTIVADAS: nadie puede iniciar sesión con ellas.
// Todo lo que crea queda marcado con demo: true.
//
// Uso (desde la carpeta scripts/demo):
//   npm install
//   node solicitudes_demo.js ruta/a/serviceAccountKey.json            (crear)
//   node solicitudes_demo.js ruta/a/serviceAccountKey.json --borrar   (borrar todo lo de ejemplo)
//
// La llave de servicio NUNCA se sube a GitHub.

import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const rutaLlave = process.argv[2];
const borrar = process.argv.includes('--borrar');
if (!rutaLlave) {
  console.error('Falta la llave: node solicitudes_demo.js ruta/a/serviceAccountKey.json [--borrar]');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();
const auth = admin.auth();

// Regla del proyecto: nunca más de 99 cuentas en Firebase Auth, contando
// las de prueba y las de ejemplo.
const MAX_CUENTAS = 99;

async function contarCuentas() {
  let total = 0;
  let pagina;
  do {
    const r = await auth.listUsers(1000, pagina);
    total += r.users.length;
    pagina = r.pageToken;
  } while (pagina);
  return total;
}

const hace = (dias, horas = 0) =>
  admin.firestore.Timestamp.fromDate(new Date(Date.now() - (dias * 24 + horas) * 3600 * 1000));

const ejemplos = [
  {
    clave: 'salteneria',
    nombreSolicitante: 'Mariela Quispe',
    nombreNegocio: 'Salteñería Doña Mari',
    ciudad: 'Cochabamba',
    telefono: '+59171234567',
    nit: '4512378019',
    mensaje: 'Vendemos salteñas y empanadas desde 2015. Queremos recibir pedidos para recoger y delivery en la zona norte.',
    fecha: hace(3, 5),
  },
  {
    clave: 'pollos',
    nombreSolicitante: 'Jorge Mendoza',
    nombreNegocio: 'Pollos El Cruceño',
    ciudad: 'Santa Cruz de la Sierra',
    telefono: '+59176543210',
    nit: '3021456017',
    mensaje: 'Tenemos dos sucursales y mucho pedido por teléfono. Nos interesa el control de caja y de repartidores.',
    fecha: hace(2, 2),
  },
  {
    clave: 'cafe',
    nombreSolicitante: 'Lucía Fernández',
    nombreNegocio: 'Café Altura',
    ciudad: 'La Paz',
    telefono: '+59172201133',
    nit: '',
    mensaje: 'Cafetería pequeña en Sopocachi. Todavía estamos tramitando el NIT.',
    fecha: hace(1, 7),
  },
  {
    clave: 'cevicheria',
    nombreSolicitante: 'Renzo Salazar',
    nombreNegocio: 'Cevichería Mar Azul',
    ciudad: 'Lima, Perú',
    telefono: '+51987654321',
    nit: '20601234567',
    mensaje: 'Somos de Miraflores. Queremos usar los pedidos por mesa con QR.',
    fecha: hace(0, 20),
  },
  {
    clave: 'taqueria',
    nombreSolicitante: 'Ana Gutiérrez',
    nombreNegocio: 'Taquería La Esquina',
    ciudad: 'Guadalajara, México',
    telefono: '+523312345678',
    nit: 'GUTA850312AB1',
    mensaje: 'Abrimos de noche y queremos que la cocina vea los pedidos en una pantalla.',
    fecha: hace(0, 3),
  },
];

async function crear() {
  const cuentas = await contarCuentas();
  let nuevas = 0;
  for (const e of ejemplos) {
    try {
      await auth.getUserByEmail(`demo.${e.clave}@example.com`);
    } catch {
      nuevas++;
    }
  }
  if (cuentas + nuevas > MAX_CUENTAS) {
    console.error(`No creo nada: ya hay ${cuentas} cuentas y con ${nuevas} más se pasaría de ${MAX_CUENTAS}.`);
    process.exit(1);
  }
  console.log(`Cuentas en Firebase Auth: ${cuentas} (+${nuevas} de ejemplo, máximo ${MAX_CUENTAS}).`);

  for (const e of ejemplos) {
    const correo = `demo.${e.clave}@example.com`;
    let usuario;
    try {
      usuario = await auth.getUserByEmail(correo);
    } catch {
      usuario = await auth.createUser({ email: correo, displayName: e.nombreSolicitante, disabled: true });
    }
    const uid = usuario.uid;

    const sol = await db.collection('solicitudesNegocio').doc(uid).get();
    if (sol.exists && sol.data().estado !== 'Pendiente') {
      console.log(`- ${e.nombreNegocio}: ya fue revisada (${sol.data().estado}), no la toco`);
      continue;
    }

    await db.collection('usuarios').doc(uid).set({
      nombre: e.nombreSolicitante,
      email: correo,
      telefono: e.telefono,
      rol: 'Cliente',
      fotoPerfil: '',
      idSucursal: null,
      idNegocio: null,
      estado: true,
      fechaRegistro: e.fecha,
      notificacionesActivas: true,
      demo: true,
    });
    await db.collection('solicitudesNegocio').doc(uid).set({
      nombreNegocio: e.nombreNegocio,
      ciudad: e.ciudad,
      telefono: e.telefono,
      nit: e.nit,
      mensaje: e.mensaje,
      nombreSolicitante: e.nombreSolicitante,
      correo,
      estado: 'Pendiente',
      fecha: e.fecha,
      demo: true,
    });
    console.log(`+ ${e.nombreNegocio} (${e.ciudad})`);
  }
  console.log('\nListo: abre "Solicitudes" como SuperAdmin.');
}

async function borrarTodo() {
  const usuarios = await db.collection('usuarios').where('demo', '==', true).get();
  for (const u of usuarios.docs) {
    const sol = await db.collection('solicitudesNegocio').doc(u.id).get();
    const idNegocio = sol.exists ? sol.data().idNegocio : null;
    if (idNegocio) {
      // Si la aprobaste en la demo, se borra también el negocio creado
      // (con sus subcolecciones, por si le agregaste algo).
      await db.recursiveDelete(db.collection('negocios').doc(idNegocio));
      console.log(`- negocio de ejemplo ${idNegocio}`);
    }
    if (sol.exists) await sol.ref.delete();
    await u.ref.delete();
    try {
      await auth.deleteUser(u.id);
    } catch {
      // La cuenta ya no existía.
    }
    console.log(`- ${u.data().nombre}`);
  }
  console.log(`\nListo: ${usuarios.size} solicitudes de ejemplo borradas.`);
}

await (borrar ? borrarTodo() : crear());
process.exit(0);
