# Firebase Interactive Setup Tool - Planning Document

This document defines the requirements for a brand-new, interactive shell-based CLI utility designed to scaffold, view, and manage applications natively deployed to Firebase Hosting and Firebase Cloud Functions.

---

## 1. Base Requirements

- **Local Execution:** The tool runs entirely locally on macOS (no SSH commands to remote servers, no on-server git hooks).
- **Environment Prerequisites:**
  - `gh` CLI (authenticated)
  - `gcloud` CLI (authenticated)
  - `firebase` CLI (authenticated via `firebase login`)
  - `jq` (for JSON file parsing)
- **TUI (Terminal User Interface):** Interactive, arrow-key or text-prompt navigation allowing the user to select options without typing complex commands.
- **Project Structure:**
  - Sourced from a local `.deploy-secrets` containing:
    - `LOCAL_PROJECTS_DIR` (e.g. `~/Projects`)
    - `BILLING_ACCOUNT_ID` (for automating Blaze plan upgrades)
    - `CLOUDFLARE_ZONE_ID` (optional, for DNS automation)
    - `CLOUDFLARE_API_TOKEN` (optional, for DNS automation)
  - Applications will be stored in `$LOCAL_PROJECTS_DIR/<app-id>/` consisting of two subfolders:
    - `frontend/` (Vite Frontend)
    - `backend/` (Express Backend)

---

## 2. Shared Registry (Multi-Machine Sync)

To support running this tool across multiple machines, a centralized private GitHub repository called **`apps-registry`** will store the metadata.

### Synchronization Flow:
1. **Startup Check:**
   - The tool looks for a local checkout of the `apps-registry` repository inside the script directory (or `~/.config/firebase-scaffolder/registry`).
   - If it does not exist, the tool attempts to clone it using `gh repo clone <username>/apps-registry`. If the repository does not exist on GitHub, the tool creates a private `apps-registry` repository, initializes `apps-registry.json` as an empty JSON array `[]`, commits, and pushes it.
   - If the repository already exists locally, the tool runs a `git pull` to fetch the latest state.
2. **Registry Changes (Write Actions):**
   - Whenever an app is created or removed, the tool writes to the local `apps-registry.json` file.
   - The tool immediately commits and pushes the registry changes:
     ```bash
     git add apps-registry.json
     git commit -m "Update registry: <action> <app-id>"
     git push
     ```

---

## 3. Action: Create (Scaffolding)

When creating a new application, the user is prompted to enter a unique app name. The tool scaffolds a unified project folder containing both frontend and backend subfolders.

### Base Scaffolding Flow:
1. **Prompts:** 
   - App Name (Title Case)
   - App ID (Hyphenated, default generated from Name)
   - Custom Domain Name (Default generated from ID + Apex Domain)
2. **Local Code Scaffolding:**
   - **Vite React Frontend:** Scaffold with Vite, React 19, Styled Components, and prettier configuration.
   - **Express Backend:** Scaffold with functions-wrapped Express app in a `functions/` directory.
3. **Firebase Resource Provisioning:**
   - Create a single Firebase project for the app using `firebase projects:create`.
   - Link Google Cloud Billing using `gcloud billing projects link` to enable the Blaze plan.
   - Connect custom domain on Firebase Hosting.
4. **Cloudflare DNS Configuration:**
   - CNAME record pointed from the custom domain to the Firebase Hosting target (`<project-id>.web.app`).
5. **Git & GitHub Integration:**
   - Initialize separate git repositories in `frontend/` and `backend/`.
   - Create private GitHub repositories: `<app-id>-frontend` and `<app-id>-backend`.
   - Generate a GCP Service Account key and save it as a secret on both GitHub repositories.
   - Push code to GitHub, triggering deployment.
6. **Registry Logging:**
   - Update `apps-registry.json` with the new app configuration and push the changes.

---

## 4. Action: Remove (Decommissioning)

This action performs clean decommissioning of an application while keeping its code history intact on GitHub.

### Tasks to Perform:
1. **Local Cleanup:** Delete the local project folder.
2. **Firebase Cleanup:** Delete the GCP/Firebase project programmatically.
3. **DNS Cleanup:** Remove the CNAME record from Cloudflare.
4. **GitHub Retention:** Do **NOT** delete the GitHub repositories.
5. **Registry Update:** Update `apps-registry.json` status to `"removed"` and push changes.

---

## 5. Action: View (Monitoring & Diagnostics)

This action displays the current active and archived inventory.

### Tasks to Perform:
1. **Inventory Listing:** 
   - List all active local applications.
   - Pressing `Ctrl+R` displays a secondary section of "Removed" applications read from `apps-registry.json`.
2. **Redeployment Prompt:** Selecting a removed application prompts the user to restore it:
   - Clones the `<app-id>-frontend` and `<app-id>-backend` repos back to the local projects directory.
   - Re-creates the Firebase project, links billing, sets up Service Account keys, and restores Cloudflare DNS.
   - Marks the application status as `"active"` in the registry and pushes changes.
3. **Metadata Inspection:** Display repository links, custom domain URL, creation date, and status.
