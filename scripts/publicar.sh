#!/usr/bin/env bash
#
# publicar.sh — flujo de publicación de un release (versión inicial)
#
# Uso:
#   publicar.sh [--dir <dir>] [--hasta cid|ipfs|propuesta] [--forzar] [--api <url>]
#
# Pasos:
#   1. chequeos: frontend estático completo y CLI de ceremonia compilado
#   2. calcula el CID del directorio
#   3. si hay RPC y RELEASE_PROPOSAL: compara contra el último release on-chain
#      (si es el mismo, corta; --forzar lo saltea)
#   4. sube y pinnea en IPFS (usa IPFS_API); si no hay nodo, avisa y sigue
#   5. arma el calldata de la propuesta y guarda releases/<cid>.json
#   6. imprime el resumen y qué queda: crear la propuesta en la DAO y votar
#
# Lo que NO hace todavía: mandar la transacción de la propuesta ni votar.
# Al final imprime los comandos exactos para esos dos pasos.
#
# Lee las variables de un .env en la raíz del proyecto (si existe):
#   RPC_URL (o BASE_SEPOLIA_RPC_URL), GOVERNADOR, RELEASE_PROPOSAL, ENS_RESOLVER,
#   DAO_SHARE, IPFS_API, PROPOSER_PRIVATE_KEY
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CEREMONY="$ROOT/ceremony"
DIR="$ROOT/frontend"
HASTA="propuesta"
FORZAR=0
API=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)     DIR="$2"; shift 2 ;;
    --hasta)   HASTA="$2"; shift 2 ;;
    --api)     API="$2"; shift 2 ;;
    --forzar)  FORZAR=1; shift ;;
    -h|--help) sed -n '2,25p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) printf 'opción desconocida: %s\n' "$1" >&2; exit 1 ;;
  esac
done

case "$HASTA" in cid|ipfs|propuesta) ;; *) printf -- '--hasta debe ser cid, ipfs o propuesta\n' >&2; exit 1 ;; esac

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

IPFS_API="${API:-${IPFS_API:-http://127.0.0.1:5001}}"
RPC_URL="${RPC_URL:-${BASE_SEPOLIA_RPC_URL:-}}"

C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
[ -t 1 ] || { C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_OFF=""; }
paso() { printf '\n%s%s%s\n' "$C_DIM" "$*" "$C_OFF"; }
ok()   { printf '%s ok %s %s\n' "$C_OK"   "$C_OFF" "$*"; }
warn() { printf '%s !! %s %s\n' "$C_WARN" "$C_OFF" "$*"; }
die()  { printf '%s ERR%s %s\n' "$C_ERR"  "$C_OFF" "$*" >&2; exit 1; }
note() { printf '%s    %s%s\n'  "$C_DIM"  "$*" "$C_OFF"; }

cli() { ( cd "$CEREMONY" && node dist/index.js "$@" ); }
json_campo() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"; }

# digest sha256 (bytes32) de un CID base32, que es lo que guardan los contratos
digest_de_cid() {
  python3 - "$1" <<'PY'
import base64, sys
cid = sys.argv[1].strip()
if cid[0] != 'b':
    sys.exit('CID no base32: ' + cid)
body = cid[1:].upper()
body += '=' * ((8 - len(body) % 8) % 8)
raw = base64.b32decode(body)
if len(raw) < 36:
    sys.exit('CID demasiado corto')
print('0x' + raw[-32:].hex())
PY
}

cast_bin() {
  if command -v cast >/dev/null 2>&1; then command -v cast
  elif [ -x "${HOME}/.foundry/bin/cast" ]; then printf '%s\n' "${HOME}/.foundry/bin/cast"
  fi
}

# ── 1. chequeos ────────────────────────────────────────────────────────
paso "1. chequeos"
[ -d "$DIR" ] || die "no existe el directorio: $DIR"
faltan=0
for f in index.html css/style.css js/config.js js/contracts.js js/verify.js js/app.js; do
  if [ ! -f "$DIR/$f" ]; then warn "falta $DIR/$f"; faltan=1; fi
done
[ "$faltan" -eq 0 ] || die "el frontend no está completo"
ok "el frontend está completo ($DIR)"

if [ ! -f "$CEREMONY/dist/index.js" ]; then
  note "compilando el CLI de ceremonia"
  ( cd "$CEREMONY" && npm run build >/dev/null )
fi
ok "CLI de ceremonia listo"

# ── 2. CID ─────────────────────────────────────────────────────────────
paso "2. CID del directorio"
CID="$(cli cid --dir "$DIR" | json_campo cid)"
[ -n "$CID" ] || die "no pude calcular el CID"
DIGEST="$(digest_de_cid "$CID")"
ok "CID:    $CID"
note "digest: $DIGEST  (esto es lo que se guarda on-chain)"

if [ "$HASTA" = "cid" ]; then
  printf '\n'
  ok "--hasta cid: me detengo acá"
  exit 0
fi

# ── 3. comparación contra el último release ────────────────────────────
paso "3. comparación con el último release on-chain"
if [ -z "$RPC_URL" ] || [ -z "${RELEASE_PROPOSAL:-}" ]; then
  warn "sin RPC_URL o sin RELEASE_PROPOSAL en .env: no puedo comparar"
  note "copiá .env.example a .env y poné los datos del deploy"
elif ! castbin="$(cast_bin)" || [ -z "$castbin" ]; then
  warn "no encuentro cast (viene con Foundry): no puedo comparar"
else
  n="$("$castbin" call "$RELEASE_PROPOSAL" "getReleaseCount()(uint256)" --rpc-url "$RPC_URL")"
  if [ "$n" -gt 0 ]; then
    ultimo="$("$castbin" call "$RELEASE_PROPOSAL" "getReleaseCID(uint256)(bytes32)" "$((n-1))" --rpc-url "$RPC_URL")"
    if [ "${ultimo,,}" = "${DIGEST,,}" ]; then
      if [ "$FORZAR" -eq 1 ]; then
        warn "el CID es idéntico al release ya publicado; sigo por --forzar"
      else
        die "este CID ya es el release publicado: no hay nada nuevo que publicar (--forzar para seguir)"
      fi
    else
      ok "hay release nuevo (publicado: ${ultimo:0:18}...)"
    fi
  else
    ok "todavía no hay releases registrados"
  fi
fi

# ── 4. IPFS ────────────────────────────────────────────────────────────
paso "4. subida a IPFS ($IPFS_API)"
if cli ipfs --dir "$DIR" --api "$IPFS_API" --pin >/dev/null 2>&1; then
  ok "subido y pinneado"
else
  warn "no pude subir a IPFS (¿hay un nodo Kubo en $IPFS_API?)"
  note "el CID ya está calculado; podés subirlo cuando tengas nodo:"
  note "  ceremonia.sh ipfs"
fi

if [ "$HASTA" = "ipfs" ]; then
  printf '\n'
  ok "--hasta ipfs: me detengo acá"
  exit 0
fi

# ── 5. propuesta ───────────────────────────────────────────────────────
paso "5. propuesta para la DAO"
if [ -n "${RELEASE_PROPOSAL:-}" ]; then
  ACCION="$(cli submit --cid "$CID" --release-proposal "$RELEASE_PROPOSAL" \
              --resolver "${ENS_RESOLVER:-0x0000000000000000000000000000000000000000}")"
else
  [ -n "${ENS_RESOLVER:-}" ] || die "definí RELEASE_PROPOSAL o ENS_RESOLVER en .env"
  ACCION="$(cli submit --cid "$CID" --resolver "$ENS_RESOLVER")"
fi

TARGET="$(printf '%s' "$ACCION" | json_campo target)"
DATA="$(printf '%s' "$ACCION" | json_campo data)"

mkdir -p "$ROOT/releases"
MANIFIESTO="$ROOT/releases/$CID.json"
python3 - "$MANIFIESTO" "$CID" "$DIGEST" "$TARGET" "$DATA" <<'PY'
import json, sys, datetime
path, cid, digest, target, data = sys.argv[1:6]
json.dump({
    "cid": cid,
    "digest": digest,
    "fecha": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "propuesta": {"target": target, "value": "0", "data": data},
    "estado": "armada, sin enviar",
}, open(path, "w"), indent=2)
PY
ok "acción armada contra $TARGET"
ok "manifiesto guardado en releases/$CID.json"

# ── 6. resumen ─────────────────────────────────────────────────────────
paso "6. resumen"
printf 'CID:     %s\n' "$CID"
printf 'digest:  %s\n' "$DIGEST"
printf 'a llamar: %s\n' "$TARGET"
printf 'qué falta para que el release esté vivo:\n'
note "1. crear la propuesta en la DAO (usa tu llave de proponente)"
if [ -n "${GOVERNADOR:-}" ]; then
  note "   cast send $GOVERNADOR \\"
  note "     \"propose(address[],uint256[],bytes[],string)\" \\"
  note "     \"[$TARGET]\" \"[0]\" \"[$DATA]\" \"release $CID\" \\"
  note "     --rpc-url \$RPC_URL --private-key \$PROPOSER_PRIVATE_KEY"
else
  note "   (definí GOVERNADOR en .env para que te lo arme completo)"
fi
note "2. que los miembros voten (48h de votación)"
note "3. esperar el timelock de 15 días y ejecutar la propuesta"
note "el manifiesto en releases/ tiene el target y el data para esos pasos"
