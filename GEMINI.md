# Server Setup Scripts

A comprehensive suite of Bash scripts for automated deployment, management, and maintenance of web applications (Vite/React, Express) on a remote Linux server using Apache.

## Project Overview

This project provides a centralized way to manage multiple web applications on a single server. It automates the entire lifecycle of an application, from initial directory creation and dependency installation to Apache VirtualHost configuration and GitHub CI/CD integration.

### Main Technologies
- **Scripting:** Bash
- **Web Server:** Apache (with SSL/TLS via Cloudflare Origin CA)
- **Application Frameworks:** Vite, React, Express.js
- **Version Control:** Git, GitHub CLI (`gh`)
- **CI/CD:** GitHub Actions, Git `post-receive` hooks
- **Tools:** `jq` (for JSON parsing), `ssh`, `sudo`

### Architecture
- **TUI Layer:** `host-manager.sh` provides an interactive terminal interface for local users to trigger actions on the remote server.
- **Service Layer:** Individual scripts (`setup-new-*.sh`, `remove-*.sh`, `rebuild-*.sh`) handle the heavy lifting on the server.
- **Data Layer:** `setup-log.json` files within each application directory store metadata (App ID, Domain, GitHub Repo).
- **Security:** `.deploy-secrets` stores sensitive credentials for GitHub and SSH integration.

## Key Workflows

### 1. Host Management
Launch the interactive TUI to manage all instances:
```bash
./host-manager.sh
```

### 2. Setting Up a New Vite App
The `setup-new-vite-app.sh` script:
- Creates the application directory structure.
- Generates a boilerplate Vite/React app with `styled-components`.
- Configures an Apache VirtualHost with SSL (HTTP to HTTPS redirect).
- Initializes a local Git repo and a private GitHub repository.
- Sets up a `post-receive` hook for direct git-push deployment.
- Configures GitHub Actions for automated deployment on push.

### 3. Setting Up a New Express Server
The `setup-new-express-server.sh` script:
- Finds an available port for the Node.js process.
- Sets up a basic Express server.
- Configures Apache as a reverse proxy to the Express process.
- Manages process lifecycle using **PM2** and updates `ecosystem.config.js`.
- Manages process lifecycle (Start/Stop/Restart).

## Development Conventions

### Application Structure
- **Vite Apps:** Root directory contains `src/`, `public/`, and `dist/` (after build).
- **Express Servers:** Root directory contains `server.js` (or similar) and `package.json`.
- **Metadata:** Every application contains a `setup-log.json` for tracking.

### Scripting Standards
- **Sudo Usage:** Scripts use `sudo` for administrative tasks. `host-manager.sh` and setup scripts include mechanisms to keep the sudo session alive.
- **Color Coding:** 
  - `BOLD_GREEN`: Success/Positive actions
  - `BOLD_RED`: Failures/Errors
  - `BOLD_CYAN`: Reloading/Maintenance
- **Naming:** App IDs are typically hyphenated versions of the App Name (e.g., "My App" -> `my-app`).

### Deployment
- **Git Push:** Deploy directly to the server via `git push production main`.
- **GitHub Actions:** Automated deployment triggered by pushing to the `main` branch on GitHub.

## Project Structure

- `host-manager.sh`: Main entry point (TUI).
- `setup-new-*.sh`: Provisioning scripts.
- `rebuild-*.sh` / `restart-*.sh`: Maintenance scripts.
- `remove-*.sh`: Decommissioning scripts.
- `.deploy-secrets.example`: Template for required configuration.
