// Fotos para TODOS los restaurantes: productos, categorías, extras,
// variantes, sucursales, banner y logo. Solo llena lo que está VACÍO (no
// toca las fotos que un restaurante ya subió) y escribe como mucho UNA vez
// por documento.
//
// Las fotos son enlaces públicos y gratuitos de Unsplash (no se sube nada
// a Storage). Se elige la foto según el nombre del plato o de la categoría
// (pizza, hamburguesa, sushi, bebidas...) y, si no se reconoce, una foto de
// comida variada que siempre sale igual para ese documento.
//
// Uso (desde la carpeta scripts/demo):
//   node imagenes_demo.js LLAVE --probar     solo muestra cuántas escrituras haría
//   node imagenes_demo.js LLAVE              pone las fotos que faltan
//   node imagenes_demo.js LLAVE --quitar     quita SOLO las fotos que puso este script
//   --max N   no escribe nada si hacen falta más de N escrituras (por defecto 3000)
//
// LLAVE = ruta a serviceAccountKey.json (NUNCA se sube a GitHub).

import { readFileSync } from 'node:fs';

import admin from 'firebase-admin';

const args = process.argv.slice(2);
const rutaLlave = args[0];
if (!rutaLlave || rutaLlave.startsWith('--')) {
  console.error('Uso: node imagenes_demo.js LLAVE [--probar | --quitar] [--max N]');
  process.exit(1);
}
const iMax = args.indexOf('--max');
const MAXIMO = iMax >= 0 ? Number(args[iMax + 1]) : 3000;
const PROBAR = args.includes('--probar');
const QUITAR = args.includes('--quitar');

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(readFileSync(rutaLlave, 'utf8'))) });
const db = admin.firestore();

// --------------------------------------------------------------- las fotos

/** Enlace de Unsplash recortado al tamaño que usa la app. */
const foto = (id, ancho, alto) =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${ancho}&h=${alto}&q=70`;

// Cada grupo tiene una o más fotos revisadas a mano (el enlace funciona y
// muestra lo que dice el nombre).
const F = {
  pizza: ['1513104890138-7c749659a591', '1565299624946-b28f40a0ae38'],
  pizzaMargarita: ['1574071318508-1cdbab80d002'],
  pizzaPepperoni: ['1628840042765-356cda07504e'],
  hamburguesa: ['1568901346375-23c9450c58cd', '1571091718767-18b5b1457add', '1553979459-d2229ba7433b', '1586190848861-99aa4a171e90'],
  hamburguesaDoble: ['1550547660-d9450f859349'],
  hamburguesaPollo: ['1606755962773-d324e0a13086'],
  papas: ['1573080496219-bb080dd4f877', '1630384060421-cb20d0e0649d', '1606755456206-b25206cde27e'],
  polloFrito: ['1626645738196-c2a7c87a8f58', '1575932444877-5106bee2a599'],
  polloBrasa: ['1598103442097-8b74394b95c6'],
  pollo: ['1532550907401-a500c9a57435', '1619221882220-947b3d3c8861'],
  alitas: ['1608039755401-742074f0548d', '1567620832903-9fc6debc209f'],
  apanado: ['1562967914-608f82629710'],
  carne: ['1600891964092-4316c288032e', '1546833999-b9f581a1996d'],
  parrilla: ['1555939594-58d7cb561ad1', '1544025162-d76694265947'],
  chorizo: ['1595777216528-071e0127ccbf'],
  anticucho: ['1532634922-8fe0b757fb13'],
  albondigas: ['1529042410759-befb1204b468'],
  ensalada: ['1512621776951-a57141f2eefd', '1540420773420-3366772f4999', '1550304943-4f24f54ddde9', '1559847844-5315695dadae'],
  arroz: ['1516684732162-798a0062be99', '1603133872878-684f208fb84b'],
  lasana: ['1574894709920-11b28e7367e3', '1619895092538-128341789043'],
  pasta: ['1621996346565-e3dbc646d9a9', '1595295333158-4742f28fbd85'],
  sushi: ['1579871494447-9811cf80d66c', '1617196034796-73dfa7b1fd56', '1553621042-f6e147245754', '1617093727343-374698b1b08d'],
  ramen: ['1569718212165-3a8278d5f624', '1557872943-16a5ac26437e', '1585032226651-759b368d7246'],
  gyoza: ['1496116218417-1a781b1c416c', '1563245372-f21724e3856d'],
  coreana: ['1553163147-622ab57be1c7', '1635363638580-c2809d049eee'],
  fideosWok: ['1615361200141-f45040f367be'],
  te: ['1556679343-c7306c1976bc', '1544787219-7f47ccb76574'],
  teFrio: ['1627435601361-ec25f5b1d0e5'],
  tacos: ['1565299585323-38d6b0865b47', '1551504734-5ee1c4a1479b', '1615870216519-2f9fa575fa5c', '1599974579688-8dbdd335c77f'],
  quesadilla: ['1618040996337-56904b7850b9', '1662116765994-1e4200c43589'],
  sandwich: ['1528735602780-2552fd46c7af', '1553909489-cd47e0907980', '1509722747041-616f39b57569', '1628191010210-a59de33e5941'],
  ceviche: ['1535399831218-d5bd36d1a6b3'],
  mariscos: ['1534080564583-6be75777b70a', '1599021456807-25db0f974333'],
  frituraMar: ['1599487488170-d11ec9c172f0'],
  guiso: ['1600565193348-f74bd3c7ccdf'],
  horneado: ['1601000938365-f182c5ec2f77'],
  cafe: ['1509042239860-f550ce710b93', '1572442388796-11668a67e53d'],
  torta: ['1578985545062-69928b1d9587', '1606313564200-e75d5e30476c', '1570145820259-b5b80c5c8bd6'],
  postre: ['1488477181946-6428a0291777', '1563805042-7684c019e1cb', '1551024506-0bccd828d307'],
  helado: ['1497034825429-c343d7c6a68f'],
  malteada: ['1572490122747-3968b75cc699', '1541658016709-82535e94bc69'],
  batidoFrutilla: ['1579954115545-a95591f28bfc'],
  gaseosa: ['1622483767028-3f66f32aef97', '1554866585-cd94860890b7'],
  limonada: ['1621263764928-df1444c5e859', '1523371054106-bbf80586c38c', '1556881286-fc6915169721'],
  jugo: ['1600271886742-f049cd451bba', '1622597467836-f3285f2131b8', '1497534446932-c925b458314e'],
  morado: ['1600718374662-0483d2b9da44'],
  coctel: ['1544145945-f90425340c7e'],
  vino: ['1510812431401-41d2bd2722f3'],
  cerveza: ['1559339352-11d035aa65de'],
  huevo: ['1525351484163-7529414344d8'],
  desayuno: ['1567620905732-2d1ec7ab7445'],
  comida: [
    '1504674900247-0877df9cc836', '1546069901-ba9599a7e63c', '1565958011703-44f9829ba187',
    '1540189549336-e6e99c3679fe', '1476224203421-9ac39bcb3327', '1555396273-367ea4eb4db5',
  ],
  local: [
    '1517248135467-4c7edcad34c4', '1552566626-52f8b828add9', '1414235077428-338989a2e8c0',
    '1466978913421-dad2ebd01d17', '1537047902294-62a40c20a6ae', '1590846406792-0adc7f938f1d',
  ],
  localCafe: ['1554118811-1e0d58224f24', '1501339847302-ac426a4a7cbb'],
  // Ingredientes sueltos, para los extras.
  queso: ['1486297678162-eb2a19b0a32d'],
  tocino: ['1606851094655-b2593a9af63f'],
  pina: ['1587883012610-e3df17d41270'],
  frutilla: ['1518635017498-87f514b751ba'],
  palta: ['1523049673857-eb18f1d7b578'],
  huevoDuro: ['1482049016688-2d3e1b311543'],
  salsa: ['1472476443507-c7a5948772fc'],
  aji: ['1583119022894-919a68a3d0e3'],
  cebolla: ['1618512496248-a07fe83aa8cb'],
  jamon: ['1524438418049-ab2acb7aa48f'],
  champinon: ['1504545102780-26774c1bb073'],
  cereza: ['1559181567-c3190ca9959b'],
  leche: ['1550583724-b2692b85b150'],
  pepino: ['1589621316382-008455b857cd'],
  verduras: ['1573246123716-6b1782bfc499'],
};

// Reglas en orden: la primera que coincide con el nombre gana. Se compara
// sin tildes y en minúsculas.
const REGLAS = [
  [/combo|familiar/, 'TEMA'],
  [/\bapi\b|chicha morada|morado/, 'morado'],
  [/sajta|fricase|curry|estofado/, 'guiso'],
  [/saltena|empanada|tucuman/, 'horneado'],
  [/pepperoni/, 'pizzaPepperoni'],
  [/pizza.*(margarit|margherit)|margarit/, 'pizzaMargarita'],
  [/pizza|calzone/, 'pizza'],
  [/lasan|lasagn/, 'lasana'],
  [/(hamburg|burger).*(pollo|crispy|chicken)/, 'hamburguesaPollo'],
  [/(hamburg|burger).*(doble|triple|double)/, 'hamburguesaDoble'],
  [/hamburg|burger/, 'hamburguesa'],
  [/malteada|milkshake|shake|frappe/, 'malteada'],
  [/batido|smoothie|licuado/, 'batidoFrutilla'],
  [/papa.*frita|papas|fries/, 'papas'],
  [/alita|wings/, 'alitas'],
  [/broaster|pollo frito|crispy|nugget|pollo coreano/, 'polloFrito'],
  [/brasa|pollo entero|rostizado|1\/2 pollo|medio pollo/, 'polloBrasa'],
  [/silpancho|milanesa|apanad|escalope/, 'apanado'],
  [/anticucho|brocheta|kebab|pincho/, 'anticucho'],
  [/parrill|asado|costilla|ribs|churrasco/, 'parrilla'],
  [/chorizo|salchich|hot ?dog|choripan/, 'chorizo'],
  [/albondig/, 'albondigas'],
  [/pique|lomo|bife|steak|filete|carne|\bres\b|chuleta|picante de/, 'carne'],
  [/sushi|roll|maki|nigiri|sashimi|kimbap|gimbap/, 'sushi'],
  [/ramen|udon|sopa de fideo/, 'ramen'],
  [/gyoza|dumpling|wantan|wonton|mandu/, 'gyoza'],
  [/tteok|bibimbap|kimchi|bulgogi|coreano/, 'coreana'],
  [/chaufa|chow|wok|tallarin salt|yakisoba|fideos? (frito|salteado)/, 'fideosWok'],
  [/taco|burrito|nacho/, 'tacos'],
  [/quesadilla|wrap|fajita/, 'quesadilla'],
  [/ceviche|cebiche|tiradito/, 'ceviche'],
  [/jalea|chicharron de (pescado|mariscos)|calamar|rabas/, 'frituraMar'],
  [/marisco|camaron|pescado|trucha|paella|langostino/, 'mariscos'],
  [/saltena|empanada|tucuman|pastel|cunap|pan de|croissant|medialuna|humita/, 'horneado'],
  [/sandw|torta ahogada|lomito|sanduch|club|baguette|panini|tostado/, 'sandwich'],
  [/espagueti|spaghetti|pasta|fideo|tallarin|ravioli|penne|macarr|carbonara/, 'pasta'],
  [/majadito|arroz|risotto|chorrillana/, 'arroz'],
  [/ensalada|salad|verdura|bowl/, 'ensalada'],
  [/huevo|omelet|tortilla de/, 'huevo'],
  [/desayuno|panqueque|waffle|hotcake/, 'desayuno'],
  [/pollo|chicken/, 'pollo'],
  [/guiso|chairo|sopa|caldo|locro/, 'guiso'],
  [/helado|ice cream|sundae|paleta/, 'helado'],
  [/torta|pastel de choc|brownie|cheesecake|keke|tarta|cake/, 'torta'],
  [/flan|postre|dulce|mousse|gelatina|budin|tiramisu|crepa|waffle/, 'postre'],
  [/capuch|cappucc|cafe|espresso|latte|mocaccino|americano/, 'cafe'],
  [/te verde|^te\b|\bte de|infusion|mate de|matcha/, 'te'],
  [/te helado|ice tea|iced tea/, 'teFrio'],
  [/limonada|lemonade|mojito/, 'limonada'],
  [/mocochinchi|jugo|refresco|zumo|horchata|chicha|tamarindo|agua de/, 'jugo'],
  [/gaseosa|coca|fanta|sprite|soda|pepsi/, 'gaseosa'],
  [/vino|sangria/, 'vino'],
  [/cerveza|beer|chela/, 'cerveza'],
  [/coctel|cocktail|trago|pisco|singani|chuflay/, 'coctel'],
  // Por el nombre de la categoría (cuando el plato no se reconoce).
  [/bebida|drinks?/, 'jugo'],
  [/postre|dulces/, 'postre'],
  [/entrada|piqueo|snack/, 'papas'],
  [/acompa/, 'papas'],
  [/cafeter/, 'cafe'],
];

// Para los extras se miran primero los ingredientes sueltos ("Queso extra",
// "Tocino", "Piña"...) y después las reglas de platos.
const REGLAS_EXTRAS = [
  [/tocino|bacon|panceta/, 'tocino'],
  [/jamon/, 'jamon'],
  [/queso|cheddar|mozzarella|parmesano/, 'queso'],
  [/pina|anana/, 'pina'],
  [/frutilla|fresa/, 'frutilla'],
  [/palta|aguacate|guacamole/, 'palta'],
  [/huevo/, 'huevoDuro'],
  [/salsa|mayonesa|ketchup|mostaza|aderezo|llajua|chimichurri/, 'salsa'],
  [/aji\b|picante|jalapen|locoto/, 'aji'],
  [/cebolla/, 'cebolla'],
  [/champi|hongo/, 'champinon'],
  [/cereza/, 'cereza'],
  [/leche|crema|chantilly/, 'leche'],
  [/pepin/, 'pepino'],
  [/lechuga|tomate|verdura|vegetal/, 'verduras'],
];

const sinTildes = (s) =>
  String(s ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase();

/** Número estable a partir de un texto (para variar fotos sin azar). */
function hash(texto) {
  let h = 0;
  for (const c of String(texto)) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  return h;
}

/** Grupo de fotos que corresponde a uno o más textos (el primero manda). */
function grupoPara(...textos) {
  for (const t of textos) {
    const limpio = sinTildes(t);
    if (!limpio) continue;
    for (const [regla, grupo] of REGLAS) if (regla.test(limpio)) return grupo;
  }
  return null;
}

const elegirDe = (grupo, clave) => {
  const lista = F[grupo] ?? F.comida;
  return lista[hash(clave) % lista.length];
};

// Tema del restaurante (para banner, logo y fotos de respaldo).
function temaNegocio(nombre) {
  const n = sinTildes(nombre);
  if (/pizz/.test(n)) return 'pizza';
  if (/sushi|japo|ramen|kento/.test(n)) return 'sushi';
  if (/burger|hamburg/.test(n)) return 'hamburguesa';
  if (/poll|broaster|brasa|chicken/.test(n)) return 'polloFrito';
  if (/ceviche|cevich|mar |marisc/.test(n)) return 'ceviche';
  if (/taco|taquer|mexic/.test(n)) return 'tacos';
  if (/saltena|empanad|panader/.test(n)) return 'horneado';
  if (/cafe|coffee|altura/.test(n)) return 'cafe';
  if (/parrill|gaucho|asado|grill/.test(n)) return 'parrilla';
  if (/k ?pop|corea|febu|garu/.test(n)) return 'coreana';
  return null;
}

/** Si el plato no se reconoce (o es un combo), la foto va con el restaurante. */
const conTema = (grupo, negocio) =>
  grupo && grupo !== 'TEMA' ? grupo : temaNegocio(negocio) ?? 'comida';

// ------------------------------------------------------------------- correr

const vacia = (v) => typeof v !== 'string' || v.trim() === '';

/** Grupo para un extra: primero como ingrediente, luego como plato. */
function grupoExtra(...textos) {
  for (const t of textos) {
    const limpio = sinTildes(t);
    if (!limpio) continue;
    for (const [regla, grupo] of REGLAS_EXTRAS) if (regla.test(limpio)) return grupo;
  }
  return grupoPara(...textos);
}

async function main() {
  const [negocios, categorias, productos, sucursales, complementos, variantes] = await Promise.all(
    ['negocios', 'categorias', 'productos', 'sucursales', 'complementos', 'variantes'].map((c) =>
      db.collection(c).get(),
    ),
  );
  const nombreNegocio = new Map(negocios.docs.map((d) => [d.id, d.data().nombre ?? '']));
  const nombreCategoria = new Map(categorias.docs.map((d) => [d.id, d.data().nombre ?? '']));

  /** Cambios a escribir: [ref, datos, texto para el resumen]. */
  const cambios = [];

  if (QUITAR) {
    for (const snap of [categorias, productos, sucursales, complementos, variantes]) {
      for (const d of snap.docs) {
        if (d.data().fotoDemo === true) cambios.push([d.ref, { imagenUrl: '', fotoDemo: admin.firestore.FieldValue.delete() }]);
      }
    }
    for (const d of negocios.docs) {
      const x = d.data();
      if (!x.fotoDemo) continue;
      const datos = { fotoDemo: admin.firestore.FieldValue.delete() };
      if (x.fotoDemo.banner) datos.bannerUrl = '';
      if (x.fotoDemo.logo) datos.logoUrl = '';
      cambios.push([d.ref, datos]);
    }
  } else {
    // Primera foto de cada categoría (por si la categoría tiene un nombre raro).
    const fotoDeCategoria = new Map();
    // Foto de cada producto (la que ya tenía o la nueva), para sus variantes.
    const fotoDeProducto = new Map(
      productos.docs.filter((d) => !vacia(d.data().imagenUrl)).map((d) => [d.id, d.data().imagenUrl]),
    );

    for (const d of productos.docs) {
      const p = d.data();
      if (!vacia(p.imagenUrl)) continue;
      const grupo = conTema(
        grupoPara(p.nombre, p.descripcion, nombreCategoria.get(p.idCategoria)),
        nombreNegocio.get(p.idNegocio),
      );
      const url = foto(elegirDe(grupo, d.id), 600, 450);
      if (p.idCategoria && !fotoDeCategoria.has(p.idCategoria)) fotoDeCategoria.set(p.idCategoria, url);
      fotoDeProducto.set(d.id, url);
      cambios.push([d.ref, { imagenUrl: url, fotoDemo: true }]);
    }
    for (const d of productos.docs) {
      const p = d.data();
      if (!vacia(p.imagenUrl) && p.idCategoria && !fotoDeCategoria.has(p.idCategoria)) {
        fotoDeCategoria.set(p.idCategoria, p.imagenUrl);
      }
    }

    for (const d of categorias.docs) {
      const c = d.data();
      if (!vacia(c.imagenUrl)) continue;
      // La foto de su primer plato; si no tiene platos, según su nombre.
      const grupo = conTema(grupoPara(c.nombre, c.descripcion), nombreNegocio.get(c.idNegocio));
      const url = fotoDeCategoria.get(d.id) ?? foto(elegirDe(grupo, d.id), 600, 450);
      cambios.push([d.ref, { imagenUrl: url, fotoDemo: true }]);
    }

    // Extras: según el ingrediente o el plato; si no se reconoce, una foto
    // de comida del estilo del restaurante.
    for (const d of complementos.docs) {
      const c = d.data();
      if (!vacia(c.imagenUrl)) continue;
      const grupo = conTema(grupoExtra(c.nombre, c.descripcion), nombreNegocio.get(c.idNegocio));
      cambios.push([d.ref, { imagenUrl: foto(elegirDe(grupo, d.id), 300, 300), fotoDemo: true }]);
    }

    // Variantes (tamaños, presentaciones): la foto de su producto.
    for (const d of variantes.docs) {
      const v = d.data();
      if (!vacia(v.imagenUrl)) continue;
      const url =
        fotoDeProducto.get(v.idProducto) ??
        foto(elegirDe(conTema(grupoPara(v.nombre), nombreNegocio.get(v.idNegocio)), d.id), 600, 450);
      cambios.push([d.ref, { imagenUrl: url, fotoDemo: true }]);
    }

    for (const d of sucursales.docs) {
      const s = d.data();
      if (!vacia(s.imagenUrl)) continue;
      const esCafe = temaNegocio(nombreNegocio.get(s.idNegocio)) === 'cafe';
      const url = foto(elegirDe(esCafe ? 'localCafe' : 'local', d.id), 800, 500);
      cambios.push([d.ref, { imagenUrl: url, fotoDemo: true }]);
    }

    for (const d of negocios.docs) {
      const n = d.data();
      const tema = temaNegocio(n.nombre) ?? 'comida';
      const lista = F[tema];
      const datos = {};
      const marca = {};
      if (vacia(n.bannerUrl)) {
        datos.bannerUrl = foto(lista[hash(d.id) % lista.length], 1200, 500);
        marca.banner = true;
      }
      if (vacia(n.logoUrl)) {
        // Otra foto del mismo tema (si hay) para que el logo no repita el banner.
        datos.logoUrl = foto(lista[(hash(d.id) + 1) % lista.length], 256, 256);
        marca.logo = true;
      }
      if (Object.keys(datos).length === 0) continue;
      cambios.push([d.ref, { ...datos, fotoDemo: marca }]);
    }
  }

  const lecturas =
    negocios.size + categorias.size + productos.size + sucursales.size + complementos.size + variantes.size;
  console.log(`Leídos: ${lecturas} documentos.`);
  console.log(`Escrituras necesarias: ${cambios.length} (una por documento).`);
  if (PROBAR) {
    for (const [ref, datos] of cambios.slice(0, 15)) {
      console.log(`  ${ref.path}: ${datos.imagenUrl ?? datos.bannerUrl ?? datos.logoUrl ?? '(quitar)'}`);
    }
    if (cambios.length > 15) console.log(`  ... y ${cambios.length - 15} más`);
    console.log('\nPrueba: no se escribió nada. Quita --probar para aplicarlo.');
    return;
  }
  if (cambios.length > MAXIMO) {
    console.error(`Son más de ${MAXIMO} escrituras: no se escribió nada. Usa --max N si estás segura.`);
    process.exit(1);
  }
  for (let i = 0; i < cambios.length; i += 400) {
    const lote = db.batch();
    for (const [ref, datos] of cambios.slice(i, i + 400)) lote.update(ref, datos);
    await lote.commit();
  }
  console.log(`\nListo: ${cambios.length} escrituras. Recarga la app.`);
}

await main();
process.exit(0);
