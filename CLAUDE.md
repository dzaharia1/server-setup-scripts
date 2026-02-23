# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A collection of bash scripts for provisioning and managing web instances on a remote Linux server (`server.danzaharia.com`). Two instance types are actively maintained: **Vite (React) apps** and **Express servers**. Legacy React (CRA) scripts still exist but Vite is the current standard.

## Script Inventory

| Script | Where it runs | Purpose |
|---|---|---|
| `host-manager.sh` | Local machine | TUI that SSHes into the server to invoke all other scripts |
| `setup-new-vite-app.sh` | Remote server | Scaffold and deploy a new Vite/React app |
| `rebuild-vite-app.sh` | Remote server | Reinstall deps, delete `dist/`, rebuild, reload Apache |
| `remove-vite-app.sh` | Remote server | Disable Apache site, delete config and app directory |
| `setup-new-express-server.sh` | Remote server | Scaffold and deploy a new Express server |
| `restart-express-server.sh` | Remote server | Reinstall deps, optional build, pm2 restart, reload Apache |
| `remove-express-server.sh` | Remote server | pm2 delete, disable Apache site, delete config and directory |
| `setup-new-react-app.sh` | Remote server | Legacy CRA setup (prefer Vite for new projects) |
| `rebuild-react-app.sh` | Remote server | Legacy CRA rebuild |
| `remove-react-app.sh` | Remote server | Legacy CRA removal |

## Server Directory Layout

```
/home/dan/
  vite-apps/<app-id>/       # Vite apps; Apache serves dist/
  services/<service-id>/    # Express servers; Apache proxies to pm2 process
  react-apps/<app-id>/      # Legacy CRA apps; Apache serves build/
  scripts/                  # Where the setup scripts live on the server
```

## Architecture

**Vite apps** are static sites built with `npm run build` and served by Apache directly from `dist/`. Deployment happens via `git push` — a `post-receive` hook runs `npm install && npm run build` automatically.

**Express servers** are Node.js processes managed by pm2. Apache proxies requests to a dynamically assigned localhost port (starting at 3100, incremented until free). The `post-receive` hook runs `npm install && pm2 restart <service-id>`.

**SSL** is handled by Cloudflare Origin CA certificates stored at `/etc/ssl/cloudflare/danzaharia.com.{pem,key}`. Both VirtualHost blocks (80 + 443) are written to `/etc/apache2/sites-available/<domain>.conf`.

**`setup-log.json`** is created in every instance directory and stores metadata (domain, id, name, port, created date). The rebuild/remove scripts read domain from this file to know which Apache config to operate on.

**Domains:** New instances default to `<id>.adanmade.app`. The setup scripts also configure aliases for `danzaharia.com`, `imadean.app`, and `danmade.app` subdomains.

## Prettier Config (applied to all new apps)

```json
{ "bracketSameLine": true, "trailingComma": "all", "singleQuote": true }
```

## Vite App Template

- React 18 + Vite 5 + styled-components
- Entry: `src/main.jsx` → `src/App.jsx`
- Build output: `dist/`
- Config: `vite.config.js`, `.eslintrc.cjs`

## Express Server Template

- ESM (`"type": "module"`)
- Entry: `server.js`
- Dependencies: express, path, url
- Dev: nodemon

## Script Conventions

- All scripts accept CLI flags (e.g., `--app-id`, `--service-id`) or fall back to interactive prompts.
- App/service IDs are lowercase-hyphenated versions of the title-case name.
- Sudo password is prompted once and kept alive in the background via a loop.
- Each step prints `SUCCESS` (green) or `FAILED` (red) and continues regardless of failure (non-fatal pattern).
- `host-manager.sh` parses `CLONE_COMMAND:git clone ...` from setup script output to display the git remote.
