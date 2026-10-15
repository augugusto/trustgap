# Scaffolding

`nuevo-proyecto.sh` genera un proyecto nuevo con la misma estructura que este:
contratos Foundry + CLI de ceremonia en TypeScript + frontend estático + CI.

No depende de GitHub ni de ningún servicio. Todo se genera local y el proyecto
nuevo arranca con sus propios commits.

## Comandos

```bash
# ¿están las herramientas? (git, python3, node>=20, npm, forge)
scripts/nuevo-proyecto.sh doctor
scripts/nuevo-proyecto.sh doctor /ruta/a/un/proyecto   # y el estado de ESE proyecto

# crear un proyecto
scripts/nuevo-proyecto.sh init ../mi-proyecto \
  --nombre "Mi Proyecto" \
  --paquete mi-proyecto \
  --simbolo MPR \
  --dominio mi-proyecto.eth \
  --hosting radicle            # radicle | github
  # --repo-url URL              # si no, se arma un valor por hosting
  # --no-install                # no correr forge install ni npm ci
  # --no-radicle                # no publicar el repo en Radicle
  # --force                     # escribir en un directorio no vacío

# traer mejoras del template a un proyecto ya generado
scripts/nuevo-proyecto.sh update ../mi-proyecto --dry-run
scripts/nuevo-proyecto.sh update ../mi-proyecto
scripts/nuevo-proyecto.sh update ../mi-proyecto --hosting github
```

`init` hace: copia el template, sustituye los placeholders, escribe
`.template-vars`, `git init` + primer commit, `forge install` de
openzeppelin-contracts v5.0.2 y forge-std v1.9.6, `npm ci` en `ceremony/`, y
compila los dos lados para confirmar que arranca sano. Si el hosting es
radicle, además publica el repo con `rad init`.

Si `forge` está en `~/.foundry/bin` y no en el `PATH`, el script lo encuentra
solo.

## El paso de Radicle

Con `--hosting radicle` (el default), después de crear el proyecto `init`
corre `rad init` para publicarlo en la red. Necesita dos cosas:

- el CLI de Radicle, que se instala una vez por máquina con
  `curl -sSf https://radicle.xyz/install | sh` (queda en `~/.radicle/bin`)
- una identidad de Radicle, que se crea una sola vez por máquina con
  `rad auth` (pide un alias y una passphrase, y usa ssh-agent)

Si falta cualquiera de las dos, `init` dice qué falta y termina igual: el
proyecto local queda completo, y se publica después con `rad init` dentro del
proyecto. `doctor` muestra el estado de `rad` y de la identidad.

Con `--no-radicle` se saltea el paso a propósito.

## Cómo funciona el template

- `template/` es el esqueleto. Los valores variables van como placeholders:
  `{{NOMBRE}}`, `{{PAQUETE}}`, `{{SIMBOLO}}`, `{{DOMINIO}}`, `{{REPO_URL}}`,
  `{{HOSTING}}`.
- `template/_github/` existe con ese nombre para que un push a este repo no
  toque `.github/workflows/` (GitHub exige el scope `workflow` para eso). Al
  generar el proyecto, `_github/` se restaura a `.github/`.
- `template/MANIFEST` lista los archivos que `update` sincroniza. A propósito
  no incluye `src/`, tests, `package.json`, `foundry.toml` ni dependencias:
  `update` no pisa nada del proyecto.
- El README del proyecto tiene un bloque entre `<!-- HOSTING:START -->` y
  `<!-- HOSTING:END -->` que `update --hosting` re-renderiza.
- `template/VERSION` es la versión del template; `init` la guarda en
  `.template-vars` del proyecto generado.

### Agregar o cambiar algo del template

1. Si es un archivo nuevo que sale de este repo, agregalo a la lista del
   generador (o copialo a mano) y aplicá las sustituciones que correspondan.
2. Si el proyecto generado tiene que mantenerlo actualizado, sumalo a
   `template/MANIFEST`.
3. Subí `template/VERSION` si el cambio es incompatible con proyectos viejos.

## Verificación

```bash
# end to end: genera un proyecto y corre sus tests
rm -rf /tmp/prueba
scripts/nuevo-proyecto.sh init /tmp/prueba --nombre "Prueba" --paquete prueba
( cd /tmp/prueba/contracts && forge test )
( cd /tmp/prueba/ceremony && npm test )
```

## Scripts que viajan con el proyecto

Además de este scaffolder, en `scripts/` viven dos atajos que se copian a cada
proyecto nuevo y que `update` mantiene al día:

- `ceremonia.sh` — atajos alrededor del CLI de ceremonia: `build`, `cid`,
  `verificar <cid>`, `ipfs`, `propuesta <cid>`, `estado`.
- `publicar.sh` — flujo de publicación de un release: chequea el frontend,
  calcula el CID, lo compara con el último release on-chain, sube y pinnea en
  IPFS, arma la propuesta para la DAO y guarda un manifiesto en `releases/`.
  Tiene `--hasta cid|ipfs|propuesta` y `--forzar`.

Los dos leen un `.env` en la raíz del proyecto (`RPC_URL`, `GOVERNADOR`,
`DAO_SHARE`, `ENS_RESOLVER`, `RELEASE_PROPOSAL`, `IPFS_API`). El modelo para
copiar es `.env.example` del template.

Límite conocido de `publicar.sh`: no manda la transacción de la propuesta ni
vota. Eso queda para la próxima iteración, después de un deploy de prueba; por
ahora imprime los comandos exactos de esos dos pasos.
