# Qué editar después de generar el proyecto

El scaffold ya deja todo compilando y con los tests en verde. Lo que sigue es
lo específico de tu proyecto.

## 1. Identidad

- `frontend/index.html` — `<title>` y el `<h1>`.
- `frontend/css/style.css` — los colores y la tipografía.
- `contracts/src/dao/GovernorDAO.sol` — el nombre y el símbolo del token
  (`ERC20("{{NOMBRE}} DAO", "{{SIMBOLO}}")`).
- `package.json` / `contracts/package.json` / `ceremony/package.json` — los
  nombres de paquete.

## 2. Red y RPC

- `contracts/foundry.toml` — `[rpc_endpoints]` y `[etherscan]`.
- `frontend/js/config.js` — `DEFAULT_CHAIN_ID` y `DEFAULT_CHAIN_NAME`.

Hoy apunta a Base Sepolia (84532). Si cambiás de red, acordate de los bloques:
`votingPeriod` está en bloques de 2 segundos.

## 3. Después del primer deploy

En `frontend/js/config.js`:

- `EXPECTED_CID` — el CID que devuelve la ceremonia (`ceremony cid --dir frontend`)
- `CONTRACTS.releaseProposal`, `CONTRACTS.daoShare`, `CONTRACTS.ensResolver`

Mientras estén vacíos, el badge del frontend va a decir que el deployment no
pasó por la ceremonia. Es lo esperado antes del primer release.

## 4. Dominio

- `frontend/js/config.js` — `ENS_DOMAIN` (ahora `{{DOMINIO}}`)
- Registrá el nombre, y pasá la propiedad al `TimelockController` que despliega
  `contracts/script/Deploy.s.sol`.
- Ojo: `ENSResolver` guarda el contenthash como `bytes32` crudo, no en el
  formato EIP-1577. Para que un navegador ENS-aware o un gateway lo resuelvan
  hay que convertirlo (ver `openspec/specs/ens-timelock-control`).

## 5. Miembros iniciales

`Deploy.s.sol` lee `INITIAL_MEMBERS` (direcciones separadas por coma). Cada
miembro recibe 1 share (1e18) y tiene que delegar en sí mismo para activar su
voto. Sin delegación, el peso de voto es 0 y no puede proponer.

## 6. Tooling del template

Para traer mejoras del template (CI, este doc, el propio script):

```bash
scripts/nuevo-proyecto.sh update . --dry-run    # ver qué cambiaría
scripts/nuevo-proyecto.sh update .
scripts/nuevo-proyecto.sh doctor .              # estado de dependencias
```

`update` sólo toca los archivos listados en `template/MANIFEST`: nunca
`src/`, tests, `package.json` ni dependencias.

## 7. La ceremonia

Los atajos están en scripts/ceremonia.sh:

```bash
scripts/ceremonia.sh build              # compila el CLI
scripts/ceremonia.sh cid                # CID del frontend
scripts/ceremonia.sh verificar bafy...  # ¿el frontend produce ese CID?
scripts/ceremonia.sh ipfs               # sube y pinnea en IPFS
scripts/ceremonia.sh propuesta bafy...  # calldata de la propuesta para la DAO
scripts/ceremonia.sh estado             # qué dice la cadena
```

Y para publicar un release completo (hasta armar la propuesta):

```bash
cp .env.example .env      # completá con los datos del deploy
scripts/publicar.sh --hasta cid     # sólo calcular el CID
scripts/publicar.sh                 # flujo completo
```

publicar.sh calcula el CID, lo compara con el release publicado, sube a IPFS,
arma la propuesta y deja un manifiesto en releases/. Todavía no manda la
transacción de la propuesta: al final imprime los comandos exactos para ese
paso y para votar.

