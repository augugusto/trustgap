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
  --hosting radicle            # radicle | github | nostr
  # --repo-url URL              # si no, se arma un valor por hosting
  # --no-install                # no correr forge install ni npm ci
  # --force                     # escribir en un directorio no vacío

# traer mejoras del template a un proyecto ya generado
scripts/nuevo-proyecto.sh update ../mi-proyecto --dry-run
scripts/nuevo-proyecto.sh update ../mi-proyecto
scripts/nuevo-proyecto.sh update ../mi-proyecto --hosting nostr
```

`init` hace: copia el template, sustituye los placeholders, escribe
`.template-vars`, `git init` + primer commit, `forge install` de
openzeppelin-contracts v5.0.2 y forge-std v1.9.6, `npm ci` en `ceremony/`, y
compila los dos lados para confirmar que arranca sano.

Si `forge` está en `~/.foundry/bin` y no en el `PATH`, el script lo encuentra
solo.

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
