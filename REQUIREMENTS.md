# Server Installation Guide

Full step-by-step guide to provisioning a fresh Linux server (e.g. DreamCompute/Ubuntu) to run these scripts.

---

## Overview

The setup works in two parts:

- **Remote server** — runs Apache, Node.js, pm2, `gh` CLI, and the setup scripts themselves
- **Local machine** — runs `host-manager.sh`, which SSHes into the server and invokes the setup scripts interactively

Work through the sections below **on the server** (via SSH) unless noted otherwise.

---

## 0. Note on Hardcoded Values

Before you start, be aware that these scripts have some values hardcoded that you'll need to match or change:

| Variable | Hardcoded value | Where to change it |
|---|---|---|
| Server username | `dan` | All scripts, `USER="dan"` near the top |
| Admin email | `zaharia.danny@gmail.com` | All setup scripts, `ADMIN_CONTACT=` near the top |
| SSL cert domain | `danzaharia.com` | All setup scripts, `SSLCertificateFile` lines |
| Default app domains | `adanmade.app`, `danmade.app`, etc. | All setup scripts, `DZ_DOMAIN`, `IM_DOMAIN`, etc. |
| Ecosystem config path | `/home/dan/ecosystem.config.js` | `setup-new-express-server.sh` line ~248 |

**Easiest path:** create a user named `dan` on the new server. Then the only things that need changing are the email, SSL cert domain, and default domain names.

---

## 1. Create the Server User

If you're setting up with a different username and want to avoid editing scripts, create a `dan` user:

```bash
sudo adduser dan
sudo usermod -aG sudo dan
```

Then log in as that user for all remaining steps:

```bash
su - dan
```

---

## 2. System Package Updates

```bash
sudo apt update && sudo apt upgrade -y
```

---

## 3. Node.js and npm

The default `apt` version of Node.js is usually too old (Vite 5 requires Node 18+). Install via NodeSource:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs
```

Verify:

```bash
node --version   # should be v20.x.x
npm --version
```

---

## 4. Apache

### Install

```bash
sudo apt install -y apache2
```

### Enable required modules

```bash
sudo a2enmod ssl proxy proxy_http rewrite
sudo systemctl restart apache2
```

Verify Apache is running:

```bash
sudo systemctl status apache2
```

### Open firewall ports (if applicable)

```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

---

## 5. pm2

pm2 manages the Express server processes:

```bash
sudo npm install -g pm2
```

### Configure pm2 to start on boot

```bash
pm2 startup
```

This prints a command — run it (it looks like `sudo env PATH=... pm2 startup systemd -u dan --hp /home/dan`). Copy and run the exact command it outputs.

After you set up your first Express service, run:

```bash
pm2 save
```

This freezes the current process list so it's restored on reboot.

---

## 6. Supporting Utilities

```bash
sudo apt install -y git jq net-tools
```

| Package | Why it's needed |
|---|---|
| `git` | Version control and post-receive deploy hooks |
| `jq` | The rebuild/remove scripts parse `setup-log.json` with it |
| `net-tools` | Provides `netstat`, used to find free ports for Express servers |

---

## 7. GitHub CLI (`gh`)

The setup scripts use `gh` to create private GitHub repos and set Actions secrets automatically.

### Install

```bash
sudo apt install -y curl
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list

sudo apt update && sudo apt install -y gh
```

### Authenticate

```bash
gh auth login
```

Select **GitHub.com** → **SSH** → follow the prompts. When done, verify:

```bash
gh api user --jq .login
```

This should print your GitHub username. If it doesn't, the setup scripts will refuse to run.

### Add SSH key to GitHub for git push

The `gh auth login` flow can add your SSH key to GitHub for you. If it didn't, do it manually:

```bash
# Generate a key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

# Add it to GitHub
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)"
```

Test the connection:

```bash
ssh -T git@github.com
```

---

## 8. Deploy SSH Key (for GitHub Actions)

GitHub Actions needs a key to push code to the server. This is separate from your personal key above.

### Generate the key

```bash
ssh-keygen -t ed25519 -f ~/.ssh/deploy_key -N ""
```

### Authorize it on the server

```bash
cat ~/.ssh/deploy_key.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Verify the key path

The private key will be at `~/.ssh/deploy_key`. Note this path — you'll need it in the next step.

---

## 9. Deploy Secrets File

The setup scripts source a `.deploy-secrets` file for GitHub Actions configuration. Copy the example and fill it in:

```bash
# From inside the scripts directory on the server
cp .deploy-secrets.example .deploy-secrets
nano .deploy-secrets
```

Fill in:

```bash
DEPLOY_HOST="your.server.hostname.or.ip"
DEPLOY_USER="dan"
DEPLOY_SSH_KEY_PATH="/home/dan/.ssh/deploy_key"
```

- `DEPLOY_HOST` — the public hostname or IP address of this server
- `DEPLOY_USER` — the username the GitHub Actions runner will SSH in as (same user running the scripts)
- `DEPLOY_SSH_KEY_PATH` — the full path to the deploy private key from step 8

---

## 10. SSL Certificates

The Apache VirtualHost configs reference Cloudflare Origin CA certificates. These are not Let's Encrypt — you generate them in the Cloudflare dashboard.

### Generate the certificate

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com)
2. Select your domain
3. Go to **SSL/TLS → Origin Server**
4. Click **Create Certificate**
5. Choose RSA or ECDSA, leave the default hostnames (`*.yourdomain.com`, `yourdomain.com`), set expiry to 15 years
6. Click **Create**
7. Copy the **Certificate** (`.pem`) and **Private Key** (`.key`) contents

### Install on the server

```bash
sudo mkdir -p /etc/ssl/cloudflare
sudo nano /etc/ssl/cloudflare/yourdomain.com.pem   # paste certificate
sudo nano /etc/ssl/cloudflare/yourdomain.com.key   # paste private key
sudo chmod 600 /etc/ssl/cloudflare/yourdomain.com.key
```

### Update the scripts to use your cert path

In each setup script (`setup-new-vite-app.sh`, `setup-new-express-server.sh`, `setup-new-react-app.sh`), find the two lines:

```
SSLCertificateFile /etc/ssl/cloudflare/danzaharia.com.pem
SSLCertificateKeyFile /etc/ssl/cloudflare/danzaharia.com.key
```

Change `danzaharia.com` to your domain.

---

## 11. DNS

Point your domains at the server's IP. For each app/service you'll create, the setup scripts generate an Apache VirtualHost using the domain you specify at setup time.

At minimum, create a wildcard A record:

```
*.yourdomain.com  →  <server IP>
yourdomain.com    →  <server IP>
```

If you're using Cloudflare (recommended with the Origin CA cert above), set the proxy status to **Proxied** for SSL termination at the edge.

---

## 12. Directory Structure

Create the working directories the scripts expect:

```bash
mkdir -p ~/vite-apps ~/services ~/react-apps ~/scripts
```

---

## 13. Deploy the Scripts to the Server

The scripts need to live at `~/scripts/` on the server so `host-manager.sh` can invoke them over SSH.

**From your local machine**, clone the repo and copy the scripts:

```bash
git clone git@github.com:youruser/server-setup-scripts.git
scp server-setup-scripts/*.sh dan@your.server.ip:~/scripts/
scp server-setup-scripts/.deploy-secrets.example dan@your.server.ip:~/scripts/
```

Or clone directly on the server:

```bash
# On the server
cd ~/scripts
git clone git@github.com:youruser/server-setup-scripts.git .
```

Make the scripts executable:

```bash
chmod +x ~/scripts/*.sh
```

Then fill in `.deploy-secrets` as described in step 9.

---

## 14. Update Hardcoded Script Variables

Edit these values in each relevant script to match your setup:

### All setup scripts (`setup-new-vite-app.sh`, `setup-new-express-server.sh`, `setup-new-react-app.sh`)

```bash
USER="dan"                          # ← your server username
ADMIN_CONTACT="you@youremail.com"   # ← your email (shown in Apache config)
DZ_DOMAIN="yourdomain.com"          # ← your primary domain (or remove/replace)
IM_DOMAIN="yourotherdomain.app"     # ← additional domain aliases (or remove)
DM_DOMAIN="anotherdomain.app"       # ← additional domain aliases (or remove)
ADM_DOMAIN="default.yourdomain.app" # ← default domain for new apps
```

### `host-manager.sh` (runs locally)

```bash
USER="dan"                    # ← your server username
SERVER="your.server.hostname" # ← your server's hostname or IP
```

---

## 15. Local Machine Setup

`host-manager.sh` runs on your **local machine**, not the server. It SSHes into the server and calls the other scripts.

### Prerequisites on local machine

- `ssh` (standard on macOS/Linux)
- `bash` (standard on macOS/Linux; on Windows use WSL)
- SSH access to the server as the configured user

### Configure SSH access

Make sure you can SSH into the server without a password:

```bash
ssh-copy-id dan@your.server.hostname
```

Test it:

```bash
ssh dan@your.server.hostname echo "connected"
```

### Run the host manager

```bash
bash /path/to/host-manager.sh
```

---

## 16. Verification

Run through this checklist to confirm everything is working before using the scripts:

```bash
# On the server:

# Node.js v18+
node --version

# npm available
npm --version

# pm2 installed globally
pm2 --version

# gh CLI installed and authenticated
gh api user --jq .login

# git installed
git --version

# jq installed
jq --version

# netstat available
netstat --version

# Apache running with required modules
sudo apache2ctl -M | grep -E 'ssl|proxy|rewrite'
sudo systemctl status apache2

# SSL cert files exist and are readable
ls -la /etc/ssl/cloudflare/

# Deploy key exists
ls -la ~/.ssh/deploy_key ~/.ssh/deploy_key.pub

# Deploy secrets file populated
cat ~/scripts/.deploy-secrets

# Working directories exist
ls ~/vite-apps ~/services ~/scripts

# Scripts are executable
ls -la ~/scripts/*.sh
```

---

## Summary Checklist

- [ ] User `dan` (or matching username) exists with sudo privileges
- [ ] System packages updated
- [ ] Node.js 20.x installed via NodeSource
- [ ] Apache installed with `ssl`, `proxy`, `proxy_http`, `rewrite` modules enabled
- [ ] Firewall allows ports 80 and 443
- [ ] `pm2` installed globally and configured to start on boot
- [ ] `git`, `jq`, `net-tools` installed
- [ ] `gh` CLI installed and authenticated (`gh api user --jq .login` works)
- [ ] SSH key added to GitHub (`ssh -T git@github.com` succeeds)
- [ ] Deploy SSH key generated at `~/.ssh/deploy_key`, public key in `authorized_keys`
- [ ] `.deploy-secrets` file populated with host, user, and key path
- [ ] Cloudflare Origin CA cert + key installed in `/etc/ssl/cloudflare/`
- [ ] SSL cert paths updated in setup scripts
- [ ] DNS records pointing to the server
- [ ] `~/vite-apps`, `~/services`, `~/react-apps`, `~/scripts` directories created
- [ ] Scripts copied to `~/scripts/` and made executable
- [ ] Hardcoded `USER`, `ADMIN_CONTACT`, and domain variables updated in all scripts
- [ ] `host-manager.sh` on local machine updated with correct `SERVER` hostname
- [ ] SSH from local machine to server works without password prompt
