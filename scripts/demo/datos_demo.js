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
//   node datos_demo.js LLAVE --mover-fechas --todos [--dia AAAA-MM-DD]
//                                                   correr las fechas: el historial termina el día
//                                                   anterior a --dia (por defecto hoy) y los pedidos
//                                                   "de hoy" quedan en ese día (o --negocio ID)
//   node datos_demo.js LLAVE --ampliar --todos [--dia AAAA-MM-DD]
//                                                   completar 60 días de historial (para comparar
//                                                   periodos). Va después de --mover-fechas
//   node datos_demo.js LLAVE --pulir                textos, personal y reseñas creíbles en los
//                                                   restaurantes de ejemplo (no crea cuentas)
//   --max N   tope de escrituras de la corrida (por defecto 18000; el plan gratis permite 20000 por día)
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

/** Motivos de cancelación variados (como los escribe el personal). */
const MOTIVOS_CANCELACION = [
  'El cliente pidió cancelar',
  'El cliente no contestó el teléfono para confirmar la dirección',
  'Se terminó el producto y el cliente no quiso cambiarlo',
  'Dirección fuera de la zona de delivery',
  'Pedido duplicado por error',
  'El cliente cambió de planes',
  'Demora en la cocina por pedido grande; el cliente prefirió cancelar',
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
  // Dirección y teléfono van aparte, en privado/contacto (como en la app):
  // la Cocina no los ve.
  if (delivery) {
    await w.set(ref.collection('privado').doc('contacto'), {
      direccionEntrega: {
        etiqueta: dir[0],
        direccion: dir[1],
        referencia: dir[2],
        latitud: -17.3935 + (azar() - 0.5) * 0.04,
        longitud: -66.157 + (azar() - 0.5) * 0.04,
      },
      telefonoCliente: cliente.telefono,
    });
  }
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
      comentario: e === 'Cancelado' ? `Motivo: ${elegir(MOTIVOS_CANCELACION)}` : '',
      fecha: ts(hora),
    });
    if (e === 'Cancelado') await w.update(ref, { fechaCancelacion: ts(hora) });
    const siguiente = masMinutos(hora, entero(4, 12));
    // Si el pedido es de ahora, su historial no puede quedar en el futuro.
    // (Los pedidos que se crean para un día que todavía no llega, con
    // --dia, los acomoda --refrescar ese día.)
    hora = siguiente > new Date() && fecha <= new Date() ? new Date() : siguiente;
  }
  return { id: ref.id, total, costoEnvio, metodoPago, estado, fecha };
}

/**
 * Pedidos de un día del historial (entregados y algunos cancelados) y, si hay
 * Cajero y es el restaurante completo, la caja cerrada de ese día.
 * [d] = cuántos días antes de "hoy" (solo para variar egresos y diferencias).
 * [factor] escala la cantidad de pedidos (menos de 1 = días más flojos).
 * Devuelve cuántos pedidos creó.
 */
async function generarDia(w, ctx, { dia, d, completo, clientes, mesas, cajero, sucursal, repartidores, ultimoPorCliente, factor = 1 }) {
  const idNegocio = ctx.idNegocio;
  let creados = 0;
  const finDeSemana = dia.getDay() === 0 || dia.getDay() === 5 || dia.getDay() === 6;
  const n = Math.max(1, Math.round((completo ? entero(finDeSemana ? 9 : 5, finDeSemana ? 15 : 10) : entero(2, 5)) * factor));

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
    creados++;
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
  return creados;
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
    cuantosPedidos += await generarDia(w, ctx, { dia, d, completo, clientes, mesas, cajero, sucursal, repartidores, ultimoPorCliente });
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

const DIA = 24 * 60 * 60000;
const correr = (t, dias) => ts(new Date(t.toDate().getTime() + dias * DIA));
const diasEntre = (a, b) => Math.round((inicioDia(b) - inicioDia(a)) / DIA);

/** Día de la demostración: --dia AAAA-MM-DD (por defecto, hoy). */
function diaObjetivo() {
  const texto = opcion('--dia');
  if (!texto) return inicioDia(new Date());
  const [a, m, d] = texto.split('-').map(Number);
  if (!a || !m || !d) throw new Error(`Fecha no válida en --dia: ${texto} (usa AAAA-MM-DD, por ejemplo 2026-11-25)`);
  return new Date(a, m - 1, d);
}

/** Tope de escrituras de esta corrida (--max N). Por defecto 18.000. */
const LIMITE_ESCRITURAS = Number(opcion('--max') ?? 18000);
let escriturasHechas = 0;

/** Restaurantes que tienen pedidos de ejemplo (para --todos). */
async function negociosConDemo() {
  const lista = [];
  for (const n of (await db.collection('negocios').get()).docs) {
    const q = await db.collection('pedidos').where('idNegocio', '==', n.id).where('demoDatos', '==', true).limit(1).get();
    if (!q.empty) lista.push({ id: n.id, demo: n.data().demoDatos === true });
  }
  // Primero el restaurante principal, luego los reales y al final los de
  // ejemplo: si se llega al tope, lo que queda para otro día es lo menos visto.
  const orden = (x) => (x.id === 'principal' ? 0 : x.demo ? 2 : 1);
  return lista.sort((a, b) => orden(a) - orden(b)).map((x) => x.id);
}

/** Clientes de ejemplo (demo_...) o una cuenta real cargada con --cliente. */
const esDeEjemplo = (id) => String(id ?? '').startsWith('demo_');

/**
 * Corre las fechas de los datos de ejemplo de un restaurante para que el
 * historial termine el día anterior a [objetivo] y los pedidos "de hoy"
 * (demoHoy) caigan en [objetivo]. Toca pedidos y su historial, cajas y sus
 * movimientos, reseñas, fichas de clientes y vencimiento de cupones; solo lo
 * marcado como ejemplo.
 *
 * El corrimiento se calcula SIN los pedidos "de hoy": --refrescar los pone
 * a la hora actual, y si se contaran el script creería que todo está al día
 * aunque el historial siga en octubre. Los pedidos de las cuentas reales
 * (--cliente) se corren aparte, porque se cargaron otro día.
 *
 * Primero cuenta cuántas escrituras necesita y, si pasan del tope, no
 * escribe nada (así nunca queda un restaurante a medio mover).
 */
async function moverFechas(idNegocio, objetivo) {
  const negocioRef = db.collection('negocios').doc(idNegocio);
  const nombre = (await negocioRef.get()).data()?.nombre ?? idNegocio;
  const pedidos = (await db.collection('pedidos').where('idNegocio', '==', idNegocio).where('demoDatos', '==', true).get()).docs;
  if (pedidos.length === 0) {
    console.log(`${nombre}: no tiene pedidos de ejemplo.`);
    return;
  }

  // Cuántos días se corre cada grupo (historial de ejemplo / cuentas reales).
  const corrimiento = { ejemplo: 0, cuenta: 0 };
  for (const grupo of ['ejemplo', 'cuenta']) {
    const hist = pedidos.filter(
      (p) => !p.data().demoHoy && (grupo === 'ejemplo') === esDeEjemplo(p.data().idCliente),
    );
    if (hist.length === 0) continue;
    const ultimo = new Date(hist.reduce((a, p) => Math.max(a, p.data().fechaCreacion.toMillis()), 0));
    corrimiento[grupo] = diasEntre(ultimo, objetivo) - 1;
  }

  // Plan de cambios (todavía no escribe nada).
  const cambios = [];
  for (const p of pedidos) {
    const datos = p.data();
    const dias = datos.demoHoy
      ? diasEntre(datos.fechaCreacion.toDate(), objetivo)
      : corrimiento[esDeEjemplo(datos.idCliente) ? 'ejemplo' : 'cuenta'];
    if (dias === 0) continue;
    const c = { fechaCreacion: correr(datos.fechaCreacion, dias) };
    if (datos.fechaCancelacion) c.fechaCancelacion = correr(datos.fechaCancelacion, dias);
    cambios.push([p.ref, c]);
    for (const h of (await p.ref.collection('historialEstados').get()).docs) {
      if (h.data().fecha) cambios.push([h.ref, { fecha: correr(h.data().fecha, dias) }]);
    }
  }

  const dias = corrimiento.ejemplo;
  let cuantasCajas = 0;
  if (dias !== 0) {
    const cajas = (await db.collection('cajas').where('idNegocio', '==', idNegocio).where('demoDatos', '==', true).get()).docs;
    cuantasCajas = cajas.length;
    for (const c of cajas) {
      const cc = {};
      for (const campo of ['fechaApertura', 'fechaConteo', 'fechaCierre']) {
        if (c.data()[campo]) cc[campo] = correr(c.data()[campo], dias);
      }
      if (Object.keys(cc).length > 0) cambios.push([c.ref, cc]);
      for (const m of (await c.ref.collection('movimientos').get()).docs) {
        if (m.data().fecha) cambios.push([m.ref, { fecha: correr(m.data().fecha, dias) }]);
      }
    }
    for (const cu of (await negocioRef.collection('cupones').where('demoDatos', '==', true).get()).docs) {
      if (cu.data().vence) cambios.push([cu.ref, { vence: correr(cu.data().vence, dias) }]);
    }
  }
  for (const r of (await negocioRef.collection('resenas').where('demoDatos', '==', true).get()).docs) {
    const d = r.id.startsWith('demo_resena_') ? corrimiento.ejemplo : corrimiento.cuenta;
    if (d !== 0 && r.data().fecha) cambios.push([r.ref, { fecha: correr(r.data().fecha, d) }]);
  }
  for (const c of (await negocioRef.collection('clientes').where('demoDatos', '==', true).get()).docs) {
    const d = esDeEjemplo(c.id) ? corrimiento.ejemplo : corrimiento.cuenta;
    if (d === 0) continue;
    const cc = {};
    for (const campo of ['fechaPrimerPedido', 'ultimoPedido']) {
      if (c.data()[campo]) cc[campo] = correr(c.data()[campo], d);
    }
    if (Object.keys(cc).length > 0) cambios.push([c.ref, cc]);
  }

  if (cambios.length === 0) {
    console.log(`${nombre}: las fechas ya están al día.`);
    return;
  }
  if (escriturasHechas + cambios.length > LIMITE_ESCRITURAS) {
    console.log(
      `${nombre}: necesita ${cambios.length} escrituras y solo quedan ${LIMITE_ESCRITURAS - escriturasHechas} ` +
        `del tope (--max). No toqué nada; córrelo mañana o sube --max.`,
    );
    return;
  }
  const w = new Escritor();
  for (const [ref, c] of cambios) await w.update(ref, c);
  await w.cerrar();
  escriturasHechas += w.total;
  console.log(
    `${nombre}: historial corrido ${corrimiento.ejemplo} días` +
      (corrimiento.cuenta ? `, pedidos de cuentas reales ${corrimiento.cuenta} días` : '') +
      `, ${cuantasCajas} cajas (${w.total} escrituras).`,
  );
}

// ----------------------------------------------------------------- ampliar
// Completa el historial hasta 60 días antes del día de la demostración: los
// paneles comparan cada periodo con el anterior (hoy con ayer, 7 días con
// los 7 anteriores, 30 días con los 30 anteriores) y sin ese historial las
// comparaciones salen vacías. Agrega días HACIA ATRÁS desde el pedido más
// antiguo que ya existe: no toca ni repite lo que ya hay, y si se corta por
// el tope de escrituras se vuelve a correr otro día y sigue donde quedó.
// Los días más antiguos tienen un poco menos de pedidos, así los paneles
// muestran crecimiento. Si un restaurante no tiene pedidos "de hoy", le
// agrega unos pocos (para que "Hoy" no salga en cero).

const DIAS_HISTORIAL = 60;

async function ampliarNegocio(idNegocio, objetivo) {
  const negocioRef = db.collection('negocios').doc(idNegocio);
  const negocio = await negocioRef.get();
  const nombre = negocio.data()?.nombre ?? idNegocio;
  semilla = [...idNegocio].reduce((a, c) => (a * 37 + c.charCodeAt(0)) % 2147483647, 20261124);
  const pedidos = (await db.collection('pedidos').where('idNegocio', '==', idNegocio).where('demoDatos', '==', true).get()).docs
    .map((d) => d.data())
    .filter((p) => esDeEjemplo(p.idCliente));
  const hist = pedidos.filter((p) => !p.demoHoy);
  if (hist.length === 0) {
    console.log(`${nombre}: no tiene historial de ejemplo (primero llénalo con --negocio).`);
    return;
  }
  const masNuevo = new Date(hist.reduce((a, p) => Math.max(a, p.fechaCreacion.toMillis()), 0));
  if (diasEntre(masNuevo, objetivo) > 1) {
    console.log(`${nombre}: el historial termina el ${masNuevo.toLocaleDateString('es-BO')}. Primero corre --mover-fechas con el mismo --dia.`);
    return;
  }
  const masViejo = inicioDia(new Date(hist.reduce((a, p) => Math.min(a, p.fechaCreacion.toMillis()), Infinity)));
  const desde = new Date(objetivo.getTime() - DIAS_HISTORIAL * DIA);
  const faltan = diasEntre(desde, masViejo);

  const completo = !negocio.data()?.demoDatos;
  // La sucursal que más pedidos tiene (donde trabaja el personal).
  const conteo = {};
  for (const p of hist) conteo[p.idSucursal] = (conteo[p.idSucursal] ?? 0) + 1;
  const idSucursal = Object.entries(conteo).sort((a, b) => b[1] - a[1])[0][0];
  const sucursal = await db.collection('sucursales').doc(idSucursal).get();
  const personal = (await db.collection('usuarios').where('idNegocio', '==', idNegocio).get()).docs
    .map((d) => ({ id: d.id, ...d.data() }))
    .filter((u) => u.estado !== false);
  const primero = (rol) => personal.find((u) => u.rol === rol);
  const cajero = primero('Cajero');
  const repartidores = personal.filter((u) => u.rol === 'Repartidor');
  const clientes = (await negocioRef.collection('clientes').where('demoDatos', '==', true).get()).docs
    .filter((d) => esDeEjemplo(d.id))
    .map((d) => ({ id: d.id, nombre: d.data().nombre, telefono: d.data().telefono ?? '' }));
  if (clientes.length === 0) {
    console.log(`${nombre}: no encontré clientes de ejemplo.`);
    return;
  }
  const mesas = completo && sucursal.exists
    ? (await sucursal.ref.collection('mesas').get()).docs.map((d) => ({ id: d.id, ref: d.ref, ...d.data() }))
    : [];
  const w = new Escritor();
  const productos = await menuDe(idNegocio, w);
  const ctx = { idNegocio, idSucursal, productos, admin: primero('Administrador')?.id ?? 'demo', cajero, cocina: primero('Cocina') };
  const ultimoPorCliente = {};

  // Cuánto puede escribir un día como máximo (para no pasar del tope).
  const maxPorDia = completo ? 15 * 9 + 60 : 5 * 8 + 10;
  let creados = 0;
  let diasHechos = 0;
  for (let k = 1; k <= faltan; k++) {
    if (escriturasHechas + w.total + maxPorDia > LIMITE_ESCRITURAS) break;
    const dia = new Date(masViejo.getTime() - k * DIA);
    const antes = diasEntre(dia, objetivo);
    creados += await generarDia(w, ctx, {
      dia, d: antes, completo, clientes, mesas, cajero, sucursal, repartidores, ultimoPorCliente,
      factor: antes > 30 ? 0.75 : 0.85,
    });
    await w.cerrar();
    diasHechos++;
  }

  // Pedidos "de hoy" para los restaurantes que no tienen ninguno.
  let deHoy = 0;
  if (!pedidos.some((p) => p.demoHoy) && escriturasHechas + w.total + 60 <= LIMITE_ESCRITURAS) {
    const esHoy = diasEntre(new Date(), objetivo) === 0;
    const base = esHoy ? new Date() : masMinutos(objetivo, 13 * 60);
    for (const [estado, modalidad, min] of [['Entregado', 'Recoger', 95], ['Entregado', 'Delivery', 70], ['Listo', 'Recoger', 15], ['Pendiente', 'Delivery', 4]]) {
      const conRepartidor = modalidad === 'Delivery' && estado === 'Entregado' && repartidores.length > 0;
      await crearPedido(w, ctx, {
        fecha: masMinutos(base, -min),
        hoy: true,
        estado,
        modalidad,
        cobrado: estado === 'Entregado',
        repartidor: conRepartidor ? repartidores[0] : null,
        cliente: elegir(clientes),
        metodoPago: elegir(['Efectivo', 'QR']),
        origen: 'cliente',
      });
      deHoy++;
    }
    await w.cerrar();
  }
  escriturasHechas += w.total;
  const resto = faltan - diasHechos;
  console.log(
    `${nombre}: ${creados} pedidos en ${diasHechos} días más de historial` +
      (deHoy ? ` y ${deHoy} pedidos de hoy` : '') +
      ` (${w.total} escrituras)` +
      (resto > 0 ? `. Faltan ${resto} días: llegó al tope, córrelo otra vez mañana.` : faltan <= 0 ? '. Ya tenía los 60 días.' : '.'),
  );
}

// ------------------------------------------------------------------- pulir
// Deja creíbles los restaurantes de ejemplo: descripción y dirección reales,
// nombre de sucursal, personal (sin cuentas de acceso: no crea usuarios en
// Authentication), repartidor sin "(ejemplo)", clientes con nombres propios
// de cada ciudad, reseñas que hablan de SU menú y solicitudes pendientes que
// no repiten restaurantes que ya funcionan. Se puede correr más de una vez.

const PULIR = {
  'Cevichería Mar Azul': {
    descripcion: 'Ceviches y mariscos frescos del día, al estilo limeño.',
    direccion: 'Av. Petit Thouars 5120, Miraflores', sucursal: 'Miraflores', correo: 'pedidos@marazul.example.com',
    personal: [['Administrador', 'Renzo Salazar'], ['Cajero', 'Milagros Huamán'], ['Cocina', 'Julio Ccori']],
    repartidor: 'Diego Paredes',
    clientes: ['Lucía Mendoza', 'Martín Quispe', 'Valeria Rojas', 'Sebastián Castro', 'Camila Torres', 'Andrés Vílchez'],
    resenas: [
      [5, 'El ceviche clásico estaba fresquísimo y con el punto justo de limón.'],
      [5, 'La jalea mixta llegó crocante y bien servida. Muy recomendable.'],
      [4, 'Rico el arroz con mariscos; el delivery tardó unos minutos más.'],
      [5, 'La chicha morada es casera de verdad. Volveremos.'],
      [4, 'Buena atención y porciones generosas para el precio.'],
    ],
  },
  'Taquería La Esquina': {
    descripcion: 'Tacos al pastor, tortas ahogadas y aguas frescas de la casa.',
    direccion: 'Av. Chapultepec Sur 215, Col. Americana', sucursal: 'Chapultepec', correo: 'hola@laesquina.example.com',
    personal: [['Administrador', 'Ana Gutiérrez'], ['Cajero', 'Luis Navarro'], ['Cocina', 'Rosa Jiménez']],
    repartidor: 'Iván Ramírez',
    clientes: ['Fernanda López', 'Ricardo Hernández', 'Daniela Ortiz', 'Alejandro Ruiz', 'Paola Sánchez', 'Jorge Cárdenas'],
    resenas: [
      [5, 'Los tacos al pastor son los mejores de la colonia. La salsa verde, increíble.'],
      [5, 'La torta ahogada pica rico y llega bien empacada.'],
      [4, 'Buena quesadilla; el agua de horchata un poco dulce para mi gusto.'],
      [5, 'Pedí para la oficina y todo llegó a tiempo y caliente.'],
      [4, 'Precios justos y buen sabor. Repetiré.'],
    ],
  },
  'Salteñería Doña Mari': {
    descripcion: 'Salteñas jugosas horneadas cada mañana desde 2015.',
    direccion: 'Calle Junín #415, zona Central', sucursal: 'Central', correo: 'pedidos@donamari.example.com',
    personal: [['Administrador', 'Mariela Quispe'], ['Cajero', 'Rubén Aguilar'], ['Cocina', 'Teodora Condori']],
    repartidor: 'Wilson Mamani',
    clientes: ['Rocío Arancibia', 'Gonzalo Padilla', 'Ximena Barrientos', 'Mauricio Sandoval', 'Patricia Calvimontes', 'Álvaro Durán'],
    resenas: [
      [5, 'Las salteñas de pollo son jugosas como deben ser. Llegaron calientitas.'],
      [5, 'El api morado con las empanadas, perfecto para la mañana.'],
      [4, 'Muy ricas; a las 10 ya se acaban las de carne, hay que pedir temprano.'],
      [5, 'La mejor salteña de Sucre, sin exagerar.'],
      [4, 'Buen precio y atención amable.'],
    ],
  },
  'Café Altura': {
    descripcion: 'Café de especialidad de los Yungas, repostería y sándwiches.',
    direccion: 'Av. 20 de Octubre #2340, Sopocachi', sucursal: 'Sopocachi', correo: 'hola@cafealtura.example.com',
    personal: [['Administrador', 'Lucía Fernández'], ['Cajero', 'Marcelo Ticona'], ['Cocina', 'Elena Choque']],
    repartidor: 'Franz Apaza',
    clientes: ['Natalia Loza', 'Pablo Urquizo', 'Andrea Salinas', 'Rodrigo Valda', 'Carla Morales', 'Esteban Rivero'],
    resenas: [
      [5, 'El capuchino tiene muy buen cuerpo y la torta de chocolate es húmeda.'],
      [5, 'Ideal para pedir a la oficina, el café llega caliente.'],
      [4, 'Rico el sándwich de pollo; me gustaría más variedad de jugos.'],
      [5, 'Café de verdad, se nota que es de los Yungas.'],
      [4, 'Lugar tranquilo y buena atención.'],
    ],
  },
  'Parrillada El Gaucho': {
    descripcion: 'Parrilla a leña con carnes chapacas y vino tarijeño.',
    direccion: 'Av. La Paz esquina Ciro Trigo #780', sucursal: 'Las Panosas', correo: 'reservas@elgaucho.example.com',
    personal: [['Administrador', 'Óscar Baldiviezo'], ['Cajero', 'Silvia Ruiz'], ['Cocina', 'Ramiro Echazú']],
    repartidor: 'Hernán Vaca',
    clientes: ['Mónica Castellanos', 'Julián Arce', 'Verónica Ávila', 'Cristian Mealla', 'Lorena Tejerina', 'Marcos Gareca'],
    resenas: [
      [5, 'La parrillada para dos alcanza para tres. Carne en su punto.'],
      [5, 'El chorizo tarijeño es buenísimo, con su llajua.'],
      [4, 'Muy rica la carne; la ensalada podría ser más grande.'],
      [5, 'El vino de la casa acompaña perfecto. Excelente para el domingo.'],
      [4, 'Buena atención, el pedido llegó bien empacado.'],
    ],
  },
  'Pizzería Don Vito': {
    descripcion: 'Pizza al horno de piedra y pastas caseras.',
    direccion: 'Av. Pando #1120, Recoleta', sucursal: 'Recoleta', correo: 'pedidos@donvito.example.com',
    personal: [['Administrador', 'Vittorio Lanza'], ['Cajero', 'Jimena Rocha'], ['Cocina', 'Freddy Montaño']],
    repartidor: 'Kevin Terrazas',
    clientes: ['Sofía Antezana', 'Diego Camacho', 'Valentina Prado', 'Joaquín Veizaga', 'Mariana Soria', 'Bruno Zambrana'],
    resenas: [
      [5, 'La pizza margarita tiene masa delgada y crocante, como en Italia.'],
      [5, 'La lasaña es casera y bien cargada. Muy recomendada.'],
      [4, 'Rica la pepperoni; llegó un poco tibia por la lluvia.'],
      [5, 'Pedimos para el cumpleaños y todos quedaron felices.'],
      [4, 'Buena relación precio y calidad.'],
    ],
  },
  'Sushi Kento': {
    descripcion: 'Sushi, ramen y cocina nikkei preparados al momento.',
    direccion: 'Av. San Martín #455, Equipetrol', sucursal: 'Equipetrol', correo: 'hola@kento.example.com',
    personal: [['Administrador', 'Kenji Nakamura'], ['Cajero', 'Daniela Justiniano'], ['Cocina', 'Hiroshi Taira']],
    repartidor: 'Luis Añez',
    clientes: ['Gabriela Suárez', 'Fabián Roca', 'Melissa Saucedo', 'Renato Áñez', 'Carolina Vaca', 'Ignacio Paz'],
    resenas: [
      [5, 'El roll acevichado es espectacular, pescado muy fresco.'],
      [5, 'El ramen tiene un caldo con mucho sabor. Perfecto para la noche.'],
      [4, 'Ricas las gyozas; me gustaría que traigan más salsa de soya.'],
      [5, 'Presentación impecable, todo llegó ordenado.'],
      [4, 'Buen sushi en Santa Cruz, volveré a pedir.'],
    ],
  },
  'Burger Andina': {
    descripcion: 'Hamburguesas de carne andina a la parrilla y batidos naturales.',
    direccion: 'Calle 21 de Calacoto #8050', sucursal: 'Calacoto', correo: 'pedidos@burgerandina.example.com',
    personal: [['Administrador', 'Sergio Villca'], ['Cajero', 'Fabiola Quisbert'], ['Cocina', 'Edwin Limachi']],
    repartidor: 'Ronald Huanca',
    clientes: ['Daniela Pinto', 'Miguel Ángel Rada', 'Fernanda Chávez', 'Hugo Alanoca', 'Brenda Calle', 'Samuel Copa'],
    resenas: [
      [5, 'La hamburguesa doble es enorme y jugosa. Las papas, crocantes.'],
      [5, 'El batido de frutilla es natural, se nota la fruta.'],
      [4, 'Muy rica la clásica; el pan podría estar más tostado.'],
      [5, 'Llegó rápido a Calacoto y bien caliente.'],
      [4, 'Buen precio para la calidad.'],
    ],
  },
};

/** Solicitudes de ejemplo que repetían restaurantes que ya funcionan. */
const SOLICITUDES_NUEVAS = {
  'Salteñería Doña Mari': 'Salteñas La Tradicional',
  'Café Altura': 'Café del Prado',
  'Cevichería Mar Azul': 'Cevichería El Muelle',
  'Taquería La Esquina': 'Taquería Los Compadres',
};

const sinTildes = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
const correoDe = (nombre, dominio) => {
  const [n, a] = sinTildes(nombre).split(' ');
  return `${n}.${a ?? 'equipo'}@${dominio}`;
};
const nombreCorto = (nombre) => {
  const p = nombre.split(' ');
  return `${p[0]} ${p[1]?.[0] ?? ''}.`;
};

async function pulirNegocio(doc) {
  const datos = PULIR[doc.data().nombre];
  if (!datos || !doc.data().demoDatos) return 0;
  const id = doc.id;
  const w = new Escritor();
  const dominio = datos.correo.split('@')[1];

  // Restaurante y sucursal
  await w.update(doc.ref, { descripcion: datos.descripcion, direccion: datos.direccion, correoContacto: datos.correo });
  for (const s of (await db.collection('sucursales').where('idNegocio', '==', id).get()).docs) {
    if (s.data().demoDatos && s.data().nombre === 'Sucursal Central') {
      await w.update(s.ref, { nombre: `Sucursal ${datos.sucursal}`, direccion: datos.direccion });
    }
  }

  // Personal: solo el registro (sin cuenta de acceso en Authentication).
  const personal = (await db.collection('usuarios').where('idNegocio', '==', id).get()).docs;
  const sucursal = (await db.collection('sucursales').where('idNegocio', '==', id).limit(1).get()).docs[0];
  for (const [rol, nombre] of datos.personal) {
    if (personal.some((u) => u.data().rol === rol)) continue;
    await w.set(db.collection('usuarios').doc(`demo_${id.slice(0, 8)}_${rol.toLowerCase()}`), {
      nombre,
      email: correoDe(nombre, dominio),
      telefono: '',
      rol,
      fotoPerfil: '',
      idSucursal: rol === 'Administrador' ? null : sucursal?.id ?? null,
      idNegocio: id,
      estado: true,
      fechaRegistro: ts(masMinutos(new Date(), -60 * 24 * 70)),
      notificacionesActivas: true,
      ...MARCA,
    });
  }

  // Repartidor sin "(ejemplo)" (y su nombre en los pedidos que entregó).
  const pedidos = (await db.collection('pedidos').where('idNegocio', '==', id).where('demoDatos', '==', true).get()).docs;
  for (const u of personal) {
    if (u.data().rol !== 'Repartidor' || !String(u.data().nombre).includes('(ejemplo)')) continue;
    await w.update(u.ref, { nombre: datos.repartidor, email: correoDe(datos.repartidor, dominio) });
    for (const p of pedidos) {
      if (p.data().idRepartidor === u.id) await w.update(p.ref, { nombreRepartidor: datos.repartidor });
    }
  }

  // Clientes con nombres propios de cada restaurante (antes eran los mismos en todos).
  const negocioRef = db.collection('negocios').doc(id);
  const nuevos = {};
  for (const c of (await negocioRef.collection('clientes').where('demoDatos', '==', true).get()).docs) {
    const i = Number(c.id.split('_cli')[1]);
    const nombre = datos.clientes[i];
    if (!nombre || c.data().nombre === nombre) continue;
    nuevos[c.id] = nombre;
    await w.update(c.ref, { nombre });
    const u = db.collection('usuarios').doc(c.id);
    if ((await u.get()).exists) await w.update(u, { nombre });
  }
  for (const p of pedidos) {
    const nombre = nuevos[p.data().idCliente];
    if (nombre) await w.update(p.ref, { nombreCliente: nombre });
  }

  // Reseñas que hablan de su menú (5 por restaurante).
  const resenas = (await negocioRef.collection('resenas').where('demoDatos', '==', true).get()).docs;
  const clientes = (await negocioRef.collection('clientes').where('demoDatos', '==', true).get()).docs.filter((c) => esDeEjemplo(c.id));
  for (const [i, [calificacion, comentario]] of datos.resenas.entries()) {
    const rid = `demo_resena_${id.slice(0, 6)}_${i}`;
    const c = clientes[i % Math.max(clientes.length, 1)];
    const nombre = c ? nuevos[c.id] ?? c.data().nombre : 'Cliente';
    const previa = resenas.find((r) => r.id === rid);
    const campos = { calificacion, comentario, nombreCliente: nombreCorto(nombre) };
    if (previa) {
      await w.update(previa.ref, campos);
    } else {
      await w.set(negocioRef.collection('resenas').doc(rid), {
        idNegocio: id,
        idPedido: rid,
        idCliente: c?.id ?? '',
        ...campos,
        fecha: ts(masMinutos(new Date(), -60 * 24 * (3 + i * 5))),
        estado: 'Visible',
        ...MARCA,
      });
    }
  }
  await w.cerrar();
  console.log(`${doc.data().nombre}: listo (${w.total} escrituras)`);
  return w.total;
}

async function pulir() {
  let total = 0;
  for (const n of (await db.collection('negocios').where('demoDatos', '==', true).get()).docs) total += await pulirNegocio(n);
  // Solicitudes pendientes de ejemplo que repetían un restaurante activo.
  for (const s of (await db.collection('solicitudesNegocio').where('demo', '==', true).get()).docs) {
    const nuevo = SOLICITUDES_NUEVAS[s.data().nombreNegocio];
    if (s.data().estado !== 'Pendiente') continue;
    // Que no parezcan olvidadas desde octubre: llegaron en los últimos días.
    const fecha = ts(masMinutos(new Date(), -60 * (6 + 20 * (total % 5))));
    if (nuevo) {
      await s.ref.update({ nombreNegocio: nuevo, fecha });
      total++;
      console.log(`Solicitud: "${s.data().nombreNegocio}" ahora es "${nuevo}"`);
    } else {
      await s.ref.update({ fecha });
      total++;
    }
  }
  console.log(`Pulido terminado (${total} escrituras).`);
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
} else if (args.includes('--mover-fechas') || args.includes('--ampliar')) {
  const objetivo = diaObjetivo();
  const ids = args.includes('--todos') ? await negociosConDemo() : [opcion('--negocio') ?? 'principal'];
  console.log(`Día de la demostración: ${objetivo.toLocaleDateString('es-BO')} (tope: ${LIMITE_ESCRITURAS} escrituras)`);
  for (const id of ids) {
    if (args.includes('--mover-fechas')) await moverFechas(id, objetivo);
    else await ampliarNegocio(id, objetivo);
  }
  console.log(`Total de esta corrida: ${escriturasHechas} escrituras.`);
  if (args.includes('--mover-fechas')) {
    console.log('El día de la demostración corre --refrescar para poner los pedidos de hoy a la hora actual.');
  }
} else if (args.includes('--pulir')) {
  await pulir();
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
  console.error('Falta una opción: --listar, --negocio ID, --todos, --mover-fechas, --ampliar, --pulir, --refrescar, --cliente CORREO o --borrar');
  process.exit(1);
}
process.exit(0);
