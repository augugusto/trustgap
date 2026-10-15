# Dónde vive el código

El proyecto no depende de ninguna plataforma para funcionar: los fuentes, la
ceremonia y el frontend son archivos locales. Lo único que cambia con el
hosting es dónde se publica el repo y quién puede reescribir su historia.

Este proyecto se generó con hosting **{{HOSTING}}**.

Repo: `{{REPO_URL}}`

Para cambiarlo en cualquier momento:

```bash
scripts/nuevo-proyecto.sh update . --hosting radicle   # o github
```

Eso re-renderiza este archivo y el bloque de hosting del README. No toca
código ni dependencias.

## Publicar el repo en Radicle

Si el hosting es Radicle, `scripts/nuevo-proyecto.sh init` corre `rad init`
para anunciar el proyecto a la red. Eso necesita el CLI de Radicle
(`curl -sSf https://radicle.xyz/install | sh`) y una identidad, que se crea
una sola vez por máquina con `rad auth`. Si falta alguno, el script avisa y el
proyecto queda igual de completo: se publica después con `rad init` desde
adentro del proyecto.

## Las tres opciones

| Hosting | A favor | En contra |
|---|---|---|
| **Radicle** | git descentralizado, sin dueño único, la historia no se reescribe, soporta contribuciones anónimas | menos gente lo conoce, hay que correr un nodo o usar un seed |
| **GitHub** | cómodo, gratis, todo el mundo lo tiene | un solo dueño puede reescribir la historia (force-push, borrar tags) e inyectar commits |

## Sobre el CI

El template incluye `.github/workflows/ci.yml`, que es específico de GitHub
Actions. Si el repo vive en Radicle, ese archivo queda inerte y
no molesta; los mismos tres chequeos se pueden correr a mano:

```bash
cd contracts && forge build --sizes && forge test
cd ceremony  && npm ci && npm run build && npm test
test -f frontend/index.html && test -f frontend/js/config.js
```

Nada del pipeline depende de GitHub: no hay pasos que llamen a la API de
GitHub, ni secretos, ni deploy a un servicio externo.
