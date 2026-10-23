# Pruebas de las reglas de seguridad

Comprueban, en el **emulador** de Firebase (nunca en la base real), que
las reglas de `firestore.rules` hacen lo que deben: un cliente no puede
hacerse administrador, la cocina de otro negocio no ve nuestros pedidos,
un cupón no da más descuento del que corresponde, el registro de
actividad no se puede borrar, etc.

```
cd test_reglas
npm install
npm test
```

Necesita **Node 20+** y **Java 21+** (el emulador de Firestore corre en Java).
En GitHub se ejecutan solas en cada Pull Request (`.github/workflows/ci.yml`).
