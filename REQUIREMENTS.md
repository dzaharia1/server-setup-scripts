# Server Setup Requirements

Requirements to provision a new Linux server (e.g. DreamCompute) to run these scripts.

---

## System Packages

Install via `apt`:

```bash
sudo apt update
sudo apt install -y apache2 git nodejs npm jq net-tools
```

| Package | Purpose |
|---|---|
| `apache2` | Web server for serving Vite apps and proxying Express servers |
| `git` | Version control; post-receive hooks drive auto-deployment |
| `nodejs` + `npm` | Runtime and package manager for all apps |
| `jq` | Parses `setup-log.json` in rebuild/remove scripts |
| `net-tools` | Provides `netstat`, used to find free ports for Express servers |

## Apache Modules

Enable these after installing Apache:

```bash
sudo a2enmod ssl proxy proxy_http rewrite
sudo systemctl restart apache2
```

## Node.js Global Packages

```bash
sudo npm install -g pm2
```

`pm2` manages Express server processes and survives reboots (`pm2 startup` + `pm2 save`).

## GitHub CLI (`gh`)

Install and authenticate the `gh` CLI — the setup scripts use it to create repos and set Actions secrets:

```bash
# Install (Debian/Ubuntu)
type -p curl >/dev/null || sudo apt install curl -y
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list
sudo apt update && sudo apt install gh -y

# Authenticate
gh auth login
```

## SSL Certificates

The scripts expect Cloudflare Origin CA certificates at:

```
/etc/ssl/cloudflare/<your-domain>.pem
/etc/ssl/cloudflare/<your-domain>.key
```

Generate them in the Cloudflare dashboard (SSL/TLS → Origin Server) and place them at those paths. Create the directory first:

```bash
sudo mkdir -p /etc/ssl/cloudflare
```

## Deploy Secrets File

Copy `.deploy-secrets.example` to `.deploy-secrets` (in the same directory as the scripts) and fill in the values:

```bash
cp .deploy-secrets.example .deploy-secrets
```

| Variable | Description |
|---|---|
| `DEPLOY_HOST` | Public hostname or IP of the server |
| `DEPLOY_USER` | SSH username on the server |
| `DEPLOY_SSH_KEY_PATH` | Path to the SSH private key GitHub Actions will use to push to the server |

## SSH Key for GitHub Actions

Generate a dedicated deploy key on the server and add the public key to `~/.ssh/authorized_keys`:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""
cat ~/.ssh/deploy_key.pub >> ~/.ssh/authorized_keys
```

Store the **private key** path in `.deploy-secrets` as `DEPLOY_SSH_KEY_PATH`. The setup scripts will automatically add the private key as a GitHub Actions secret (`DEPLOY_SSH_KEY`) on each new repo they create.

## Directory Structure

Create the expected home directories:

```bash
mkdir -p ~/vite-apps ~/services ~/react-apps ~/scripts
```

Copy the scripts into `~/scripts/` so they're accessible on the server when `host-manager.sh` SSHes in.

## DNS

Point your domains at the server's IP address. Each new app/service defaults to `<id>.adanmade.app` but the setup scripts also write aliases for whatever domains you configure. You'll need A records (or CNAMEs pointing to the server) for any domains you plan to use.

---

## Checklist

- [ ] `apache2` installed and running, with `ssl`, `proxy`, `proxy_http`, `rewrite` modules enabled
- [ ] `nodejs` and `npm` installed
- [ ] `pm2` installed globally
- [ ] `gh` CLI installed and authenticated
- [ ] `jq` and `net-tools` installed
- [ ] Cloudflare Origin CA cert + key placed in `/etc/ssl/cloudflare/`
- [ ] `.deploy-secrets` file populated
- [ ] Deploy SSH key generated and `authorized_keys` updated
- [ ] `~/vite-apps`, `~/services`, `~/react-apps`, `~/scripts` directories created
- [ ] Scripts copied to `~/scripts/` on the server
- [ ] DNS records pointing to the server
