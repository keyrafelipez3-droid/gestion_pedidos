// Pruebas de las reglas de seguridad de Firestore (firestore.rules).
//
// Corren en el EMULADOR de Firebase con un proyecto de prueba
// ("demo-caro"): nunca tocan la base de datos real.
//
//   cd test_reglas
//   npm install
//   npm test        (necesita Java 21 instalado)
//
// Cada prueba describe una regla de negocio o de seguridad con palabras
// que se pueden leer en la presentación: "un cliente no puede hacerse
// administrador", "la cocina de otro negocio no ve nuestros pedidos", etc.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';

let env;

const USUARIOS = {
  super1: { rol: 'SuperAdmin', estado: true, email: 'super@caro.bo' },
  admin1: { rol: 'Administrador', estado: true, idNegocio: 'n1', email: 'admin@n1.bo' },
  cajero1: { rol: 'Cajero', estado: true, idNegocio: 'n1', idSucursal: 's1', email: 'caja@n1.bo' },
  cocina1: { rol: 'Cocina', estado: true, idNegocio: 'n1', email: 'cocina@n1.bo' },
  repa1: { rol: 'Repartidor', estado: true, idNegocio: 'n1', email: 'repa@n1.bo' },
  cocinaInactiva: { rol: 'Cocina', estado: false, idNegocio: 'n1', email: 'baja@n1.bo' },
  cocinaB: { rol: 'Cocina', estado: true, idNegocio: 'n2', email: 'cocina@n2.bo' },
  cli1: { rol: 'Cliente', estado: true, email: 'ana@gmail.com', nombre: 'Ana' },
  cli2: { rol: 'Cliente', estado: true, email: 'luis@gmail.com', nombre: 'Luis' },
};

/** Base de datos de cada prueba (se escribe sin reglas). */
async function sembrar() {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    for (const [uid, datos] of Object.entries(USUARIOS)) {
      await setDoc(doc(db, 'usuarios', uid), datos);
    }
    await setDoc(doc(db, 'negocios', 'n1'), { nombre: 'Pollos Caro', estado: true });
    await setDoc(doc(db, 'negocios', 'n2'), { nombre: 'Otra tienda', estado: true });
    // Codigos de acceso y los clientes que ya entraron con el de n1.
    await setDoc(doc(db, 'codigosNegocio', 'POLLO1'), { idNegocio: 'n1', nombre: 'Pollos Caro' });
    await setDoc(doc(db, 'codigosNegocio', 'OTRA22'), { idNegocio: 'n2', nombre: 'Otra tienda' });
    await setDoc(doc(db, 'usuarios/cli1/misNegocios', 'n1'), { codigo: 'POLLO1' });
    await setDoc(doc(db, 'usuarios/cli2/misNegocios', 'n1'), { codigo: 'POLLO1' });
    await setDoc(doc(db, 'sucursales', 's1'), { idNegocio: 'n1', nombre: 'Centro' });
    await setDoc(doc(db, 'sucursales', 's2'), { idNegocio: 'n2', nombre: 'Norte' });
    await setDoc(doc(db, 'sucursales', 's3'), {
      idNegocio: 'n1', nombre: 'Sur', zonasDelivery: { Centro: 5, Norte: 8 }, pedidoMinimoDelivery: 30,
    });
    await setDoc(doc(db, 'productos', 'prod1'), {
      idNegocio: 'n1', nombre: 'Pollo', precio: 35, disponible: true, stock: 10,
    });
    await setDoc(doc(db, 'negocios/n1/cupones', 'CARO10'), {
      tipo: 'porcentaje', valor: 10, minimo: 0, activo: true, vence: null,
    });
    await setDoc(doc(db, 'negocios/n1/cupones', 'VIEJO'), {
      tipo: 'monto', valor: 5, minimo: 0, activo: true,
      vence: Timestamp.fromDate(new Date('2020-01-01')),
    });
    await setDoc(doc(db, 'pedidos', 'ped1'), {
      idCliente: 'cli1', idNegocio: 'n1', idSucursal: 's1', modalidad: 'Recoger',
      metodoPago: 'Efectivo', estado: 'Pendiente', total: 35, cobrado: false,
    });
    await setDoc(doc(db, 'pedidos', 'pedDelivery'), {
      idCliente: 'cli1', idNegocio: 'n1', idSucursal: 's1', modalidad: 'Delivery',
      metodoPago: 'Efectivo', estado: 'Listo', total: 50, cobrado: false,
    });
  });
}

/** Firestore como lo ve una persona con sesión (correo verificado). */
function como(uid, { correoVerificado = true } = {}) {
  return env.authenticatedContext(uid, { email_verified: correoVerificado }).firestore();
}

/** Pedido válido de un cliente; se puede modificar cualquier campo. */
function pedidoCliente(uid, cambios = {}) {
  return {
    idCliente: uid,
    idNegocio: 'n1',
    idSucursal: 's1',
    modalidad: 'Recoger',
    metodoPago: 'Efectivo',
    estado: 'Pendiente',
    total: 35,
    notas: '',
    fechaCreacion: serverTimestamp(),
    origen: 'cliente',
    cuentaAbierta: false,
    cobrado: false,
    alergias: [],
    idiomaCliente: 'es',
    descuento: 0,
    propina: 0,
    ...cambios,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-caro',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await sembrar();
});

after(async () => {
  await env?.cleanup();
});

// ---------------------------------------------------------------------------
describe('Cuentas y roles', () => {
  test('alguien sin sesión no lee nada', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'productos', 'prod1')));
    await assertFails(getDoc(doc(db, 'pedidos', 'ped1')));
  });

  test('un cliente nuevo se registra solo como Cliente', async () => {
    const db = como('nuevo');
    await assertSucceeds(setDoc(doc(db, 'usuarios', 'nuevo'), { rol: 'Cliente', estado: true, email: 'n@x.com' }));
  });

  test('nadie se registra como Administrador ni se mete a un negocio', async () => {
    await assertFails(setDoc(doc(como('pirata'), 'usuarios', 'pirata'), { rol: 'Administrador', estado: true }));
    await assertFails(
      setDoc(doc(como('pirata2'), 'usuarios', 'pirata2'), { rol: 'Cliente', estado: true, idNegocio: 'n1' }),
    );
  });

  test('un cliente cambia su nombre pero no su rol', async () => {
    const db = como('cli1');
    await assertSucceeds(updateDoc(doc(db, 'usuarios', 'cli1'), { nombre: 'Ana María' }));
    await assertFails(updateDoc(doc(db, 'usuarios', 'cli1'), { rol: 'SuperAdmin' }));
    await assertFails(updateDoc(doc(db, 'usuarios', 'cli1'), { estado: false, idNegocio: 'n1' }));
  });

  test('un cliente no lee los datos de otro cliente', async () => {
    await assertFails(getDoc(doc(como('cli1'), 'usuarios', 'cli2')));
  });

  test('alergias: solo códigos de la lista oficial', async () => {
    const db = como('cli1');
    await assertSucceeds(updateDoc(doc(db, 'usuarios', 'cli1'), { alergias: ['mani', 'cebolla'] }));
    await assertFails(updateDoc(doc(db, 'usuarios', 'cli1'), { alergias: ['<script>'] }));
  });

  test('el Administrador maneja a su personal, no a otros administradores ni a otro negocio', async () => {
    const db = como('admin1');
    await assertSucceeds(updateDoc(doc(db, 'usuarios', 'cocina1'), { rol: 'Cajero' }));
    await assertFails(updateDoc(doc(db, 'usuarios', 'cocina1'), { rol: 'Administrador' }));
    await assertFails(updateDoc(doc(db, 'usuarios', 'cocinaB'), { estado: false }));
    await assertFails(updateDoc(doc(db, 'usuarios', 'admin1'), { idNegocio: 'n2' }));
  });

  test('un empleado dado de baja pierde el acceso', async () => {
    await assertFails(getDoc(doc(como('cocinaInactiva'), 'pedidos', 'ped1')));
  });
});

// ---------------------------------------------------------------------------
describe('Acuerdo de confidencialidad del personal', () => {
  const firma = (cambios = {}) => ({
    acuerdoPersonal: {
      version: '2026-10-23', fecha: serverTimestamp(), nombre: 'Rosa Quispe', ci: '1234567',
      idNegocio: 'n1', rol: 'Cocina', ...cambios,
    },
  });

  test('el empleado firma con su nombre y CI', async () => {
    await assertSucceeds(updateDoc(doc(como('cocina1'), 'usuarios', 'cocina1'), firma()));
  });

  test('no se puede poner otra fecha en la firma', async () => {
    const fechaFalsa = Timestamp.fromDate(new Date('2025-01-01'));
    await assertFails(updateDoc(doc(como('cocina1'), 'usuarios', 'cocina1'), firma({ fecha: fechaFalsa })));
  });

  test('el Administrador no puede firmar por el empleado', async () => {
    await assertFails(updateDoc(doc(como('admin1'), 'usuarios', 'cocina1'), firma()));
  });
});

// ---------------------------------------------------------------------------
describe('Pedidos del cliente', () => {
  const crear = (uid, datos, opciones) => setDoc(doc(como(uid, opciones), 'pedidos', 'nuevo'), datos);

  test('un pedido normal se crea', async () => {
    await assertSucceeds(crear('cli1', pedidoCliente('cli1')));
  });

  test('sin correo verificado no puede pedir', async () => {
    await assertFails(crear('cli1', pedidoCliente('cli1'), { correoVerificado: false }));
  });

  test('no puede pedir a nombre de otra persona', async () => {
    await assertFails(crear('cli1', pedidoCliente('cli2')));
  });

  test('no puede crear el pedido ya entregado, cobrado o gratis', async () => {
    await assertFails(crear('cli1', pedidoCliente('cli1', { estado: 'Entregado' })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { cobrado: true })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { total: 0 })));
  });

  test('no puede inventar la fecha ni agregar campos extra', async () => {
    const ayer = Timestamp.fromDate(new Date(Date.now() - 86400000));
    await assertFails(crear('cli1', pedidoCliente('cli1', { fechaCreacion: ayer })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { idRepartidor: 'yo' })));
  });

  test('la sucursal tiene que ser del negocio', async () => {
    await assertFails(crear('cli1', pedidoCliente('cli1', { idSucursal: 's2' })));
  });

  test('no acepta notas enormes', async () => {
    await assertSucceeds(crear('cli1', pedidoCliente('cli1', { notas: 'Sin cebolla, por favor' })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { notas: 'x'.repeat(600) })));
  });

  test('alergias con códigos válidos', async () => {
    await assertSucceeds(crear('cli1', pedidoCliente('cli1', { alergias: ['mani', 'tomate'] })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { alergias: ['veneno'] })));
  });

  test('cupón vigente: el descuento no puede pasar lo que da el cupón', async () => {
    // CARO10 = 10 %: sobre Bs 100 el máximo es Bs 10.
    await assertSucceeds(crear('cli1', pedidoCliente('cli1', { codigoCupon: 'CARO10', descuento: 10, total: 90 })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { codigoCupon: 'CARO10', descuento: 50, total: 50 })));
  });

  test('cupón vencido o inexistente: no hay descuento', async () => {
    await assertFails(crear('cli1', pedidoCliente('cli1', { codigoCupon: 'VIEJO', descuento: 5, total: 30 })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { codigoCupon: 'NOEXISTE', descuento: 5, total: 30 })));
  });

  test('propina solo en delivery y con tope', async () => {
    const delivery = { modalidad: 'Delivery', direccionEntrega: { texto: 'Calle 1' } };
    await assertSucceeds(crear('cli1', pedidoCliente('cli1', { ...delivery, propina: 5 })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { propina: 5 })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { ...delivery, propina: 9999 })));
  });

  test('pedido programado: futuro y máximo 3 días', async () => {
    const en2h = Timestamp.fromDate(new Date(Date.now() + 2 * 3600e3));
    const en10d = Timestamp.fromDate(new Date(Date.now() + 10 * 86400e3));
    await assertSucceeds(crear('cli1', pedidoCliente('cli1', { programadoPara: en2h })));
    await assertFails(crear('cli1', pedidoCliente('cli1', { programadoPara: en10d })));
  });

  test('un cliente bloqueado por el negocio no puede pedir', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'negocios/n1/clientes', 'cli1'), { nombre: 'Ana', bloqueado: true }),
    );
    await assertFails(crear('cli1', pedidoCliente('cli1')));
  });

  test('el cliente ve sus pedidos pero no los de otros', async () => {
    await assertSucceeds(getDoc(doc(como('cli1'), 'pedidos', 'ped1')));
    await assertFails(getDoc(doc(como('cli2'), 'pedidos', 'ped1')));
  });

  test('el cliente no modifica su pedido después de crearlo', async () => {
    await assertFails(updateDoc(doc(como('cli1'), 'pedidos', 'ped1'), { total: 1 }));
    await assertFails(updateDoc(doc(como('cli1'), 'pedidos', 'ped1'), { estado: 'Cancelado' }));
  });
});

// ---------------------------------------------------------------------------
describe('Pedidos en el local (cocina, caja, reparto)', () => {
  test('la cocina cambia el estado', async () => {
    await assertSucceeds(updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), { estado: 'En preparación' }));
  });

  test('la cocina no puede poner un estado inventado ni tocar el total', async () => {
    await assertFails(updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), { estado: 'Regalado' }));
    // Tampoco "colándolo" junto con el borrado de la ubicación del repartidor.
    await assertFails(
      updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), {
        estado: 'Regalado', ubicacionRepartidor: null, ubicacionActualizada: null,
      }),
    );
    await assertFails(updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), { total: 1 }));
  });

  test('la cocina de OTRO negocio no ve ni toca nuestros pedidos', async () => {
    const db = como('cocinaB');
    await assertFails(getDoc(doc(db, 'pedidos', 'ped1')));
    await assertFails(updateDoc(doc(db, 'pedidos', 'ped1'), { estado: 'Cancelado' }));
    await assertFails(getDocs(query(collection(db, 'pedidos'), where('idNegocio', '==', 'n1'))));
  });

  test('solo el cajero registra el cobro, y no se puede des-cobrar', async () => {
    await assertFails(updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), { cobrado: true }));
    await assertSucceeds(updateDoc(doc(como('cajero1'), 'pedidos', 'ped1'), { cobrado: true }));
    await assertFails(updateDoc(doc(como('cajero1'), 'pedidos', 'ped1'), { cobrado: false }));
  });

  test('el repartidor toma un delivery listo a su nombre', async () => {
    await assertSucceeds(
      updateDoc(doc(como('repa1'), 'pedidos', 'pedDelivery'), {
        estado: 'En camino', idRepartidor: 'repa1', nombreRepartidor: 'Juan', telefonoRepartidor: '+59171234567',
      }),
    );
  });

  test('el repartidor no puede asignarle el pedido a otro', async () => {
    await assertFails(
      updateDoc(doc(como('repa1'), 'pedidos', 'pedDelivery'), {
        estado: 'En camino', idRepartidor: 'otro', nombreRepartidor: 'X', telefonoRepartidor: '1',
      }),
    );
  });

  test('el repartidor no ve pedidos para recoger en el local', async () => {
    await assertFails(getDoc(doc(como('repa1'), 'pedidos', 'ped1')));
  });

  test('nadie borra pedidos (salvo el SuperAdmin)', async () => {
    await assertFails(deleteDoc(doc(como('admin1'), 'pedidos', 'ped1')));
    await assertSucceeds(deleteDoc(doc(como('super1'), 'pedidos', 'ped1')));
  });
});

// ---------------------------------------------------------------------------
describe('Catálogo y stock', () => {
  test('la cocina descuenta stock, pero no lo aumenta ni cambia el precio', async () => {
    const db = como('cocina1');
    await assertSucceeds(updateDoc(doc(db, 'productos', 'prod1'), { stock: 8 }));
    await assertFails(updateDoc(doc(db, 'productos', 'prod1'), { stock: 50 }));
    await assertFails(updateDoc(doc(db, 'productos', 'prod1'), { precio: 1 }));
  });

  test('el Administrador edita su catálogo, no el de otro negocio', async () => {
    await assertSucceeds(updateDoc(doc(como('admin1'), 'productos', 'prod1'), { precio: 40 }));
    await assertFails(updateDoc(doc(como('admin1'), 'productos', 'prod1'), { idNegocio: 'n2' }));
    await assertFails(setDoc(doc(como('admin1'), 'productos', 'ajeno'), { idNegocio: 'n2', nombre: 'X' }));
  });

  test('un cliente no puede tocar el catálogo', async () => {
    await assertFails(updateDoc(doc(como('cli1'), 'productos', 'prod1'), { precio: 1 }));
  });

  test('cupones: los gestiona el Administrador; el cliente solo los lee', async () => {
    await assertSucceeds(getDoc(doc(como('cli1'), 'negocios/n1/cupones', 'CARO10')));
    await assertFails(updateDoc(doc(como('cli1'), 'negocios/n1/cupones', 'CARO10'), { valor: 100 }));
    await assertSucceeds(updateDoc(doc(como('admin1'), 'negocios/n1/cupones', 'CARO10'), { valor: 15 }));
  });
});

// ---------------------------------------------------------------------------
describe('Registro de actividad (auditoría)', () => {
  const registro = (uid, cambios = {}) => ({
    tipo: 'pedido', descripcion: 'Cambió el estado', idUsuario: uid, nombreUsuario: 'X', rol: 'Cocina',
    fecha: serverTimestamp(), ...cambios,
  });

  test('cada persona anota SUS acciones en su negocio', async () => {
    await assertSucceeds(addDoc(collection(como('cocina1'), 'negocios/n1/actividad'), registro('cocina1')));
  });

  test('no se puede anotar a nombre de otro ni en otro negocio', async () => {
    await assertFails(addDoc(collection(como('cocina1'), 'negocios/n1/actividad'), registro('admin1')));
    await assertFails(addDoc(collection(como('cocina1'), 'negocios/n2/actividad'), registro('cocina1')));
  });

  test('nadie edita ni borra el registro; solo el Administrador lo lee', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'negocios/n1/actividad', 'a1'), { tipo: 'caja', descripcion: 'Cerró caja' }),
    );
    await assertSucceeds(getDoc(doc(como('admin1'), 'negocios/n1/actividad', 'a1')));
    await assertFails(getDoc(doc(como('cajero1'), 'negocios/n1/actividad', 'a1')));
    await assertFails(updateDoc(doc(como('admin1'), 'negocios/n1/actividad', 'a1'), { descripcion: 'nada' }));
    await assertFails(deleteDoc(doc(como('admin1'), 'negocios/n1/actividad', 'a1')));
  });
});

// ---------------------------------------------------------------------------
describe('Caja', () => {
  test('el cajero abre SU caja en su sucursal', async () => {
    await assertSucceeds(
      setDoc(doc(como('cajero1'), 'cajas', 'c1'), {
        idCajero: 'cajero1', idNegocio: 'n1', idSucursal: 's1', estado: 'Abierta', montoInicial: 100,
      }),
    );
  });

  test('no puede abrir una caja a nombre de otro', async () => {
    await assertFails(
      setDoc(doc(como('cajero1'), 'cajas', 'c2'), {
        idCajero: 'otro', idNegocio: 'n1', idSucursal: 's1', estado: 'Abierta', montoInicial: 100,
      }),
    );
  });

  test('las cajas cerradas no se borran', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'cajas', 'c3'), { idCajero: 'cajero1', idNegocio: 'n1', estado: 'Cerrada' }),
    );
    await assertFails(deleteDoc(doc(como('cajero1'), 'cajas', 'c3')));
    await assertFails(deleteDoc(doc(como('super1'), 'cajas', 'c3')));
  });
});

describe('Delivery por zonas', () => {
  const crear = (datos) => setDoc(doc(como('cli1'), 'pedidos', 'nuevo'), datos);
  const delivery = (cambios = {}) =>
    pedidoCliente('cli1', {
      idSucursal: 's3', modalidad: 'Delivery', direccionEntrega: { texto: 'Calle 1' }, total: 40, ...cambios,
    });

  test('con zonas, el pedido lleva la zona y su costo exacto', async () => {
    await assertSucceeds(crear(delivery({ zonaEntrega: 'Centro', costoEnvio: 5 })));
  });

  test('no se puede omitir la zona ni bajar el costo de envío', async () => {
    await assertFails(crear(delivery()));
    await assertFails(crear(delivery({ zonaEntrega: 'Centro', costoEnvio: 1 })));
    await assertFails(crear(delivery({ zonaEntrega: 'Inventada', costoEnvio: 0 })));
  });

  test('se respeta el pedido mínimo para delivery', async () => {
    await assertFails(crear(delivery({ zonaEntrega: 'Norte', costoEnvio: 8, total: 20 })));
  });

  test('sin delivery no hay costo de envío', async () => {
    await assertFails(crear(pedidoCliente('cli1', { costoEnvio: 5 })));
  });
});

describe('Registro de errores de la app', () => {
  const error = (uid, cambios = {}) => ({
    mensaje: 'Null check operator', pila: '', contexto: '', plataforma: 'web', version: 'v1.0.0 (1)',
    idUsuario: uid, rol: 'Cajero', idNegocio: 'n1', fecha: serverTimestamp(), ...cambios,
  });

  test('cada persona anota sus propios errores', async () => {
    await assertSucceeds(addDoc(collection(como('cajero1'), 'erroresApp'), error('cajero1')));
  });

  test('no a nombre de otro, ni sin sesión, ni con textos enormes', async () => {
    await assertFails(addDoc(collection(como('cajero1'), 'erroresApp'), error('admin1')));
    await assertFails(addDoc(collection(env.unauthenticatedContext().firestore(), 'erroresApp'), error('x')));
    await assertFails(addDoc(collection(como('cajero1'), 'erroresApp'), error('cajero1', { mensaje: 'x'.repeat(600) })));
  });

  test('solo el SuperAdmin los lee y los borra', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'erroresApp', 'e1'), { mensaje: 'Fallo', idUsuario: 'cajero1' }),
    );
    await assertFails(getDoc(doc(como('admin1'), 'erroresApp', 'e1')));
    await assertFails(getDoc(doc(como('cajero1'), 'erroresApp', 'e1')));
    await assertSucceeds(getDoc(doc(como('super1'), 'erroresApp', 'e1')));
    await assertFails(updateDoc(doc(como('super1'), 'erroresApp', 'e1'), { mensaje: 'otro' }));
    await assertSucceeds(deleteDoc(doc(como('super1'), 'erroresApp', 'e1')));
  });
});

describe('Permisos ajustables por el Administrador', () => {
  const quitarPermisos = () =>
    env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'negocios', 'n1'), {
        permisos: { cajeroCancelaPedidos: false, cajeroRegistraEgresos: false, cajeroTomaPedidosMesa: false },
      }),
    );
  const egreso = { tipo: 'Egreso', metodoPago: 'Efectivo', monto: 10, idUsuario: 'cajero1', concepto: 'Gas' };
  const pedidoMesa = () => ({
    idNegocio: 'n1', idSucursal: 's1', modalidad: 'Mesa', metodoPago: 'Por definir', estado: 'Pendiente',
    origen: 'cajero', creadoPor: 'cajero1', cobrado: false, total: 20, alergias: [], fechaCreacion: serverTimestamp(),
  });
  const abrirCaja = () =>
    env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'cajas', 'c9'), { idCajero: 'cajero1', idNegocio: 'n1', estado: 'Abierta' }),
    );

  test('por defecto el cajero cancela, saca dinero y toma pedidos en mesa', async () => {
    await abrirCaja();
    await assertSucceeds(updateDoc(doc(como('cajero1'), 'pedidos', 'ped1'), { estado: 'Cancelado' }));
    await assertSucceeds(addDoc(collection(como('cajero1'), 'cajas/c9/movimientos'), egreso));
    await assertSucceeds(setDoc(doc(como('cajero1'), 'pedidos', 'mesa1'), pedidoMesa()));
  });

  test('si el Administrador quita los permisos, el servidor los bloquea', async () => {
    await abrirCaja();
    await quitarPermisos();
    await assertFails(updateDoc(doc(como('cajero1'), 'pedidos', 'ped1'), { estado: 'Cancelado' }));
    await assertFails(addDoc(collection(como('cajero1'), 'cajas/c9/movimientos'), egreso));
    await assertFails(setDoc(doc(como('cajero1'), 'pedidos', 'mesa1'), pedidoMesa()));
    // Lo demás sigue funcionando.
    await assertSucceeds(updateDoc(doc(como('cajero1'), 'pedidos', 'ped1'), { estado: 'En preparación' }));
    await assertSucceeds(updateDoc(doc(como('admin1'), 'pedidos', 'ped1'), { estado: 'Cancelado' }));
  });

  test('la cocina no cancela salvo que se lo permitan', async () => {
    await assertFails(updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), { estado: 'Cancelado' }));
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'negocios', 'n1'), { permisos: { cocinaCancelaPedidos: true } }),
    );
    await assertSucceeds(updateDoc(doc(como('cocina1'), 'pedidos', 'ped1'), { estado: 'Cancelado' }));
  });

  test('solo el Administrador cambia los permisos', async () => {
    await assertSucceeds(updateDoc(doc(como('admin1'), 'negocios', 'n1'), { permisos: { cajeroCancelaPedidos: false } }));
    await assertFails(updateDoc(doc(como('cajero1'), 'negocios', 'n1'), { permisos: { cajeroCancelaPedidos: true } }));
  });
});

describe('Solicitudes de negocios nuevos', () => {
  const solicitud = (cambios = {}) => ({
    nombreNegocio: 'Salteñas Doña Rosa', ciudad: 'Cochabamba', telefono: '71234567', nit: '', mensaje: '',
    nombreSolicitante: 'Ana', correo: 'ana@gmail.com', estado: 'Pendiente', fecha: serverTimestamp(), ...cambios,
  });

  test('un cliente envía su solicitud', async () => {
    await assertSucceeds(setDoc(doc(como('cli1'), 'solicitudesNegocio', 'cli1'), solicitud()));
  });

  test('no puede enviarla aprobada, ni a nombre de otro, ni siendo personal', async () => {
    await assertFails(setDoc(doc(como('cli1'), 'solicitudesNegocio', 'cli1'), solicitud({ estado: 'Aprobada' })));
    await assertFails(setDoc(doc(como('cli1'), 'solicitudesNegocio', 'cli2'), solicitud()));
    await assertFails(setDoc(doc(como('cajero1'), 'solicitudesNegocio', 'cajero1'), solicitud()));
  });

  test('solo el SuperAdmin la aprueba y la ve junto a quien la envió', async () => {
    await setDoc(doc(como('cli1'), 'solicitudesNegocio', 'cli1'), solicitud());
    await assertFails(updateDoc(doc(como('cli1'), 'solicitudesNegocio', 'cli1'), { estado: 'Aprobada' }));
    await assertFails(getDoc(doc(como('cli2'), 'solicitudesNegocio', 'cli1')));
    await assertSucceeds(getDoc(doc(como('cli1'), 'solicitudesNegocio', 'cli1')));
    await assertSucceeds(updateDoc(doc(como('super1'), 'solicitudesNegocio', 'cli1'), { estado: 'Aprobada' }));
  });
});

describe('Código de acceso de cada restaurante', () => {
  const unirse = (uid, idNegocio, codigo) =>
    setDoc(doc(como(uid), `usuarios/${uid}/misNegocios`, idNegocio), { codigo, fecha: serverTimestamp() });

  test('un cliente no puede pedir en un restaurante al que no entró con su código', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'usuarios', 'cli3'), { rol: 'Cliente', estado: true, email: 'c3@x.com' }));
    await assertFails(addDoc(collection(como('cli3'), 'pedidos'), pedidoCliente('cli3')));
  });

  test('con el código correcto entra y ya puede pedir', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'usuarios', 'cli3'), { rol: 'Cliente', estado: true, email: 'c3@x.com' }));
    await assertSucceeds(unirse('cli3', 'n1', 'POLLO1'));
    await assertSucceeds(addDoc(collection(como('cli3'), 'pedidos'), pedidoCliente('cli3')));
  });

  test('no puede entrar con un código de otro restaurante o inventado', async () => {
    await assertFails(unirse('cli3', 'n1', 'OTRA22'));
    await assertFails(unirse('cli3', 'n1', 'NOEXIS'));
    await assertFails(setDoc(doc(como('cli3'), 'usuarios/cli3/misNegocios', 'n2'), { codigo: 'OTRA22' }));
  });

  test('un código se puede consultar, pero nadie puede listar los códigos', async () => {
    const anon = env.unauthenticatedContext().firestore();
    await assertSucceeds(getDoc(doc(anon, 'codigosNegocio', 'POLLO1')));
    await assertFails(getDocs(collection(como('cli1'), 'codigosNegocio')));
  });

  test('solo el SuperAdmin crea códigos', async () => {
    await assertSucceeds(setDoc(doc(como('super1'), 'codigosNegocio', 'NUEVO9'), { idNegocio: 'n1', nombre: 'x' }));
    await assertFails(setDoc(doc(como('admin1'), 'codigosNegocio', 'MIO123'), { idNegocio: 'n1', nombre: 'x' }));
    await assertFails(setDoc(doc(como('cli1'), 'codigosNegocio', 'MIO123'), { idNegocio: 'n1', nombre: 'x' }));
  });
});

describe('Condiciones de cada restaurante', () => {
  test('si el restaurante cambia sus condiciones, el cliente debe aceptarlas antes de pedir', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'negocios', 'n1'), { condiciones: { version: '2026-10-25 20:00' } }));
    await assertFails(addDoc(collection(como('cli1'), 'pedidos'), pedidoCliente('cli1')));
    await assertSucceeds(updateDoc(doc(como('cli1'), 'usuarios/cli1/misNegocios', 'n1'), {
      condicionesVersion: '2026-10-25 20:00', condicionesAceptadasEn: serverTimestamp(),
    }));
    await assertSucceeds(addDoc(collection(como('cli1'), 'pedidos'), pedidoCliente('cli1')));
  });

  test('al aceptar, el cliente no puede cambiar a qué restaurante entró', async () => {
    await assertFails(updateDoc(doc(como('cli1'), 'usuarios/cli1/misNegocios', 'n1'), { codigo: 'OTRA22' }));
    await assertFails(updateDoc(doc(como('cli2'), 'usuarios/cli1/misNegocios', 'n1'), {
      condicionesVersion: 'x', condicionesAceptadasEn: serverTimestamp(),
    }));
  });

  test('solo el Administrador de ese restaurante cambia sus condiciones', async () => {
    await assertSucceeds(updateDoc(doc(como('admin1'), 'negocios', 'n1'), { condiciones: { version: 'v' } }));
    await assertFails(updateDoc(doc(como('admin1'), 'negocios', 'n2'), { condiciones: { version: 'v' } }));
    await assertFails(updateDoc(doc(como('cajero1'), 'negocios', 'n1'), { condiciones: { version: 'v' } }));
  });
});

describe('Pausa de pedidos (HU-47)', () => {
  test('con la sucursal en pausa nadie puede hacer un pedido ahí', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'sucursales', 's1'), { pedidosPausados: true, motivoPausa: 'Cocina llena' }));
    await assertFails(addDoc(collection(como('cli1'), 'pedidos'), pedidoCliente('cli1')));
  });

  test('al reanudar, se vuelve a poder pedir', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'sucursales', 's1'), { pedidosPausados: false }));
    await assertSucceeds(addDoc(collection(como('cli1'), 'pedidos'), pedidoCliente('cli1')));
  });

  test('solo el Administrador pausa su sucursal', async () => {
    await assertSucceeds(updateDoc(doc(como('admin1'), 'sucursales', 's1'), { pedidosPausados: true }));
    await assertFails(updateDoc(doc(como('cajero1'), 'sucursales', 's1'), { pedidosPausados: true }));
    await assertFails(updateDoc(doc(como('admin1'), 'sucursales', 's2'), { pedidosPausados: true }));
  });
});

describe('Asignar repartidor (HU-39)', () => {
  const asignacion = (uid) => ({ idRepartidor: uid, nombreRepartidor: 'Repa', telefonoRepartidor: '70000000' });

  test('el Cajero asigna un pedido Listo a un repartidor de su negocio', async () => {
    await assertSucceeds(updateDoc(doc(como('cajero1'), 'pedidos', 'pedDelivery'), asignacion('repa1')));
  });

  test('no se puede asignar a alguien que no es repartidor del negocio', async () => {
    await assertFails(updateDoc(doc(como('cajero1'), 'pedidos', 'pedDelivery'), asignacion('cocina1')));
    await assertFails(updateDoc(doc(como('cajero1'), 'pedidos', 'pedDelivery'), asignacion('cli1')));
  });

  test('la Cocina no asigna repartidores', async () => {
    await assertFails(updateDoc(doc(como('cocina1'), 'pedidos', 'pedDelivery'), asignacion('repa1')));
  });

  test('no se asigna un pedido que todavía no está Listo', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      updateDoc(doc(ctx.firestore(), 'pedidos', 'pedDelivery'), { estado: 'En preparación' }));
    await assertFails(updateDoc(doc(como('cajero1'), 'pedidos', 'pedDelivery'), asignacion('repa1')));
  });

  test('el repartidor asignado sale con el pedido; otro no puede tomarlo', async () => {
    await updateDoc(doc(como('cajero1'), 'pedidos', 'pedDelivery'), asignacion('repa1'));
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'usuarios', 'repa2'), { rol: 'Repartidor', estado: true, idNegocio: 'n1' }));
    await assertFails(updateDoc(doc(como('repa2'), 'pedidos', 'pedDelivery'), {
      estado: 'En camino', idRepartidor: 'repa2', nombreRepartidor: 'Otro', telefonoRepartidor: '1',
    }));
    await assertSucceeds(updateDoc(doc(como('repa1'), 'pedidos', 'pedDelivery'), { estado: 'En camino' }));
  });

  test('el Cajero ve a los repartidores de su negocio, pero no al resto del personal', async () => {
    await assertSucceeds(getDocs(query(collection(como('cajero1'), 'usuarios'),
      where('idNegocio', '==', 'n1'), where('rol', '==', 'Repartidor'))));
    await assertFails(getDoc(doc(como('cajero1'), 'usuarios', 'cocina1')));
  });
});

describe('Versión publicada de la app', () => {
  const version = { version: '1.1.0', build: 2, buildMinimo: 0, urlApk: '', notas: '' };

  test('cualquiera la lee, incluso sin sesión', async () => {
    await env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), 'plataforma', 'app'), version));
    await assertSucceeds(getDoc(doc(env.unauthenticatedContext().firestore(), 'plataforma', 'app')));
  });

  test('solo el SuperAdmin la publica', async () => {
    await assertSucceeds(setDoc(doc(como('super1'), 'plataforma', 'app'), version));
    await assertFails(setDoc(doc(como('admin1'), 'plataforma', 'app'), { ...version, buildMinimo: 99 }));
    await assertFails(setDoc(doc(como('cli1'), 'plataforma', 'app'), version));
  });
});

test('cualquier colección que no está en las reglas queda cerrada', async () => {
  await assertFails(setDoc(doc(como('super1'), 'secreto', 'x'), { a: 1 }));
});
