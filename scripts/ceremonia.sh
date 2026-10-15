#!/usr/bin/env bash
#
# ceremonia.sh — atajos alrededor del CLI de ceremonia (ceremony/)
#
# Uso:
#   ceremonia.sh build                 compila el CLI (npm run build)
#   ceremonia.sh cid [dir]             calcula el CID de un directorio (default: frontend)
#   ceremonia.sh verificar <cid> [dir] compara el directorio contra un CID esperado
#   ceremonia.sh ipfs [dir]            sube y pinnea en IPFS (usa IPFS_API)
#   ceremonia.sh propuesta <cid>       arma el calldata de la propuesta para la DAO
#   ceremonia.sh estado                qué dice la cadena: último release y miembros
#   ceremonia.sh ayuda
#
# Lee las variables de un archivo .env en la raíz del proyecto (si existe):
#   RPC_URL (o BASE_SEPOLIA_RPC_URL), RELEASE_PROPOSAL, ENS_RESOLVER, DAO_SHARE, IPFS_API
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CEREMONY="$ROOT/ceremony"
DIR_DEFECTO="$ROOT/frontend"

if [ -f "$ROOT/.env" ]; then
  set -a
  # shellcheck disable=SC1091
  . "$ROOT/.env"
  set +a
fi

IPFS_API="${IPFS_API:-http://127.0.0.1:5001}"
RPC_URL="${RPC_URL:-${BASE_SEPOLIA_RPC_URL:-}}"

C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
[ -t 1 ] || { C_OK=""; C_ERR=""; C_DIM=""; C_OFF=""; }
ok()   { printf '%s ok %s %s\n' "$C_OK"  "$C_OFF" "$*"; }
die()  { printf '%s ERR%s %s\n' "$C_ERR" "$C_OFF" "$*" >&2; exit 1; }
note() { printf '%s    %s%s\n'  "$C_DIM" "$*" "$C_OFF"; }

# ── helpers ────────────────────────────────────────────────────────────
compilar_si_hace_falta() {
  if [ ! -f "$CEREMONY/dist/index.js" ]; then
    note "compilando el CLI de ceremonia"
    ( cd "$CEREMONY" && npm run build >/dev/null )
  fi
}

cli() { ( cd "$CEREMONY" && node dist/index.js "$@" ); }

json_campo() { python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"; }

necesita_cast() {
  command -v cast >/dev/null 2>&1 && return 0
  [ -x "${HOME}/.foundry/bin/cast" ] && return 0
  die "no encuentro cast (viene con Foundry): hace falta para leer la cadena"
}

cast_bin() {
  command -v cast >/dev/null 2>&1 && command -v cast || printf '%s\n' "${HOME}/.foundry/bin/cast"
}

necesita_rpc() {
  [ -n "${RPC_URL:-}" ] || die "definí RPC_URL en .env (o pasala como variable de entorno)"
  necesita_cast
}

# ── comandos ───────────────────────────────────────────────────────────
cmd_build() {
  ( cd "$CEREMONY" && npm run build )
  ok "CLI de ceremonia compilado"
}

cmd_cid() {
  local dir="${1:-$DIR_DEFECTO}"
  [ -d "$dir" ] || die "no existe el directorio: $dir"
  compilar_si_hace_falta
  cli cid --dir "$dir"
}

cmd_verificar() {
  local cid="${1:-}" dir="${2:-$DIR_DEFECTO}"
  [ -n "$cid" ] || die "falta el CID. Uso: ceremonia.sh verificar <cid> [dir]"
  compilar_si_hace_falta
  if cli verify --dir "$dir" --expected-cid "$cid" >/dev/null 2>&1; then
    ok "el directorio $dir produce ese CID"
  else
    die "el directorio $dir NO produce ese CID"
  fi
}

cmd_ipfs() {
  local dir="${1:-$DIR_DEFECTO}"
  compilar_si_hace_falta
  cli ipfs --dir "$dir" --api "$IPFS_API" --pin
}

cmd_propuesta() {
  local cid="${1:-}"
  [ -n "$cid" ] || die "falta el CID. Uso: ceremonia.sh propuesta <cid>"
  compilar_si_hace_falta
  if [ -n "${ENS_RESOLVER:-}${RELEASE_PROPOSAL:-}" ]; then
    :
  else
    die "definí RELEASE_PROPOSAL o ENS_RESOLVER en .env (las direcciones del deploy)"
  fi
  if [ -n "${RELEASE_PROPOSAL:-}" ]; then
    cli submit --cid "$cid" --release-proposal "$RELEASE_PROPOSAL" \
      --resolver "${ENS_RESOLVER:-0x0000000000000000000000000000000000000000}"
  else
    cli submit --cid "$cid" --resolver "$ENS_RESOLVER"
  fi
}

cmd_estado() {
  necesita_rpc
  local castbin; castbin="$(cast_bin)"
  local rpc=(--rpc-url "$RPC_URL")

  if [ -n "${RELEASE_PROPOSAL:-}" ]; then
    local n
    n="$("$castbin" call "$RELEASE_PROPOSAL" "getReleaseCount()(uint256)" "${rpc[@]}")"
    printf 'releases registrados: %s\n' "$n"
    if [ "$n" -gt 0 ]; then
      printf 'último CID (bytes32): %s\n' \
        "$("$castbin" call "$RELEASE_PROPOSAL" "getReleaseCID(uint256)(bytes32)" "$((n-1))" "${rpc[@]}")"
    fi
  else
    note "sin RELEASE_PROPOSAL en .env: salteo el último release"
  fi

  if [ -n "${DAO_SHARE:-}" ]; then
    local supply
    supply="$("$castbin" call "$DAO_SHARE" "totalSupply()(uint256)" "${rpc[@]}")"
    printf 'miembros: %s\n' "$(python3 -c "print($supply // 10**18)")"
  else
    note "sin DAO_SHARE en .env: salteo los miembros"
  fi
}

uso() {
  awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "${BASH_SOURCE[0]}"
}

case "${1:-}" in
  build)                 shift; cmd_build ;;
  cid)                   shift; cmd_cid "${1:-}" ;;
  verificar)             shift; cmd_verificar "${1:-}" "${2:-}" ;;
  ipfs)                  shift; cmd_ipfs "${1:-}" ;;
  propuesta|propuesta-dao) shift; cmd_propuesta "${1:-}" ;;
  estado)                shift; cmd_estado ;;
  ""|-h|--help|ayuda)    uso ;;
  *) die "comando desconocido: $1 (probá: ceremonia.sh ayuda)" ;;
esac
