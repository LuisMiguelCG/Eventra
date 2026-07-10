# AGENTS.md

Guía para agentes que trabajen en este repositorio.

## Visión general

**Eventra** es un monorepo (**npm workspaces**) con dos paquetes:

- **`packages/foundry`** — Contrato inteligente `EventraContract` (ERC-721 + Ownable) y sus tests, gestionado con **Foundry/Forge**.
- **`packages/nextjs`** — Frontend en **Next.js (App Router)** que es cliente directo de ese contrato: alta de usuarios/empresas, creación de eventos, compra/reventa/transferencia de entradas y retirada de fondos.

> Nota: el frontend **sí interactúa con la blockchain**. No hay backend ni base de datos: las lecturas van directas al nodo con `ethers.JsonRpcProvider` y las escrituras se firman con la wallet del usuario (MetaMask) vía `ethers.BrowserProvider`. No se usa wagmi/RainbowKit; toda la integración es `ethers.js` v6 a mano (ver `utils/eventra/contract.ts`). El único uso de `localStorage` es cachear el rol detectado (`user`/`company`) y la preferencia de "desconectado" de la wallet — no es la fuente de verdad de nada.

## Comandos (desde la raíz)

```bash
npm install             # Instalar dependencias de ambos paquetes (npm workspaces)

# Contrato (Foundry)
npm run compile         # forge compile
npm test                # forge test
npm run chain           # Levantar anvil (cadena local)
npm run deploy          # Desplegar EventraContract (script/Deploy.s.sol)

# Frontend (Next.js)
npm start               # next dev -> http://localhost:3000
npm run next:build      # Build de producción
npm run next:check-types # tsc --noEmit

# Calidad
npm run lint            # Lint de ambos paquetes
npm run format          # Format de ambos paquetes
```

> Los scripts de la raíz delegan en los paquetes con `npm run <script> -w @eventra/<paquete>`.

## Smart contract (`packages/foundry`)

- Contratos: `packages/foundry/contracts/` (contrato principal: `EventraContract.sol`, ERC-721 "Eventra Tickets" + `Ownable`).
- Tests: `packages/foundry/test/EventraContract.t.sol` (94 tests).
- Config: `packages/foundry/foundry.toml`; librerías en `lib/` (forge-std, OpenZeppelin).
- Deploy: `packages/foundry/script/Deploy.s.sol` despliega `EventraContract` (owner y comisión de la plataforma se pasan como argumentos del constructor). `npm run deploy` invoca `scripts-js/parseArgs.js`, que a su vez usa las cuentas gestionadas por Foundry (`npm run account` / `account:generate` / `account:import`); para un deploy rápido en Anvil también sirve invocar `forge script` directamente con la private key de una cuenta de prueba.
- Variables de entorno de despliegue: `packages/foundry/.env.example` (copiar a `.env`; `npm install` ya lo hace vía `postinstall`). Incluye `ALCHEMY_API_KEY`, `ETHERSCAN_API_KEY`, `LOCALHOST_KEYSTORE_ACCOUNT`.
- Reglas de negocio clave a tener en cuenta al tocar el contrato: depósito de `1 ether` para crear un evento, royalty de reventa acotado a 10–25%, ventana de cancelación con devolución de depósito (`startSellDate - 1 día`), y `withdrawCompanyFunds` solo disponible `eventDate + 1 día` después del evento.

## Frontend (`packages/nextjs`)

- Páginas (App Router) en `app/`: `page.tsx` (home, listado de eventos), `register/` (alta de usuario/empresa), `events/create/`, `events/mine/` (eventos de una empresa), `tickets/` (entradas del usuario), `resell/` (mercado de reventa), `funds/` (fondos retirables: owner, empresa o usuario según el rol detectado). No existe ruta `login/`: conectar la wallet y registrarse son el mismo flujo (`register/` o el modal en `Header.tsx`).
- Conexión a la wallet: `hooks/eventra/useWallet.ts` (conecta/desconecta MetaMask, expone `address`).
- Contrato: `utils/eventra/contract.ts` — `getReadContract()` (provider de solo lectura por `NEXT_PUBLIC_RPC_URL`), `getWriteContract(signer)`, y `parseContractError()` (traduce los `revert` de Solidity a mensajes en español). ABI y dirección en `contracts/eventra.ts`, leídos desde variables de entorno: `NEXT_PUBLIC_EVENTRA_ADDRESS`, `NEXT_PUBLIC_RPC_URL`, `NEXT_PUBLIC_CHAIN_ID` (definidas en `packages/nextjs/.env.local`, no versionado).
- Navegación y rol: `components/Header.tsx` detecta si la wallet conectada es `company`, `user` u owner del contrato (`contract.owner()`) y ajusta el menú y el modal de alta de cuenta en consecuencia.
- `utils/eventra/events.ts` es un tipo/helper de una implementación anterior basada en `localStorage`; no se importa desde ninguna página actualmente — no asumir que sigue en uso sin comprobarlo primero.
- Estilos: **Tailwind CSS v4** (sin DaisyUI). Estilos globales en `styles/globals.css`.
- Alias de import: usar `~~/` (configurado en `tsconfig.json`), p. ej. `import { getReadContract } from "~~/utils/eventra/contract"`.

## Convenciones

- TypeScript: preferir `type` sobre `interface`; evitar tipados explícitos cuando se pueden inferir.
- Páginas Next como `const X: NextPage = () => { ... }` con `export default`.
- Comentarios solo cuando aporten información.
