// Datos DE EJEMPLO para la demostración: llena un restaurante con un mes
// de ventas, pedidos en curso, mesas ocupadas, cajas cerradas, reseñas,
// cupones y clientes; y agrega otros restaurantes de ejemplo para que el
// panel del SuperAdmin no se vea vacío.
//
// Usa lo que el restaurante ya tiene (sucursales, menú, mesas y personal);
// solo crea lo que falta. Todo lo que agrega queda marcado con
// demoDatos: true y se puede borrar con --borrar.
//
// Uso (desde la carpeta scripts/demo):
//   node datos_demo.js LLAVE --listar               ver los restaurantes y su id
//   node datos_demo.js LLAVE --negocio ID_NEGOCIO   llenar ese restaurante
//   node datos_demo.js LLAVE --todos                llenar todos los restaurantes
//   node datos_demo.js LLAVE --refrescar            pedidos de hoy a la hora actual (día de la defensa)
//   node datos_demo.js LLAVE --cliente CORREO       pedidos de ejemplo para tu cuenta de cliente
//                                                   (en Febu Garu; otro restaurante: --negocio ID)
//   node datos_demo.js LLAVE --borrar               borrar todo lo de ejemplo
//
// LLAVE = ruta a serviceAccountKey.json (NUNCA se sube a GitHub).

import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const args = process.argv.slice(2);
const rutaLlave = args[0];
const opcion = (nombre) => {
  const i = args.indexOf(nombre);
  return i >= 0 ? args[i + 1] : undefined;
};
if (!rutaLlave || rutaLlave.startsWith('--')) {
  console.error('Uso: node datos_demo.js LLAVE (--listar | --negocio ID | --borrar)');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();
const { Timestamp, GeoPoint } = admin.firestore;
const MARCA = { demoDatos: true };

// ------------------------------------------------------------------ utilidades

let semilla = 20261027;
/** Números al azar pero siempre los mismos (la demo sale igual cada vez). */
function azar() {
  semilla = (semilla * 1103515245 + 12345) % 2147483648;
  return semilla / 2147483648;
}
const entero = (min, max) => min + Math.floor(azar() * (max - min + 1));
const elegir = (lista) => lista[Math.floor(azar() * lista.length)];
const dinero = (v) => Math.round(v * 100) / 100;
const ts = (fecha) => Timestamp.fromDate(fecha);
const masMinutos = (fecha, min) => new Date(fecha.getTime() + min * 60000);

/** Escribe en lotes de hasta 450 operaciones. */
class Escritor {
  constructor() {
    this.lote = db.batch();
    this.n = 0;
    this.total = 0;
  }
  async set(ref, datos) {
    this.lote.set(ref, datos);
    await this._contar();
  }
  async update(ref, datos) {
    this.lote.update(ref, datos);
    await this._contar();
  }
  async _contar() {
    this.n++;
    this.total++;
    if (this.n >= 450) await this.cerrar();
  }
  async cerrar() {
    if (this.n > 0) await this.lote.commit();
    this.lote = db.batch();
    this.n = 0;
  }
}

// ------------------------------------------------------------- datos de ejemplo

const MENU = [
  {
    categoria: 'Platos fuertes',
    descripcion: 'Comida tradicional, porciones grandes',
    productos: [
      ['Pique macho', 'Carne, salchicha, papas fritas, huevo, locoto y tomate', 55, ['picante', 'huevo', 'cebolla']],
      ['Silpancho', 'Arroz, papa, carne apanada, huevo frito y ensalada', 38, ['gluten', 'huevo']],
      ['Pollo a la broaster', 'Presa de pollo crocante con papas y arroz', 32, ['gluten']],
      ['Majadito', 'Arroz con charque, huevo frito, plátano y yuca', 35, ['huevo']],
      ['Sajta de pollo', 'Pollo en salsa de ají amarillo con chuño y papa', 40, ['picante', 'cebolla']],
    ],
  },
  {
    categoria: 'Entradas',
    descripcion: 'Para picar mientras esperas',
    productos: [
      ['Salteña de carne', 'Jugosa, recién horneada', 9, ['gluten', 'huevo']],
      ['Empanada de queso', 'Frita, con azúcar opcional', 7, ['gluten', 'lacteos']],
      ['Anticucho', 'Corazón de res a la parrilla con papa y salsa de maní', 25, ['mani', 'picante']],
    ],
  },
  {
    categoria: 'Bebidas',
    descripcion: 'Frías y calientes',
    productos: [
      ['Mocochinchi', 'Refresco de durazno deshidratado', 8, []],
      ['Limonada', 'Natural, vaso grande', 10, []],
      ['Gaseosa 2 L', 'Coca-Cola, Fanta o Sprite', 18, []],
      ['Api con pastel', 'Api morado caliente con pastel de queso', 15, ['gluten', 'lacteos']],
    ],
  },
  {
    categoria: 'Postres',
    descripcion: 'Para terminar',
    productos: [
      ['Helado de canela', 'Dos bolas', 12, ['lacteos']],
      ['Flan casero', 'Con caramelo', 12, ['huevo', 'lacteos']],
    ],
  },
];

const MENU_POLLOS = [
  {
    categoria: 'Pollos',
    descripcion: 'Pollo crocante o a la brasa',
    productos: [
      ['1/4 de pollo broaster', 'Con papas fritas, arroz y ensalada', 28, ['gluten']],
      ['1/2 pollo broaster', 'Con papas fritas, arroz y ensalada', 52, ['gluten']],
      ['Pollo entero a la brasa', 'Para 4 personas, con papas y ensalada', 98, []],
      ['Alitas picantes (8 u.)', 'Con salsa de la casa', 35, ['picante']],
      ['Combo familiar', 'Pollo entero, papas grandes y gaseosa 2 L', 115, ['gluten']],
    ],
  },
  {
    categoria: 'Acompañamientos',
    descripcion: '',
    productos: [
      ['Papas fritas grandes', '', 15, []],
      ['Arroz con queso', '', 12, ['lacteos']],
      ['Ensalada fresca', 'Lechuga, tomate y zanahoria', 10, ['tomate']],
    ],
  },
  {
    categoria: 'Bebidas',
    descripcion: '',
    productos: [
      ['Gaseosa 2 L', 'Coca-Cola, Fanta o Sprite', 18, []],
      ['Limonada', 'Natural, vaso grande', 10, []],
      ['Mocochinchi', 'Refresco de durazno deshidratado', 8, []],
    ],
  },
];

const CLIENTES = [
  ['Andrea Vargas', '+59170011223'],
  ['Carlos Rojas', '+59171122334'],
  ['Daniela Mamani', '+59172233445'],
  ['Fernando Choque', '+59173344556'],
  ['Gabriela Torrez', '+59174455667'],
  ['Hugo Céspedes', '+59175566778'],
  ['Isabel Flores', '+59176677889'],
  ['Javier Gutiérrez', '+59177788990'],
  ['Karen Siles', '+59178899001'],
  ['Luis Quiroga', '+59179900112'],
  ['María José Antezana', '+59160011223'],
  ['Nicolás Paz', '+59161122334'],
  ['Paola Zurita', '+59162233445'],
  ['Rodrigo Arce', '+59163344556'],
];

const DIRECCIONES = [
  ['Casa', 'Av. América #1450', 'Portón negro, frente a la farmacia', 'Norte'],
  ['Trabajo', 'Calle España #230, edificio Colón, piso 3', 'Preguntar en recepción', 'Centro'],
  ['Casa', 'Av. Blanco Galindo km 2, calle 5', 'Casa de dos pisos, rejas verdes', 'Sur'],
  ['Depa', 'Calle Lanza #455', 'Timbre 2B', 'Centro'],
  ['Casa', 'Av. Melchor Pérez #890', 'Al lado de la tienda Don Pepe', 'Norte'],
];

const NOTAS = ['', '', '', '', 'Sin cebolla, por favor', 'Bien cocido', 'Salsa aparte', 'Sin picante', 'Para llevar cubiertos'];

const RESENAS = [
  [5, 'Muy rico y llegó caliente. El pique macho es enorme.'],
  [5, 'Excelente atención, el pedido estuvo listo en el tiempo que dijeron.'],
  [4, 'Buena comida, solo tardó un poco el delivery.'],
  [5, 'Me encanta poder ver en qué estado está mi pedido.'],
  [4, 'Las salteñas muy buenas. Volveré a pedir.'],
  [3, 'Rico, pero faltó la salsa que pedí aparte.'],
  [5, 'Pedimos desde la mesa con el QR y fue muy rápido.'],
  [4, 'Buen precio y porciones generosas.'],
];

const CUPONES = [
  { codigo: 'BIENVENIDA10', tipo: 'porcentaje', valor: 10, minimo: 0, dias: 30, descripcion: '10 % en tu primer pedido' },
  { codigo: 'ENVIOGRATIS', tipo: 'monto', valor: 8, minimo: 60, dias: 2, descripcion: 'Bs 8 de descuento en pedidos desde Bs 60' },
  { codigo: 'FINDE15', tipo: 'porcentaje', valor: 15, minimo: 80, dias: 10, descripcion: '15 % los fines de semana' },
];

const OTROS_NEGOCIOS = [
  { nombre: 'Cevichería Mar Azul', ciudad: 'Lima', pais: 'PE', color: '#00838F', telefono: '+51987654321',
    platos: [['Ceviche clásico', 38], ['Arroz con mariscos', 42], ['Jalea mixta', 45], ['Chicha morada', 10]] },
  { nombre: 'Taquería La Esquina', ciudad: 'Guadalajara', pais: 'MX', color: '#EF6C00', telefono: '+523312345678',
    platos: [['Tacos al pastor (3)', 75], ['Quesadilla', 60], ['Torta ahogada', 85], ['Agua de horchata', 35]] },
  { nombre: 'Salteñería Doña Mari', ciudad: 'Sucre', pais: 'BO', color: '#8D6E63', telefono: '+59171234500',
    platos: [['Salteña de pollo', 9], ['Salteña de carne', 9], ['Empanada de queso', 7], ['Api morado', 8]] },
  { nombre: 'Café Altura', ciudad: 'La Paz', pais: 'BO', color: '#4E342E', telefono: '+59172201133',
    platos: [['Capuchino', 18], ['Torta de chocolate', 20], ['Sándwich de pollo', 25], ['Jugo natural', 15]] },
  { nombre: 'Parrillada El Gaucho', ciudad: 'Tarija', pais: 'BO', color: '#6D4C41', telefono: '+59172644455',
    platos: [['Parrillada para 2', 140], ['Chorizo tarijeño', 25], ['Ensalada mixta', 15], ['Vino de la casa', 30]] },
  { nombre: 'Pizzería Don Vito', ciudad: 'Cochabamba', pais: 'BO', color: '#C62828', telefono: '+59170707070',
    platos: [['Pizza margarita', 60], ['Pizza pepperoni', 70], ['Lasaña', 45], ['Gaseosa 2 L', 18]] },
  { nombre: 'Sushi Kento', ciudad: 'Santa Cruz de la Sierra', pais: 'BO', color: '#1565C0', telefono: '+59170808080',
    platos: [['Roll acevichado', 65], ['Ramen', 55], ['Gyozas', 35], ['Té verde', 12]] },
  { nombre: 'Burger Andina', ciudad: 'La Paz', pais: 'BO', color: '#2E7D32', telefono: '+59170909090',
    platos: [['Hamburguesa clásica', 35], ['Hamburguesa doble', 48], ['Papas fritas', 15], ['Batido de frutilla', 18]] },
];

// ------------------------------------------------------------------- listar

async function listar() {
  const negocios = await db.collection('negocios').get();
  if (negocios.empty) {
    console.log('No hay restaurantes todavía.');
    return;
  }
  console.log('Restaurantes (usa el id con --negocio):\n');
  for (const n of negocios.docs) {
    const d = n.data();
    if (d.demoDatos) continue;
    const [suc, prod, gente, ped] = await Promise.all([
      db.collection('sucursales').where('idNegocio', '==', n.id).count().get(),
      db.collection('productos').where('idNegocio', '==', n.id).count().get(),
      db.collection('usuarios').where('idNegocio', '==', n.id).count().get(),
      db.collection('pedidos').where('idNegocio', '==', n.id).count().get(),
    ]);
    console.log(`${n.id}  ${d.nombre}`);
    console.log(
      `    sucursales: ${suc.data().count}, productos: ${prod.data().count}, ` +
        `personal: ${gente.data().count}, pedidos: ${ped.data().count}\n`,
    );
  }
}

// -------------------------------------------------------------------- llenar

/** Usa el menú del restaurante o crea uno de ejemplo si tiene muy poco. */
async function menuDe(idNegocio, w, platosSimples) {
  const existentes = await db.collection('productos').where('idNegocio', '==', idNegocio).get();
  const activos = existentes.docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((p) => p.estado !== false && typeof p.precio === 'number' && p.precio > 0);
  if (activos.length >= 4) {
    console.log(`  Menú: uso los ${activos.length} productos que ya tiene`);
    return activos.map((p) => ({ id: p.id, nombre: p.nombre, precio: p.precio }));
  }
  const nombreNegocio = ((await db.collection('negocios').doc(idNegocio).get()).data()?.nombre ?? '').toLowerCase();
  const grupos = platosSimples
    ? [{ categoria: 'Menú', descripcion: '', productos: platosSimples.map(([n, p]) => [n, '', p, []]) }]
    : /poll|broaster|brasa/.test(nombreNegocio)
      ? MENU_POLLOS
      : MENU;
  const productos = [];
  for (const g of grupos) {
    const cat = db.collection('categorias').doc();
    await w.set(cat, { nombre: g.categoria, descripcion: g.descripcion, imagenUrl: '', estado: true, idNegocio, ...MARCA });
    for (const [nombre, descripcion, precio, alergenos] of g.productos) {
      const ref = db.collection('productos').doc();
      await w.set(ref, {
        nombre,
        descripcion,
        precio,
        idCategoria: cat.id,
        imagenUrl: '',
        estado: true,
        disponible: true,
        idNegocio,
        alergenos,
        stock: null,
        stockMinimo: 5,
        precioPromo: null,
        promoHasta: null,
        esCombo: false,
        comboIds: [],
        ...MARCA,
      });
      productos.push({ id: ref.id, nombre, precio });
    }
  }
  // La lista de precios pública (negocios/{id}/publico/precios) que usan la
  // app y las reglas para revisar el precio de cada línea.
  const refPrecios = db.collection('negocios').doc(idNegocio).collection('publico').doc('precios');
  const normal = Object.fromEntries(productos.map((p) => [p.id, p.precio]));
  if ((await refPrecios.get()).exists) {
    await refPrecios.set({ normal }, { merge: true });
  } else {
    await refPrecios.set({ normal, promo: {}, hasta: {}, promoHasta: null });
  }
  console.log(`  Menú: creé ${productos.length} productos de ejemplo`);
  return productos;
}

/** Arma los platos de un pedido (detalle) y su total. */
function armarPlatos(productos) {
  const platos = [];
  const cuantos = entero(1, 4);
  const usados = new Set();
  for (let i = 0; i < cuantos; i++) {
    const p = elegir(productos);
    if (usados.has(p.id)) continue;
    usados.add(p.id);
    const cantidad = azar() < 0.7 ? 1 : entero(2, 3);
    platos.push({
      idProducto: p.id,
      nombreProducto: p.nombre,
      precioUnitario: p.precio,
      cantidad,
      variantes: [],
      complementos: [],
      notas: azar() < 0.15 ? elegir(NOTAS.filter(Boolean)) : '',
      subtotal: dinero(p.precio * cantidad),
    });
  }
  return { platos, total: dinero(platos.reduce((a, p) => a + p.subtotal, 0)) };
}

/** Estados por los que pasó un pedido hasta llegar a [final]. */
function caminoDeEstados(final, modalidad) {
  const delivery = modalidad === 'Delivery';
  const completo = delivery
    ? ['Pendiente', 'En preparación', 'Listo', 'En camino', 'En el lugar', 'Entregado']
    : ['Pendiente', 'En preparación', 'Listo', 'Entregado'];
  if (final === 'Cancelado') return ['Pendiente', 'Cancelado'];
  return completo.slice(0, completo.indexOf(final) + 1);
}

async function crearPedido(w, ctx, { fecha, estado, modalidad, mesa, cobrado, idCaja, repartidor, cliente, metodoPago, cuentaAbierta = false, origen, idSucursal, hoy = false }) {
  const { platos, total: subtotal } = armarPlatos(ctx.productos);
  const conCupon = estado === 'Entregado' && azar() < 0.08;
  const descuento = conCupon ? dinero(subtotal * 0.1) : 0;
  const total = dinero(subtotal - descuento);
  const delivery = modalidad === 'Delivery';
  const dir = delivery ? elegir(DIRECCIONES) : null;
  const costoEnvio = delivery ? ({ Centro: 5, Norte: 8, Sur: 10 }[dir[3]] ?? 8) : 0;
  const ref = db.collection('pedidos').doc();
  const pedido = {
    idCliente: cliente.id,
    idNegocio: ctx.idNegocio,
    idSucursal: idSucursal ?? ctx.idSucursal,
    modalidad,
    idMesa: mesa?.id ?? null,
    direccionEntrega: dir
      ? {
          etiqueta: dir[0],
          direccion: dir[1],
          referencia: dir[2],
          latitud: -17.3935 + (azar() - 0.5) * 0.04,
          longitud: -66.157 + (azar() - 0.5) * 0.04,
        }
      : null,
    metodoPago,
    comprobantePagoUrl: null,
    estado,
    total,
    notas: elegir(NOTAS),
    fechaCreacion: ts(fecha),
    origen,
    creadoPor: origen === 'cajero' ? ctx.cajero?.id ?? null : null,
    numeroMesa: mesa?.numero ?? null,
    cuentaAbierta,
    cobrado,
    idCaja: idCaja ?? null,
    nombreCliente: cliente.nombre,
    telefonoCliente: cliente.telefono,
    alergias: azar() < 0.06 ? ['mani'] : [],
    idiomaCliente: 'es',
    descuento,
    // Líneas del pedido, con el mismo formato que usa la app
    // (DetallePedidoModel.camposDeLineas en lib/models/pedido_models.dart).
    lineasIds: platos.map((p) => p.idProducto),
    lineasCant: platos.map((p) => p.cantidad),
    lineasNombre: platos.map((p) => p.nombreProducto),
    lineasNotas: platos.map((p) => p.notas),
    precios: Object.fromEntries(platos.map((p) => [p.idProducto, p.precioUnitario])),
    subtotal,
    propina: delivery && azar() < 0.3 ? 5 : 0,
    costoEnvio,
    ...(delivery ? { zonaEntrega: dir[3] } : {}),
    ...(conCupon ? { codigoCupon: 'BIENVENIDA10' } : {}),
    ...(hoy ? { demoHoy: true } : {}),
    ...MARCA,
  };
  if (repartidor) {
    pedido.idRepartidor = repartidor.id;
    pedido.nombreRepartidor = repartidor.nombre;
    pedido.telefonoRepartidor = repartidor.telefono ?? '';
    if (estado === 'En camino' || estado === 'En el lugar') {
      pedido.ubicacionRepartidor = new GeoPoint(-17.3935 + (azar() - 0.5) * 0.02, -66.157 + (azar() - 0.5) * 0.02);
      pedido.ubicacionActualizada = ts(new Date());
    }
  }
  await w.set(ref, pedido);
  // Igual que la app: junto al pedido va su control/total (lo revisan las reglas).
  await w.set(ref.collection('control').doc('total'), {
    ids: pedido.lineasIds,
    cant: pedido.lineasCant,
    precios: pedido.precios,
    subtotal,
  });
  let hora = fecha;
  for (const e of caminoDeEstados(estado, modalidad)) {
    const quien =
      e === 'Pendiente' ? cliente.id
        : e === 'En camino' || e === 'En el lugar' ? repartidor?.id ?? ctx.admin
          : e === 'En preparación' || e === 'Listo' ? ctx.cocina?.id ?? ctx.admin
            : ctx.cajero?.id ?? ctx.admin;
    await w.set(ref.collection('historialEstados').doc(), {
      estado: e,
      idUsuarioQueCambio: quien,
      comentario: e === 'Cancelado' ? 'El cliente pidió cancelar' : '',
      fecha: ts(hora),
    });
    const siguiente = masMinutos(hora, entero(4, 12));
    hora = siguiente > new Date() ? new Date() : siguiente;
  }
  return { id: ref.id, total, costoEnvio, metodoPago, estado, fecha };
}

async function llenarNegocio(idNegocio, { completo = true, platosSimples, dias: diasPedidos } = {}) {
  const w = new Escritor();
  semilla = [...idNegocio].reduce((a, c) => (a * 31 + c.charCodeAt(0)) % 2147483647, 20261027);
  const negocio = await db.collection('negocios').doc(idNegocio).get();
  if (!negocio.exists) throw new Error(`No existe el restaurante ${idNegocio}. Usa --listar.`);
  console.log(`\n${negocio.data().nombre}`);
  const previos = await db.collection('pedidos').where('idNegocio', '==', idNegocio).where('demoDatos', '==', true).limit(1).get();
  if (!previos.empty) {
    console.log('  Ya tiene datos de ejemplo. Para volver a crearlos, primero corre con --borrar.');
    return;
  }

  // Sucursal: la del Cajero (o de otro empleado) para que vean los pedidos.
  const sucursales = await db.collection('sucursales').where('idNegocio', '==', idNegocio).get();
  const equipo = await cargarPersonal(idNegocio, sucursales.docs);
  let sucursal =
    sucursales.docs.find((s) => s.id === equipo.sucCajero) ??
    sucursales.docs.find((s) => s.data().estado !== false);
  if (!sucursal) {
    const ref = db.collection('sucursales').doc();
    await ref.set({
      nombre: 'Sucursal Central',
      direccion: 'Av. Ballivián #500',
      telefono: negocio.data().telefono ?? '',
      imagenUrl: '',
      estado: true,
      idNegocio,
      horarios: {},
      zonasDelivery: { Centro: 5, Norte: 8, Sur: 10 },
      ...MARCA,
    });
    sucursal = await ref.get();
    console.log('  Sucursal: creé "Sucursal Central"');
  } else if (completo && !sucursal.data().zonasDelivery) {
    await sucursal.ref.update({ zonasDelivery: { Centro: 5, Norte: 8, Sur: 10 }, demoZonas: true });
    console.log('  Sucursal: le agregué zonas de delivery');
  }

  // Personal
  const personal = (await db.collection('usuarios').where('idNegocio', '==', idNegocio).get()).docs.map((d) => ({
    id: d.id,
    ...d.data(),
  }));
  const primero = (rol) => personal.find((u) => u.rol === rol && u.estado !== false);
  const admin = primero('Administrador')?.id ?? 'demo';
  const cajero = primero('Cajero');
  const cocina = primero('Cocina');
  let repartidores = personal.filter((u) => u.rol === 'Repartidor' && u.estado !== false);
  if (repartidores.length === 0) {
    const ref = db.collection('usuarios').doc();
    const r = {
      nombre: 'Marco Delgado (ejemplo)',
      email: `demo.repartidor.${idNegocio.slice(0, 6).toLowerCase()}@example.com`,
      telefono: '+59178787878',
      rol: 'Repartidor',
      fotoPerfil: '',
      idSucursal: equipo.sucRepartidor ?? sucursal.id,
      idNegocio,
      estado: true,
      fechaRegistro: ts(masMinutos(new Date(), -60 * 24 * 40)),
      notificacionesActivas: true,
      ...MARCA,
    };
    await w.set(ref, r);
    repartidores = [{ id: ref.id, ...r }];
    console.log('  Personal: creé un repartidor de ejemplo (sin cuenta para entrar)');
  }

  // Clientes
  const clientes = [];
  const cuantosClientes = completo ? CLIENTES.length : 6;
  for (let i = 0; i < cuantosClientes; i++) {
    const [nombre, telefono] = CLIENTES[i];
    const id = `demo_${idNegocio.slice(0, 8)}_cli${i}`;
    const desde = masMinutos(new Date(), -60 * 24 * entero(35, 120));
    await w.set(db.collection('usuarios').doc(id), {
      nombre,
      email: `demo.cliente${i}.${idNegocio.slice(0, 6).toLowerCase()}@example.com`,
      telefono,
      rol: 'Cliente',
      fotoPerfil: '',
      idSucursal: null,
      idNegocio: null,
      estado: true,
      fechaRegistro: ts(desde),
      notificacionesActivas: true,
      ...MARCA,
    });
    clientes.push({ id, nombre, telefono, desde });
  }

  const productos = await menuDe(idNegocio, w, platosSimples);
  const ctx = { idNegocio, idSucursal: sucursal.id, productos, admin, cajero, cocina };

  // Mesas
  let mesas = [];
  if (completo) {
    const existentes = await sucursal.ref.collection('mesas').get();
    mesas = existentes.docs.map((d) => ({ id: d.id, ref: d.ref, ...d.data() }));
    if (mesas.length === 0) {
      for (let n = 1; n <= 8; n++) {
        const ref = sucursal.ref.collection('mesas').doc();
        const m = { numero: String(n), capacidad: n <= 4 ? 4 : n <= 6 ? 2 : 6, estado: 'Libre', idNegocio, ...MARCA };
        await w.set(ref, m);
        mesas.push({ id: ref.id, ref, ...m });
      }
      console.log('  Mesas: creé 8 mesas');
    }
  }

  // ---------------- historial: pedidos entregados de los últimos 30 días
  const hoy = new Date();
  hoy.setHours(0, 0, 0, 0);
  const ultimoPorCliente = {};
  const dias = diasPedidos ?? (completo ? 30 : 14);
  let cuantosPedidos = 0;
  for (let d = dias; d >= 1; d--) {
    const dia = new Date(hoy.getTime() - d * 86400000);
    const finDeSemana = dia.getDay() === 0 || dia.getDay() === 5 || dia.getDay() === 6;
    const n = completo ? entero(finDeSemana ? 9 : 5, finDeSemana ? 15 : 10) : entero(2, 5);

    // Caja del día (si hay Cajero)
    let caja = null;
    if (cajero && completo) {
      caja = { ref: db.collection('cajas').doc(), efectivo: 0, transferencia: 0, qr: 0, cobros: [] };
    }

    for (let i = 0; i < n; i++) {
      const fecha = new Date(dia);
      fecha.setHours(elegir([12, 12, 13, 13, 14, 19, 20, 20, 21]), entero(0, 59), 0, 0);
      const modalidad = elegir(completo ? ['Mesa', 'Recoger', 'Delivery', 'Delivery', 'Recoger'] : ['Recoger', 'Delivery']);
      const mesa = modalidad === 'Mesa' && mesas.length ? elegir(mesas) : null;
      const cliente = elegir(clientes);
      const estado = azar() < 0.07 ? 'Cancelado' : 'Entregado';
      const metodoPago = elegir(['Efectivo', 'Efectivo', 'QR', 'QR', 'Transferencia']);
      const repartidor = modalidad === 'Delivery' && estado === 'Entregado' ? elegir(repartidores) : null;
      const cobrado = estado === 'Entregado';
      const p = await crearPedido(w, ctx, {
        fecha,
        estado,
        modalidad: mesa || modalidad !== 'Mesa' ? modalidad : 'Recoger',
        mesa,
        cobrado,
        idCaja: cobrado && caja ? caja.ref.id : null,
        repartidor,
        cliente,
        metodoPago,
        origen: modalidad === 'Mesa' && azar() < 0.5 ? 'cajero' : 'cliente',
      });
      cuantosPedidos++;
      ultimoPorCliente[cliente.id] = fecha;
      if (caja && cobrado) {
        const monto = dinero(p.total + p.costoEnvio);
        if (metodoPago === 'Efectivo') caja.efectivo += monto;
        else if (metodoPago === 'QR') caja.qr += monto;
        else caja.transferencia += monto;
        caja.cobros.push({ id: p.id, monto, metodoPago, fecha });
      }
    }

    if (caja) {
      const apertura = new Date(dia);
      apertura.setHours(11, 30, 0, 0);
      const cierre = new Date(dia);
      cierre.setHours(22, 30, 0, 0);
      const inicial = 200;
      const egreso = d % 4 === 0 ? 45 : 0;
      const esperado = dinero(inicial + caja.efectivo - egreso);
      const diferencia = d % 9 === 0 ? -10 : d % 13 === 0 ? 5 : 0;
      await w.set(caja.ref, {
        idNegocio,
        idSucursal: sucursal.id,
        idCajero: cajero.id,
        nombreCajero: cajero.nombre ?? 'Cajero',
        estado: 'Cerrada',
        montoInicial: inicial,
        fechaApertura: ts(apertura),
        montoContado: dinero(esperado + diferencia),
        fechaConteo: ts(cierre),
        fechaCierre: ts(cierre),
        montoEsperado: esperado,
        diferencia,
        observacionCierre: diferencia < 0 ? 'Faltaron Bs 10, se revisó con el administrador' : '',
        totalEfectivo: dinero(caja.efectivo),
        totalTransferencia: dinero(caja.transferencia),
        totalQr: dinero(caja.qr),
        totalIngresos: 0,
        totalEgresos: egreso,
        ...MARCA,
      });
      for (const c of caja.cobros) {
        await w.set(caja.ref.collection('movimientos').doc(`cobro_${c.id}`), {
          tipo: 'Cobro',
          concepto: `Pedido #${c.id.substring(0, 6)}`,
          monto: c.monto,
          metodoPago: c.metodoPago,
          idPedido: c.id,
          idUsuario: cajero.id,
          fecha: ts(c.fecha),
        });
      }
      if (egreso) {
        await w.set(caja.ref.collection('movimientos').doc(), {
          tipo: 'Egreso',
          concepto: 'Compra de gas',
          monto: egreso,
          metodoPago: 'Efectivo',
          idUsuario: cajero.id,
          fecha: ts(masMinutos(apertura, 120)),
        });
      }
    }
  }
  console.log(`  Ventas: ${cuantosPedidos} pedidos de los últimos ${dias} días`);

  // ---------------- hoy: pedidos en curso para Cocina, Cajero y Repartidor
  if (completo) {
    const ahora = new Date();
    const hace = (min) => masMinutos(ahora, -min);
    const enCurso = [
      { estado: 'Pendiente', modalidad: 'Recoger', min: 2 },
      { estado: 'Pendiente', modalidad: 'Delivery', min: 4 },
      { estado: 'Pendiente', modalidad: 'Recoger', min: 6 },
      { estado: 'En preparación', modalidad: 'Recoger', min: 9 },
      { estado: 'En preparación', modalidad: 'Delivery', min: 14 },
      { estado: 'En preparación', modalidad: 'Recoger', min: 26 }, // atrasado (rojo)
      { estado: 'Listo', modalidad: 'Recoger', min: 18 },
      { estado: 'Listo', modalidad: 'Delivery', min: 21 }, // para que un repartidor lo tome
      { estado: 'Listo', modalidad: 'Delivery', min: 16 },
      { estado: 'En camino', modalidad: 'Delivery', min: 30, conRepartidor: true },
      { estado: 'Entregado', modalidad: 'Delivery', min: 70, conRepartidor: true, efectivoSinRendir: true },
      { estado: 'Entregado', modalidad: 'Delivery', min: 95, conRepartidor: true, efectivoSinRendir: true },
      { estado: 'Entregado', modalidad: 'Recoger', min: 50 },
      { estado: 'Entregado', modalidad: 'Recoger', min: 110 },
      { estado: 'Cancelado', modalidad: 'Recoger', min: 80 },
    ];
    for (const e of enCurso) {
      const cliente = elegir(clientes);
      await crearPedido(w, ctx, {
        fecha: hace(e.min),
        hoy: true,
        idSucursal: e.modalidad === 'Delivery' ? equipo.sucRepartidor ?? sucursal.id : sucursal.id,
        estado: e.estado,
        modalidad: e.modalidad,
        cobrado: e.estado === 'Entregado' && !e.efectivoSinRendir,
        repartidor: e.conRepartidor ? repartidores[0] : null,
        cliente,
        metodoPago: e.efectivoSinRendir ? 'Efectivo' : elegir(['Efectivo', 'QR']),
        origen: 'cliente',
      });
      ultimoPorCliente[cliente.id] = hace(e.min);
    }

    // Mesas: dos ocupadas con cuenta abierta y una con todo servido (por cobrar)
    const usar = mesas.slice(0, 3);
    for (const [i, mesa] of usar.entries()) {
      const estados = i === 2 ? ['Entregado', 'Entregado'] : i === 0 ? ['En preparación'] : ['Listo', 'Pendiente'];
      for (const [j, estado] of estados.entries()) {
        await crearPedido(w, ctx, {
          fecha: hace(15 + i * 12 + j * 6),
          hoy: true,
          estado,
          modalidad: 'Mesa',
          mesa,
          cobrado: false,
          cuentaAbierta: true,
          cliente: elegir(clientes),
          metodoPago: 'Por definir',
          origen: 'cajero',
        });
      }
      if (mesa.estado !== 'Ocupada') {
        await w.update(mesa.ref, { estado: 'Ocupada', personas: entero(2, 4), ...(mesa.demoDatos ? {} : { demoOcupada: true }) });
      }
    }
    if (mesas.length > 4 && mesas[4].estado === 'Libre') {
      await w.update(mesas[4].ref, { estado: 'Reservada', ...(mesas[4].demoDatos ? {} : { demoOcupada: true }) });
    }
    console.log('  Hoy: 15 pedidos en curso, 3 mesas ocupadas y 1 reservada');
  }

  // ---------------- clientes del negocio, reseñas y cupones
  const negocioRef = db.collection('negocios').doc(idNegocio);
  for (const c of clientes) {
    await w.set(negocioRef.collection('clientes').doc(c.id), {
      nombre: c.nombre,
      telefono: c.telefono,
      bloqueado: false,
      fechaPrimerPedido: ts(c.desde),
      ultimoPedido: ts(ultimoPorCliente[c.id] ?? c.desde),
      ...MARCA,
    });
  }
  const resenas = completo ? RESENAS : RESENAS.slice(0, 3);
  for (const [i, [calificacion, comentario]] of resenas.entries()) {
    const c = clientes[i % clientes.length];
    const id = `demo_resena_${idNegocio.slice(0, 6)}_${i}`;
    const partes = c.nombre.split(' ');
    await w.set(negocioRef.collection('resenas').doc(id), {
      idNegocio,
      idPedido: id,
      idCliente: c.id,
      nombreCliente: `${partes[0]} ${partes[1]?.[0] ?? ''}.`,
      calificacion,
      comentario,
      fecha: ts(masMinutos(new Date(), -60 * 24 * entero(1, 25))),
      estado: 'Visible',
      ...MARCA,
    });
  }
  if (completo) {
    for (const cu of CUPONES) {
      const ref = negocioRef.collection('cupones').doc(cu.codigo);
      if ((await ref.get()).exists) continue;
      await w.set(ref, {
        tipo: cu.tipo,
        valor: cu.valor,
        minimo: cu.minimo,
        vence: ts(masMinutos(new Date(), 60 * 24 * cu.dias)),
        activo: true,
        descripcion: cu.descripcion,
        ...MARCA,
      });
    }
    console.log(`  ${clientes.length} clientes, ${resenas.length} reseñas y ${CUPONES.length} cupones`);
  }

  await w.cerrar();
  console.log(`  (${w.total} documentos escritos)`);
}

async function crearOtrosNegocios() {
  for (const o of OTROS_NEGOCIOS) {
    const ya = await db.collection('negocios').where('nombre', '==', o.nombre).where('demoDatos', '==', true).get();
    if (!ya.empty) continue;
    const ref = db.collection('negocios').doc();
    await ref.set({
      nombre: o.nombre,
      logoUrl: '',
      bannerUrl: '',
      descripcion: 'Restaurante de ejemplo para la demostración',
      telefono: o.telefono,
      colorPrimario: o.color,
      colorSecundario: '#FFF3E0',
      colorFondo: '',
      modoOscuro: false,
      estado: true,
      qrPagoUrl: '',
      razonSocial: `${o.nombre} S.R.L.`,
      nit: String(1000000000 + entero(0, 899999999)),
      direccion: 'Av. Principal #100',
      ciudad: o.ciudad,
      correoContacto: '',
      estiloBase: 'moderno',
      tipografia: 'sans',
      formaBotones: 'redondeado',
      pais: o.pais,
      ...MARCA,
    });
    await llenarNegocio(ref.id, { completo: false, platosSimples: o.platos });
  }
}


/** Personal del restaurante y la sucursal donde trabaja cada rol. */
async function cargarPersonal(idNegocio, sucursales) {
  const validas = new Set(sucursales.map((s) => s.id));
  const personal = (await db.collection('usuarios').where('idNegocio', '==', idNegocio).get()).docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((u) => u.estado !== false);
  const sucDe = (rol) => personal.find((u) => u.rol === rol && !u.demoDatos && validas.has(u.idSucursal))?.idSucursal;
  const sucCajero = sucDe('Cajero') ?? sucDe('Cocina') ?? sucDe('Repartidor');
  return { personal, sucCajero, sucRepartidor: sucDe('Repartidor') ?? sucCajero };
}

// --------------------------------------------------------------- refrescar
// Pone los pedidos "de hoy" a la hora actual (para el día de la defensa)
// y los pasa a la sucursal donde trabajan el Cajero y el Repartidor.

const ACTIVOS = ['Pendiente', 'En preparación', 'Listo', 'En camino', 'En el lugar'];
const inicioDia = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate());

async function refrescarNegocio(idNegocio) {
  const negocio = await db.collection('negocios').doc(idNegocio).get();
  const qs = await db.collection('pedidos').where('idNegocio', '==', idNegocio).where('demoDatos', '==', true).get();
  if (qs.empty) return;
  const pedidos = qs.docs.map((d) => ({ ref: d.ref, ...d.data(), fecha: d.data().fechaCreacion.toDate() }));
  const ultimo = pedidos.reduce((a, p) => (p.fecha > a ? p.fecha : a), new Date(0));
  const desdeUltimoDia = inicioDia(ultimo);
  const deHoy = pedidos.filter(
    (p) => p.demoHoy || p.cuentaAbierta || ACTIVOS.includes(p.estado) || p.fecha >= desdeUltimoDia,
  );
  if (deHoy.length === 0) return;
  const masNuevo = deHoy.reduce((a, p) => (p.fecha > a ? p.fecha : a), new Date(0));
  const corrimiento = Date.now() - masNuevo.getTime() - 2 * 60000;

  const sucursales = (await db.collection('sucursales').where('idNegocio', '==', idNegocio).get()).docs;
  const equipo = await cargarPersonal(idNegocio, sucursales);
  const w = new Escritor();

  // Mesas: si la sucursal del Cajero es otra, las cuentas abiertas pasan a sus mesas.
  const conMesa = deHoy.filter((p) => p.cuentaAbierta && p.idMesa);
  const mapaMesas = {};
  const sucMesas = equipo.sucCajero;
  if (sucMesas && conMesa.some((p) => p.idSucursal !== sucMesas)) {
    const refSuc = db.collection('sucursales').doc(sucMesas);
    let mesas = (await refSuc.collection('mesas').get()).docs.map((d) => ({ id: d.id, ref: d.ref, ...d.data() }));
    if (mesas.length === 0) {
      for (let n = 1; n <= 8; n++) {
        const ref = refSuc.collection('mesas').doc();
        const m = { numero: String(n), capacidad: 4, estado: 'Libre', idNegocio, ...MARCA };
        await w.set(ref, m);
        mesas.push({ id: ref.id, ref, ...m });
      }
    }
    const viejas = [...new Set(conMesa.map((p) => `${p.idSucursal}|${p.idMesa}`))];
    for (const [i, clave] of viejas.entries()) {
      const nueva = mesas[i % mesas.length];
      mapaMesas[clave] = nueva;
      if (nueva.estado !== 'Ocupada') {
        await w.update(nueva.ref, { estado: 'Ocupada', personas: 3, ...(nueva.demoDatos ? {} : { demoOcupada: true }) });
        nueva.estado = 'Ocupada';
      }
      const [s, m] = clave.split('|');
      const vieja = db.collection('sucursales').doc(s).collection('mesas').doc(m);
      const datos = (await vieja.get()).data();
      if (datos && (datos.demoOcupada || datos.demoDatos)) {
        await w.update(vieja, {
          estado: 'Libre',
          personas: admin.firestore.FieldValue.delete(),
          demoOcupada: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }

  for (const p of deHoy) {
    const cambios = { fechaCreacion: ts(new Date(p.fecha.getTime() + corrimiento)), demoHoy: true };
    const destino = p.modalidad === 'Delivery' ? equipo.sucRepartidor : equipo.sucCajero;
    if (destino && destino !== p.idSucursal) cambios.idSucursal = destino;
    const mesa = mapaMesas[`${p.idSucursal}|${p.idMesa}`];
    if (mesa) {
      cambios.idMesa = mesa.id;
      cambios.numeroMesa = mesa.numero;
    }
    if (p.ubicacionActualizada) cambios.ubicacionActualizada = ts(new Date());
    await w.update(p.ref, cambios);
    for (const h of (await p.ref.collection('historialEstados').get()).docs) {
      const f = h.data().fecha?.toDate();
      if (f) await w.update(h.ref, { fecha: ts(new Date(Math.min(f.getTime() + corrimiento, Date.now()))) });
    }
  }
  await w.cerrar();
  console.log(`${negocio.data()?.nombre ?? idNegocio}: ${deHoy.length} pedidos de hoy actualizados (${w.total} escrituras)`);
}

async function refrescar(idNegocio) {
  if (idNegocio) return refrescarNegocio(idNegocio);
  for (const n of (await db.collection('negocios').get()).docs) await refrescarNegocio(n.id);
}

// ----------------------------------------------------------------- cliente
// Pedidos de ejemplo para TU cuenta de cliente (Mis pedidos, Pedir de
// nuevo, seguimiento y reseñas).

async function clienteDemo(correo, idNegocio) {
  const buscados = await db.collection('usuarios').where('email', '==', correo.trim().toLowerCase()).get();
  let doc = buscados.docs[0];
  if (!doc) {
    try {
      const u = await admin.auth().getUserByEmail(correo.trim());
      const d = await db.collection('usuarios').doc(u.uid).get();
      if (d.exists) doc = d;
    } catch {
      // No existe en Auth.
    }
  }
  if (!doc) throw new Error(`No encontré la cuenta ${correo}. Revisa el correo (debe estar registrada en la app).`);
  const usuario = { id: doc.id, ...doc.data() };
  if (usuario.rol !== 'Cliente') throw new Error(`La cuenta ${correo} es ${usuario.rol}, no Cliente.`);

  const negocioRef = db.collection('negocios').doc(idNegocio);
  const negocio = await negocioRef.get();
  if (!negocio.exists) throw new Error(`No existe el restaurante ${idNegocio}. Usa --listar.`);
  const ya = await db.collection('pedidos').where('idCliente', '==', usuario.id).where('demoDatos', '==', true).limit(1).get();
  if (!ya.empty) {
    console.log(`${usuario.nombre} ya tiene pedidos de ejemplo.`);
    return;
  }

  const sucursales = (await db.collection('sucursales').where('idNegocio', '==', idNegocio).get()).docs;
  const equipo = await cargarPersonal(idNegocio, sucursales);
  const idSucursal = equipo.sucCajero ?? sucursales.find((s) => s.data().estado !== false)?.id;
  if (!idSucursal) throw new Error('El restaurante no tiene sucursales. Primero llénalo con --negocio.');
  const w = new Escritor();
  const productos = await menuDe(idNegocio, w);
  const primero = (rol) => equipo.personal.find((u) => u.rol === rol);
  const ctx = {
    idNegocio,
    idSucursal,
    productos,
    admin: primero('Administrador')?.id ?? 'demo',
    cajero: primero('Cajero'),
    cocina: primero('Cocina'),
  };
  const repartidor = primero('Repartidor');
  const cliente = { id: usuario.id, nombre: usuario.nombre, telefono: usuario.telefono ?? '' };
  const ahora = new Date();
  const hace = (dias, horas) => masMinutos(ahora, -(dias * 24 * 60 + horas * 60));

  const entregados = [];
  for (const [dias, modalidad] of [[12, 'Recoger'], [6, 'Delivery'], [2, 'Mesa']]) {
    const p = await crearPedido(w, ctx, {
      fecha: hace(dias, 3),
      estado: 'Entregado',
      modalidad: modalidad === 'Delivery' && !repartidor ? 'Recoger' : modalidad,
      cobrado: true,
      repartidor: modalidad === 'Delivery' ? repartidor : null,
      cliente,
      metodoPago: 'QR',
      origen: 'cliente',
    });
    entregados.push(p);
  }
  await crearPedido(w, ctx, {
    fecha: masMinutos(ahora, -8),
    hoy: true,
    estado: 'En preparación',
    modalidad: 'Recoger',
    cobrado: false,
    cliente,
    metodoPago: 'Efectivo',
    origen: 'cliente',
  });

  // Ya dejó reseña en el más antiguo; en los otros dos puede dejarla en la demo.
  await w.set(negocioRef.collection('resenas').doc(entregados[0].id), {
    idNegocio,
    idPedido: entregados[0].id,
    idCliente: usuario.id,
    nombreCliente: usuario.nombre.split(' ').slice(0, 2).map((x, i) => (i ? `${x[0]}.` : x)).join(' '),
    calificacion: 5,
    comentario: 'Todo muy rico, volveré a pedir.',
    fecha: ts(hace(11, 0)),
    estado: 'Visible',
    ...MARCA,
  });

  const cliRef = negocioRef.collection('clientes').doc(usuario.id);
  if (!(await cliRef.get()).exists) {
    await w.set(cliRef, {
      nombre: usuario.nombre,
      telefono: usuario.telefono ?? '',
      bloqueado: false,
      fechaPrimerPedido: ts(hace(12, 3)),
      ultimoPedido: ts(ahora),
      ...MARCA,
    });
  }
  // Que el restaurante aparezca en su inicio (como si hubiera entrado con el código).
  const mio = db.collection('usuarios').doc(usuario.id).collection('misNegocios').doc(idNegocio);
  if (!(await mio.get()).exists) {
    // El código ahora está en negocios/{id}/privado/acceso (ya no en el negocio).
    const acceso = await negocioRef.collection('privado').doc('acceso').get();
    await w.set(mio, { codigo: acceso.data()?.codigo ?? '', fecha: ts(hace(12, 4)), ...MARCA });
  }
  await w.cerrar();
  await db.collection('plataforma').doc('demoDatos').set(
    { clientes: admin.firestore.FieldValue.arrayUnion(usuario.id) },
    { merge: true },
  );
  console.log(`${usuario.nombre}: 4 pedidos de ejemplo en ${negocio.data().nombre} (3 entregados y 1 en preparación).`);
}

// -------------------------------------------------------------------- borrar

async function borrarTodo() {
  let n = 0;
  const borrarConsulta = async (consulta, recursivo = false) => {
    const qs = await consulta.get();
    for (const d of qs.docs) {
      if (recursivo) await db.recursiveDelete(d.ref);
      else await d.ref.delete();
      n++;
    }
  };
  console.log('Borrando pedidos de ejemplo...');
  await borrarConsulta(db.collection('pedidos').where('demoDatos', '==', true), true);
  console.log('Borrando cajas de ejemplo...');
  await borrarConsulta(db.collection('cajas').where('demoDatos', '==', true), true);

  console.log('Borrando restaurantes de ejemplo...');
  const negociosDemo = await db.collection('negocios').where('demoDatos', '==', true).get();
  const idsDemo = new Set(negociosDemo.docs.map((d) => d.id));
  for (const d of negociosDemo.docs) {
    await db.recursiveDelete(d.ref);
    n++;
  }

  console.log('Limpiando restaurantes reales...');
  for (const neg of (await db.collection('negocios').get()).docs) {
    for (const sub of ['clientes', 'resenas', 'cupones']) {
      await borrarConsulta(neg.ref.collection(sub).where('demoDatos', '==', true));
    }
  }

  console.log('Borrando menú, sucursales y mesas de ejemplo...');
  // Antes de borrar los productos de ejemplo, se quitan de la lista de
  // precios de los restaurantes reales.
  const borrarCampo = admin.firestore.FieldValue.delete();
  for (const d of (await db.collection('productos').where('demoDatos', '==', true).get()).docs) {
    const idNeg = d.data().idNegocio;
    if (!idNeg || idsDemo.has(idNeg)) continue;
    try {
      await db.collection('negocios').doc(idNeg).collection('publico').doc('precios').update({
        [`normal.${d.id}`]: borrarCampo,
        [`promo.${d.id}`]: borrarCampo,
        [`hasta.${d.id}`]: borrarCampo,
      });
    } catch {
      // Ese restaurante no tiene lista de precios.
    }
  }
  await borrarConsulta(db.collection('productos').where('demoDatos', '==', true));
  await borrarConsulta(db.collection('categorias').where('demoDatos', '==', true));
  for (const s of (await db.collection('sucursales').get()).docs) {
    const d = s.data();
    if (d.demoDatos || idsDemo.has(d.idNegocio)) {
      await db.recursiveDelete(s.ref);
      n++;
      continue;
    }
    if (d.demoZonas) {
      await s.ref.update({ zonasDelivery: admin.firestore.FieldValue.delete(), demoZonas: admin.firestore.FieldValue.delete() });
    }
    for (const m of (await s.ref.collection('mesas').get()).docs) {
      if (m.data().demoDatos) {
        await m.ref.delete();
        n++;
      } else if (m.data().demoOcupada) {
        await m.ref.update({
          estado: 'Libre',
          personas: admin.firestore.FieldValue.delete(),
          demoOcupada: admin.firestore.FieldValue.delete(),
        });
      }
    }
  }

  const registro = await db.collection('plataforma').doc('demoDatos').get();
  for (const uid of registro.data()?.clientes ?? []) {
    await borrarConsulta(db.collection('usuarios').doc(uid).collection('misNegocios').where('demoDatos', '==', true));
  }
  if (registro.exists) await registro.ref.delete();

  console.log('Borrando clientes y repartidores de ejemplo...');
  await borrarConsulta(db.collection('usuarios').where('demoDatos', '==', true));
  console.log(`\nListo: ${n} documentos de ejemplo borrados.`);
}

// ---------------------------------------------------------------------- main

if (args.includes('--listar')) {
  await listar();
} else if (args.includes('--borrar')) {
  await borrarTodo();
} else if (args.includes('--refrescar')) {
  await refrescar(opcion('--negocio'));
  console.log('\nListo. Recarga la app.');
} else if (opcion('--cliente')) {
  await clienteDemo(opcion('--cliente'), opcion('--negocio') ?? 'principal');
  console.log('\nListo. Entra con esa cuenta de cliente para verlos.');
} else if (args.includes('--todos')) {
  for (const n of (await db.collection('negocios').get()).docs) {
    if (n.data().demoDatos) continue;
    // 10 días por restaurante para no pasar el límite gratuito de escrituras.
    await llenarNegocio(n.id, { dias: 10 });
  }
  await crearOtrosNegocios();
  console.log('\nListo. Recarga la app para ver los datos.');
} else if (opcion('--negocio')) {
  await llenarNegocio(opcion('--negocio'));
  await crearOtrosNegocios();
  console.log('\nListo. Recarga la app para ver los datos.');
} else {
  console.error('Falta una opción: --listar, --negocio ID, --todos, --refrescar, --cliente CORREO o --borrar');
  process.exit(1);
}
process.exit(0);
