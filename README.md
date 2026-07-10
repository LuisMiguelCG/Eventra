# Eventra

Monorepo (npm workspaces) con dos partes independientes

- **`packages/foundry`** — Contrato inteligente (`EventraContract`) y sus tests, con **Foundry / Forge**.
- **`packages/nextjs`** — Frontend **Next.js (App Router)** con **login / register** y **creación de eventos**.

> El frontend funciona solo con `localStorage` (autenticación y eventos en el navegador). No interactúa con la blockchain ni incluye librerías Web3.

## Requisitos

- Node.js >= 20.18.3 (incluye npm)
- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `anvil`) para el contrato

## Instalación

```bash
npm install
```

## Contrato (Foundry)

```bash
npm run compile     # Compilar
npm test            # Ejecutar los tests (forge test)
npm run chain       # Levantar una cadena local (anvil)
```

> Para desplegar (`npm run deploy`) hay que crear primero un script `packages/foundry/script/Deploy.s.sol` que despliegue `EventraContract`.

## Frontend (Next.js)

```bash
npm start            # Servidor de desarrollo en http://localhost:3000
npm run next:build   # Build de producción
```

Rutas principales: `/` (home), `/login`, `/register`, `/events/create`.

## Calidad

```bash
npm run lint      # Lint de ambos paquetes
npm run format    # Format de ambos paquetes
```

## Estructura

```
packages/
  foundry/   contratos Solidity + tests (Forge)
  nextjs/    app Next.js (auth + eventos, localStorage)
```
