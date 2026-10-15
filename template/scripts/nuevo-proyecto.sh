#!/usr/bin/env bash
#
# nuevo-proyecto.sh — scaffolding para el stack trustgap
#   contracts (Foundry/Solidity) + ceremony (CLI TS) + frontend estático + CI
#
# Uso:
#   nuevo-proyecto.sh doctor [dir]
#   nuevo-proyecto.sh init <dir> [opciones]
#   nuevo-proyecto.sh update <dir> [opciones]
#   nuevo-proyecto.sh version
#
# No depende de GitHub ni de ningún servicio: todo se genera local.
#
set -euo pipefail

VERSION="0.1.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../template"

# ── salida ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_OFF=""
fi
ok()   { printf '%s ok %s %s\n' "$C_OK"   "$C_OFF" "$*"; }
warn() { printf '%s !! %s %s\n' "$C_WARN" "$C_OFF" "$*"; }
die()  { printf '%s ERR%s %s\n' "$C_ERR"  "$C_OFF" "$*" >&2; exit 1; }
note() { printf '%s    %s%s\n'  "$C_DIM"  "$*" "$C_OFF"; }

# ── dependencias ───────────────────────────────────────────────────────
# forge suele vivir en ~/.foundry/bin, que no está en el PATH de una shell
# no interactiva (el caso de init corriendo desde un script o desde CI).
ensure_forge_on_path() {
  if ! command -v forge >/dev/null 2>&1 && [ -x "${HOME}/.foundry/bin/forge" ]; then
    PATH="${HOME}/.foundry/bin:${PATH}"; export PATH
    note "uso forge de ~/.foundry/bin (no estaba en el PATH)"
  fi
}

NEED_TOOLS=(git python3 node npm forge)

have() { command -v "$1" >/dev/null 2>&1; }

tool_version() {
  case "$1" in
    git)     git --version 2>/dev/null | head -1 ;;
    node)    node --version 2>/dev/null ;;
    npm)     npm --version 2>/dev/null ;;
    python3) python3 --version 2>/dev/null ;;
    forge)   forge --version 2>/dev/null | head -1 ;;
  esac
}

node_major() { node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1; }

check_deps() {
  ensure_forge_on_path
  local missing=0
  for t in "${NEED_TOOLS[@]}"; do
    if have "$t"; then
      printf '  %-8s %s\n' "$t" "$(tool_version "$t")"
    else
      printf '  %-8s %s\n' "$t" "FALTA"
      missing=1
    fi
  done
  if have node; then
    local major; major="$(node_major)"
    if [ "${major:-0}" -lt 20 ]; then
      printf '  %-8s %s\n' "node>=20" "FALLA: tenés node ${major}, el proyecto pide >=20"
      missing=1
    fi
  fi
  return "$missing"
}

# tplvar <archivo-vars> <CLAVE> — lee un valor, tolerando comillas
tplvar() { sed -n "s/^$2=//p" "$1" | sed 's/^"//; s/"$//' | head -1; }

# rad está en ~/.radicle/bin cuando lo instalás con el script oficial
find_rad() {
  if command -v rad >/dev/null 2>&1; then command -v rad
  elif [ -x "${HOME}/.radicle/bin/rad" ]; then printf '%s\n' "${HOME}/.radicle/bin/rad"
  fi
}

rad_home_dir() { printf '%s\n' "${RAD_HOME:-${HOME}/.radicle}"; }

check_optional() {
  printf '\nopcionales\n'
  local rad; rad="$(find_rad || true)"
  if [ -z "$rad" ]; then
    printf '  %-10s %s\n' "rad" "no instalado (sólo para hosting radicle)"
    note "se instala con:  curl -sSf https://radicle.xyz/install | sh"
    return 0
  fi
  printf '  %-10s %s\n' "rad" "$("$rad" --version 2>/dev/null | head -1)"
  local rh; rh="$(rad_home_dir)"
  if [ -f "$rh/keys/radicle.pub" ]; then
    printf '  %-10s %s\n' "identidad" "ok ($rh/keys/radicle.pub)"
  else
    printf '  %-10s %s\n' "identidad" "falta: 'rad auth' (una sola vez por máquina)"
  fi
}

# ── doctor ─────────────────────────────────────────────────────────────
cmd_doctor() {
  local target="${1:-}"
  printf 'dependencias del sistema\n'
  if ! check_deps; then
    warn "faltan dependencias: instalalas antes de correr 'init'"
  else
    ok "todas las dependencias presentes"
  fi
  check_optional

  if [ -n "$target" ]; then
    printf '\nestado del proyecto %s\n' "$target"
    [ -d "$target" ] || die "no existe el directorio: $target"
    if [ -f "$target/.template-vars" ]; then
      ok "generado con el template (vars en .template-vars)"
      sed 's/^/  /' "$target/.template-vars"
    else
      warn "no encuentro .template-vars (¿lo generó este script?)"
    fi
    for d in contracts/lib/openzeppelin-contracts contracts/lib/forge-std; do
      if [ -d "$target/$d" ]; then ok "$d presente"; else warn "$d falta (corré: cd contracts && forge install)"; fi
    done
    if [ -d "$target/ceremony/node_modules" ]; then ok "ceremony/node_modules presente"; else warn "ceremony/node_modules falta (corré: cd ceremony && npm ci)"; fi
  fi
}

# ── sustitución de placeholders ────────────────────────────────────────
subst_dir() {
  local dir="$1"; shift
  local pairs=("$@")
  python3 - "$dir" "${pairs[@]}" <<'PY'
import os, sys

root = sys.argv[1]
pairs = {}
for kv in sys.argv[2:]:
    k, _, v = kv.partition('=')
    pairs['{{%s}}' % k] = v

SKIP_EXT = {'.png','.jpg','.jpeg','.gif','.ico','.woff','.woff2','.ttf','.otf',
            '.pdf','.zip','.gz','.tgz','.wasm','.so','.bin','.mp4','.webp'}

touched = 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in ('.git','node_modules','lib','dist','out','cache')]
    for fn in filenames:
        if fn.endswith('.min.js'):
            continue
        path = os.path.join(dirpath, fn)
        if os.path.splitext(fn)[1].lower() in SKIP_EXT:
            continue
        try:
            with open(path, 'r', encoding='utf-8') as fh:
                data = fh.read()
        except (UnicodeDecodeError, OSError):
            continue
        if '{{' not in data:
            continue
        new = data
        for k, v in pairs.items():
            new = new.replace(k, v)
        if new != data:
            with open(path, 'w', encoding='utf-8') as fh:
                fh.write(new)
            touched += 1
            print('  sustituido: %s' % os.path.relpath(path, root))
PY
}

# ── bloque de hosting del README ───────────────────────────────────────
render_hosting_block() {
  local f="$1" hosting="$2" repo="$3"
  [ -f "$f" ] || return 0
  grep -q 'HOSTING:START' "$f" || return 0
  local block
  block="$(python3 - "$hosting" "$repo" <<'PY'
import sys
hosting, repo = sys.argv[1], sys.argv[2]
nombre = {'radicle':'Radicle','github':'GitHub'}[hosting]
extra = {
 'radicle':'git descentralizado: sin dueño único y con historia que no se reescribe.',
 'github' :'cómodo, pero un solo dueño puede reescribir la historia (force-push, borrar tags).',
}[hosting]
print('## Dónde vive el código')
print()
print('Hosting elegido: **%s**.' % nombre)
print()
print('Repo: `%s`' % repo)
print()
print(extra)
print()
print('Para cambiarlo: `scripts/nuevo-proyecto.sh update . --hosting radicle|github`')
PY
)"
  python3 - "$f" "$block" <<'PY'
import sys, re, pathlib
path, block = sys.argv[1], sys.argv[2]
p = pathlib.Path(path)
s = p.read_text()
if '<!-- HOSTING:START -->' not in s:
    sys.exit(0)
s = re.sub(r'<!-- HOSTING:START -->.*?<!-- HOSTING:END -->',
           '<!-- HOSTING:START -->\n' + block.rstrip() + '\n<!-- HOSTING:END -->',
           s, flags=re.S)
p.write_text(s)
PY
}

write_vars() {
  local dest="$1" nombre="$2" paquete="$3" simbolo="$4" dominio="$5" repo="$6" hosting="$7"
  cat > "$dest/.template-vars" <<EOF
NOMBRE="$nombre"
PAQUETE=$paquete
SIMBOLO=$simbolo
DOMINIO=$dominio
REPO_URL=$repo
HOSTING=$hosting
TEMPLATE_VERSION=$VERSION
GENERADO=$(date -Iseconds)
EOF
}

commit_if_possible() {
  local dir="$1" msg="$2"
  if git -C "$dir" add -A && git -C "$dir" -c commit.gpgsign=false commit -q -m "$msg" 2>/dev/null; then
    return 0
  fi
  return 1
}

# ── paso Radicle ───────────────────────────────────────────────────────
# Publica el repo nuevo en la red Radicle. Necesita el CLI (rad) y una
# identidad de Radicle, que se crea una sola vez por máquina con 'rad auth'.
# Si falta cualquiera de las dos, avisa y sigue: el proyecto queda igual.
radicle_init() {
  local dir="$1" nombre="$2"
  local rad; rad="$(find_rad || true)"
  local rh; rh="$(rad_home_dir)"

  if [ -z "$rad" ]; then
    warn "no encuentro el CLI de Radicle: salteo la publicación"
    note "se instala con:  curl -sSf https://radicle.xyz/install | sh"
    note "y después, dentro del proyecto:  rad init"
    return 0
  fi
  if [ ! -f "$rh/keys/radicle.pub" ]; then
    warn "todavía no hay identidad de Radicle en $rh: salteo la publicación"
    note "se crea una sola vez con 'rad auth' (pide un alias y una passphrase)"
    note "y después, dentro del proyecto:  rad init"
    return 0
  fi

  printf 'publicando en Radicle\n'
  local flags=()
  local help
  help="$("$rad" init --help 2>&1 || true)"
  if printf '%s' "$help" | grep -q -- '--name'; then
    flags=(--name "$nombre")
    printf '%s' "$help" | grep -q -- '--default-branch' && flags+=(--default-branch main)
    printf '%s' "$help" | grep -q -- '--no-confirm'     && flags+=(--no-confirm)
  fi

  if ( cd "$dir" && "$rad" init "${flags[@]}" ); then
    ok "repo de Radicle inicializado"
  else
    warn "rad init no terminó bien; probá a mano dentro del proyecto"
    note "si dice que no hay nodo:  rad node start"
  fi
}

# ── init ───────────────────────────────────────────────────────────────
cmd_init() {
  local dest="" nombre="" paquete="" simbolo="" dominio="" repo_url="" hosting="radicle"
  local do_install=1 do_radicle=1 force=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --nombre)   nombre="$2"; shift 2 ;;
      --paquete)  paquete="$2"; shift 2 ;;
      --simbolo)  simbolo="$2"; shift 2 ;;
      --dominio)  dominio="$2"; shift 2 ;;
      --repo-url) repo_url="$2"; shift 2 ;;
      --hosting)  hosting="$2"; shift 2 ;;
      --no-install) do_install=0; shift ;;
      --no-radicle) do_radicle=0; shift ;;
      --force)    force=1; shift ;;
      -*) die "opción desconocida: $1" ;;
      *)  [ -z "$dest" ] || die "sobra un argumento: $1"; dest="$1"; shift ;;
    esac
  done

  [ -n "$dest" ] || die "falta el directorio destino. Uso: nuevo-proyecto.sh init <dir> [opciones]"
  case "$hosting" in radicle|github) ;; *) die "--hosting debe ser radicle o github";; esac

  local base
  base="$(basename "$dest")"
  [ -n "$nombre" ]  || nombre="${base//[-_]/ }"
  [ -n "$paquete" ] || paquete="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/-\{2,\}/-/g; s/^-//; s/-$//')"
  [ -n "$paquete" ] || die "no pude derivar el paquete del nombre del directorio; pasá --paquete"
  if [ -z "$simbolo" ]; then
    simbolo="$(printf '%s' "$paquete" | tr -d -- '-' | tr '[:lower:]' '[:upper:]' | cut -c1-4)"
  fi
  [ -n "$dominio" ] || dominio="${paquete}.eth"
  if [ -z "$repo_url" ]; then
    case "$hosting" in
      github)  repo_url="https://github.com/CAMBIAR-USUARIO/${paquete}" ;;
      radicle) repo_url="radicle://${paquete}" ;;
    esac
  fi

  [ -d "$TEMPLATE_DIR" ] || die "no encuentro el template en $TEMPLATE_DIR (¿corriste el script desde el repo del template?)"
  if [ -d "$dest" ] && [ -n "$(ls -A "$dest" 2>/dev/null || true)" ] && [ "$force" -eq 0 ]; then
    die "el directorio $dest no está vacío (usá --force si querés escribir igual)"
  fi

  printf 'dependencias\n'
  check_deps || die "faltan dependencias; corré 'nuevo-proyecto.sh doctor' para el detalle"

  printf '\ncreando %s\n' "$dest"
  mkdir -p "$dest"
  cp -a "$TEMPLATE_DIR"/. "$dest"/
  # los workflows viven como _github/ en el template para que un push al repo
  # del template no toque .github/workflows/; acá se restauran a su lugar.
  if [ -d "$dest/_github" ]; then mv "$dest/_github" "$dest/.github"; fi

  printf '\nsustituyendo valores\n'
  subst_dir "$dest" \
    "NOMBRE=$nombre" "PAQUETE=$paquete" "SIMBOLO=$simbolo" \
    "DOMINIO=$dominio" "REPO_URL=$repo_url" "HOSTING=$hosting"

  write_vars "$dest" "$nombre" "$paquete" "$simbolo" "$dominio" "$repo_url" "$hosting"
  render_hosting_block "$dest/README.md" "$hosting" "$repo_url"
  ok "valores escritos en .template-vars"

  if [ ! -d "$dest/.git" ]; then
    git -C "$dest" init -q
    if commit_if_possible "$dest" "chore: estructura inicial (${paquete})"; then
      ok "repo git inicializado con el primer commit"
    else
      warn "git init hecho pero no pude commitear (¿identidad o firma de git?)"
    fi
  fi

  if [ "$do_install" -eq 1 ]; then
    printf '\ndependencias de contratos (forge install)\n'
    if ( cd "$dest/contracts" \
         && forge install OpenZeppelin/openzeppelin-contracts@v5.0.2 --no-commit >/dev/null 2>&1 \
         && forge install foundry-rs/forge-std@v1.9.6 --no-commit >/dev/null 2>&1 \
         && forge build --sizes >/dev/null 2>&1 ); then
      ok "openzeppelin-contracts v5.0.2 + forge-std v1.9.6 instalados y compilando"
    else
      warn "algo falló en forge install/build; corré 'cd contracts && forge build' a mano"
    fi

    printf '\ndependencias de ceremony (npm ci)\n'
    if ( cd "$dest/ceremony" && npm ci --no-audit --no-fund >/dev/null 2>&1 && npm run build >/dev/null 2>&1 ); then
      ok "ceremony instalado y compilando"
    else
      warn "algo falló con npm; corré 'cd ceremony && npm ci' a mano"
    fi

    if [ -d "$dest/.git" ]; then
      if commit_if_possible "$dest" "chore(deps): submódulos de Foundry"; then
        ok "dependencias commiteadas"
      else
        warn "quedaron cambios sin commitear (git status para ver)"
      fi
    fi
  else
    note "--no-install: me salteo forge install y npm ci"
  fi

  if [ "$hosting" = "radicle" ] && [ "$do_radicle" -eq 1 ]; then
    printf '\n'
    radicle_init "$dest" "$nombre"
  elif [ "$hosting" != "radicle" ]; then
    note "hosting $hosting: no inicializo nada en Radicle"
  fi

  printf '\nlisto. próximos pasos:\n'
  note "cd $dest"
  note "editá frontend/js/config.js (EXPECTED_CID, CONTRACTS, ENS_DOMAIN) después del deploy"
  note "editá contracts/foundry.toml ([rpc_endpoints]) con tu RPC"
  note "npm test   # contratos (forge) + ceremony (vitest)"
  note "docs/EDITAR.md tiene la lista completa de lo que conviene tocar"
}

# ── update ─────────────────────────────────────────────────────────────
# Sincroniza los archivos de tooling listados en template/MANIFEST y/o cambia
# el hosting. Nunca toca src/, tests, package.json ni dependencias.
cmd_update() {
  local dest="" template_override="" hosting="" dry=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --template) template_override="$2"; shift 2 ;;
      --hosting)  hosting="$2"; shift 2 ;;
      --dry-run)  dry=1; shift ;;
      -*) die "opción desconocida: $1" ;;
      *)  [ -z "$dest" ] || die "sobra un argumento: $1"; dest="$1"; shift ;;
    esac
  done
  [ -n "$dest" ] || die "falta el directorio del proyecto. Uso: nuevo-proyecto.sh update <dir> [--template <dir>] [--hosting ...] [--dry-run]"
  [ -d "$dest" ] || die "no existe el directorio: $dest"
  local vars="$dest/.template-vars"
  [ -f "$vars" ] || die "$dest no tiene .template-vars; ¿lo generó este script?"

  if [ -n "$template_override" ]; then TEMPLATE_DIR="$template_override"; fi
  [ -d "$TEMPLATE_DIR" ] || die "no encuentro el template en $TEMPLATE_DIR (pasá --template /ruta/al/repo)"
  [ -f "$TEMPLATE_DIR/MANIFEST" ] || die "el template no tiene MANIFEST"

  case "${hosting:-}" in ""|radicle|github) ;; *) die "--hosting debe ser radicle o github";; esac

  local paquete; paquete="$(tplvar "$vars" PAQUETE)"
  if [ -n "$hosting" ] && [ "$dry" -eq 0 ]; then
    sed -i "s|^HOSTING=.*|HOSTING=$hosting|" "$vars"
    case "$hosting" in
      github)  sed -i "s|^REPO_URL=.*|REPO_URL=https://github.com/CAMBIAR-USUARIO/${paquete}|" "$vars" ;;
      radicle) sed -i "s|^REPO_URL=.*|REPO_URL=radicle://${paquete}|" "$vars" ;;
    esac
    ok "hosting -> $hosting"
  fi

  local NOMBRE PAQUETE SIMBOLO DOMINIO REPO_URL HOSTING
  NOMBRE="$(tplvar "$vars" NOMBRE)"
  PAQUETE="$paquete"
  SIMBOLO="$(tplvar "$vars" SIMBOLO)"
  DOMINIO="$(tplvar "$vars" DOMINIO)"
  REPO_URL="$(tplvar "$vars" REPO_URL)"
  HOSTING="$(tplvar "$vars" HOSTING)"

  # deja en $2 el contenido del archivo del template ya sustituido
  render_into() {
    cp "$1" "$2"
    subst_dir "$(dirname "$2")" \
      "NOMBRE=$NOMBRE" "PAQUETE=$PAQUETE" "SIMBOLO=$SIMBOLO" \
      "DOMINIO=$DOMINIO" "REPO_URL=$REPO_URL" "HOSTING=$HOSTING" >/dev/null
  }

  local changed=0 entry src rel dst tmp
  tmp="$(mktemp -d)"
  # comillas dobles a proposito: $tmp se expande ahora, porque el trap corre
  # en EXIT cuando la variable local ya no existe
  trap "rm -rf '$tmp'" EXIT

  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    case "$entry" in '#'*) continue ;; esac
    src="$TEMPLATE_DIR/$entry"
    rel="$entry"
    case "$rel" in _github/*) rel=".github/${rel#_github/}" ;; esac
    dst="$dest/$rel"
    if [ ! -f "$src" ]; then warn "el template no tiene $entry"; continue; fi
    if [ "$dry" -eq 1 ]; then
      mkdir -p "$tmp/$(dirname "$rel")"
      render_into "$src" "$tmp/$rel"
      if ! cmp -s "$tmp/$rel" "$dst"; then
        printf 'cambiaría: %s\n' "$rel"
        diff -u "$dst" "$tmp/$rel" 2>/dev/null | sed -n '1,40p' || true
        changed=$((changed+1))
      fi
      continue
    fi
    mkdir -p "$(dirname "$dst")" "$tmp/$(dirname "$rel")"
    render_into "$src" "$tmp/$rel"
    if cmp -s "$tmp/$rel" "$dst"; then
      continue
    fi
    cp "$tmp/$rel" "$dst"
    printf 'sincronizado: %s\n' "$rel"
    changed=$((changed+1))
  done < "$TEMPLATE_DIR/MANIFEST"

  if [ -n "$hosting" ] && [ "$dry" -eq 0 ]; then
    render_hosting_block "$dest/README.md" "$hosting" "$REPO_URL"
    ok "bloque de hosting actualizado en README.md"
  fi

  if [ "$changed" -eq 0 ]; then ok "nada para cambiar: el proyecto ya está al día"; fi
  note "update no toca src/, tests, package.json ni dependencias: eso es tuyo"
}

usage() {
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "${BASH_SOURCE[0]}"
}

case "${1:-}" in
  doctor)  shift; cmd_doctor "${1:-}" ;;
  init)    shift; cmd_init "$@" ;;
  update)  shift; cmd_update "$@" ;;
  version) printf 'nuevo-proyecto.sh %s\n' "$VERSION" ;;
  ""|-h|--help|help) usage ;;
  *) die "comando desconocido: $1 (probá: doctor | init | update | version)" ;;
esac
