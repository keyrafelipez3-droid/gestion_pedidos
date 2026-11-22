# Documentación de Nami

| Documento | Para quién |
|---|---|
| [manual-usuario.md](manual-usuario.md) | Cada rol: Cliente, Cajero, Cocina, Repartidor, Administrador y SuperAdmin |
| [manual-tecnico.md](manual-tecnico.md) | Quien mantenga el sistema: arquitectura, reglas, scripts, despliegue y respaldo |
| [guia-consola.md](guia-consola.md) | Pasos en Firebase y Google Cloud: App Check, llaves de API, llave de servicio, plan Blaze |
| [publicar-play-store.md](publicar-play-store.md) | Firma de la app y formulario de Google Play |
| [borrador-acuerdo-alaitz-susan.md](borrador-acuerdo-alaitz-susan.md) | Borrador del acuerdo entre la desarrolladora y la dueña |
| [revision-abogado.md](revision-abogado.md) | Lista de puntos para revisar con un abogado |

Reglas que no cambian:

- No pasar de 99 usuarios en Firebase Authentication (las cuentas de prueba también cuentan).
- Mantener el plan gratuito (Spark). Blaze y SMS solo si las dueñas lo deciden.
- `serviceAccountKey.json` nunca se sube a GitHub ni se comparte.
