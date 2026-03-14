#!/bin/bash

# Set up variables
SERVER="server.danzaharia.com"
USER="dan"
ADMIN_CONTACT="zaharia.danny@gmail.com"
SERVICES_DIRECTORY="/home/$USER/services"
DZ_DOMAIN="danzaharia.com"
IM_DOMAIN="imadean.app"
DM_DOMAIN="danmade.app"
ADM_DOMAIN="adanmade.app"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Source deploy secrets for GitHub integration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_SECRETS_FILE="$SCRIPT_DIR/.deploy-secrets"
if [ -f "$DEPLOY_SECRETS_FILE" ]; then
    source "$DEPLOY_SECRETS_FILE"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot find deploy secrets at $DEPLOY_SECRETS_FILE"
    echo "Copy .deploy-secrets.example to .deploy-secrets and fill in values."
    exit 1
fi

# Validate gh CLI and get GitHub username
if ! command -v gh &>/dev/null; then
    echo -e "${BOLD_RED}FAILED${END_COLOR} gh CLI not found. Install with: https://cli.github.com"
    exit 1
fi
GITHUB_USER=$(gh api user --jq .login 2>/dev/null)
if [ -z "$GITHUB_USER" ]; then
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot get GitHub username. Is 'gh' authenticated?"
    exit 1
fi

# Function to convert service name to hyphenated service ID
generate_service_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Prompt for the service name and generate the default app ID
read -p "Service Name (Title Case): " SERVICE_NAME
DEFAULT_SERVICE_ID=$(generate_service_id "$SERVICE_NAME")

# Prompt for the service ID with the default value
read -p "Service ID (Default: "${DEFAULT_SERVICE_ID}"): " SERVICE_ID
SERVICE_ID=${SERVICE_ID:-$DEFAULT_SERVICE_ID}
GITHUB_REPO="$GITHUB_USER/$SERVICE_ID"

# Prompt for the domain name with the default value
DZ_DOMAIN_NAME="$SERVICE_ID.$DZ_DOMAIN"
IM_DOMAIN_NAME="$SERVICE_ID.$IM_DOMAIN"
DM_DOMAIN_NAME="$SERVICE_ID.$DM_DOMAIN"
ADM_DOMAIN_NAME="$SERVICE_ID.$ADM_DOMAIN"


read -p "URL (Default: "${ADM_DOMAIN_NAME}"): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-$DM_DOMAIN_NAME}

echo " "

# Display the collected information
echo "Service Name: $SERVICE_NAME"
echo "Service ID: $SERVICE_ID"
echo "DZ Domain: https://$DZ_DOMAIN_NAME"
echo "IM Domain: https://$IM_DOMAIN_NAME"
echo "DM Domain: https://$DM_DOMAIN_NAME"
echo "ADM Domain: https://$ADM_DOMAIN_NAME"
echo "GitHub Repo: github.com/$GITHUB_REPO"

echo " "

# Find an available port
find_available_port() {
    local port=3100  # Start with a default port
    while netstat -tna | grep -q :$port; do
        port=$((port+1))
    done
    echo $port
}

PORT=$(find_available_port)
echo "Host: localhost:$PORT"

echo " "

# Prompt for sudo password
read -s -p "Enter sudo password: " SUDO_PASSWORD
echo

# Function to keep sudo session alive
keep_sudo_alive() {
    while true; do
        echo "$SUDO_PASSWORD" | sudo -S -v > /dev/null 2>&1
        sleep 60
    done
}

echo " "

# Initial check to see if the provided password is correct
if ! echo "$SUDO_PASSWORD" | sudo -kS echo > /dev/null 2>&1; then
    echo -e "${BOLD_RED}FAILED${END_COLOR} Password incorrect"
    echo " "
    exit 1
fi

# Start the keep-alive function in the background
keep_sudo_alive &
SUDO_KEEP_ALIVE_PID=$!

# Make sure to kill the keep-alive process on exit
trap 'kill $SUDO_KEEP_ALIVE_PID' EXIT

echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Password correct"

# Create root directory for service
if echo "$SUDO_PASSWORD" | sudo -S mkdir -p "$SERVICES_DIRECTORY/$SERVICE_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $SERVICES_DIRECTORY/$SERVICE_ID"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $SERVICES_DIRECTORY/$SERVICE_ID"
fi

# Change permissions for services directory to specified user
if echo "$SUDO_PASSWORD" | sudo -S chown -R "$USER" "$SERVICES_DIRECTORY/$SERVICE_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to $USER"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to $USER"
fi

#create a .prettierrc file
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/.prettierrc
if echo "{
  "bracketSameLine": true,
  "trailingComma": "all",
  "singleQuote": true
}
" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.prettierrc > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created .prettierrc file at $SERVICES_DIRECTORY/$SERVICE_ID/.prettierrc"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create .prettierrc file at $SERVICES_DIRECTORY/$SERVICE_ID/.prettierrc"
fi

# Create a setup-log.json
sudo touch "$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json"
if echo "{
  \"service_id\": \"$SERVICE_ID\",
  \"service_name\": \"$SERVICE_NAME\",
  \"domain\": \"https://$DOMAIN_NAME\",
  \"github_repo\": \"github.com/$GITHUB_REPO\",
  \"host\": \"localhost\",
  \"port\": \"$PORT\",
  \"author\": \"$USER\",
  \"created_on\": \"$(date)\"
}" | sudo tee "$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created setup-log.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create setup-log.json file"
fi

# Create a basic server
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/server.js
if echo "import express from 'express';

const app = express();
const port = $PORT;

app.get('/', (req, res) => {
  res.send('$SERVICE_NAME');
});

app.listen(port, () => {
  console.log(\`Server is running at http://localhost:\${port}\`);
});
" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/server.js > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic server file"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic server file"
fi

# Create a basic README.md
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/README.md
if echo "# $SERVICE_NAME

Identifier: $SERVICE_ID

Created: $(date)" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/README.md > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic README.md file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic README.md file"
fi

# Create basic package.json file
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/package.json
sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/package.json > /dev/null <<EOF
{
  "name": "$SERVICE_ID",
  "version": "1.0.0",
  "description": "",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "start": "node $SERVICES_DIRECTORY/$SERVICE_ID/server.js",
    "dev": "nodemon server.js",
    "deploy": "git push origin main && sleep 6 && gh run watch \$(gh run list --limit 1 --json databaseId --jq '.[0].databaseId')"
  },
  "author": "",
  "license": "ISC",
  "dependencies": {
    "express": "^5.0.1",
    "path": "^0.12.7",
    "url": "^0.11.4"
  }
}
EOF

if [ $? -eq 0 ]; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic package.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic package.json file"
fi

# Install node modules
if cd $SERVICES_DIRECTORY/$SERVICE_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Start node process
if cd "$SERVICES_DIRECTORY/$SERVICE_ID"; then
    if pm2 start --name "$SERVICE_ID" server.js; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Started node process with pm2 under name $SERVICE_ID"
        pm2 save
    else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot start node process with pm2"
    fi
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change directory to $SERVICES_DIRECTORY/$SERVICE_ID"
fi

# Add entry to ecosystem.config.js
ECOSYSTEM_FILE="/home/dan/ecosystem.config.js"
if node -e "
try {
  const fs = require('fs');
  const filePath = '$ECOSYSTEM_FILE';
  let config;
  try { config = require(filePath); } catch(e) { config = { apps: [] }; }
  config.apps = config.apps.filter(a => a.name !== '$SERVICE_ID');
  config.apps.push({
    name: '$SERVICE_ID',
    script: 'server.js',
    cwd: '$SERVICES_DIRECTORY/$SERVICE_ID',
    instances: 1,
    exec_mode: 'fork',
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: { NODE_ENV: 'production' }
  });
  fs.writeFileSync(filePath, 'module.exports = ' + JSON.stringify(config, null, 2) + ';\n');
} catch(e) { console.error(e.message); process.exit(1); }
"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Added $SERVICE_ID to ecosystem.config.js"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot add $SERVICE_ID to ecosystem.config.js"
fi

# Create a VirtualHost config file that proxies requests to node
sudo touch /etc/apache2/sites-available/$DOMAIN_NAME.conf
if echo "<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME $DZ_DOMAIN_NAME $IM_DOMAIN_NAME $DM_DOMAIN_NAME $ADM_DOMAIN_NAME
    ServerAdmin $ADMIN_CONTACT

    # Redirect HTTP to HTTPS
    Redirect permanent / https://$DOMAIN_NAME/

    ErrorLog /var/log/apache2/$DOMAIN_NAME-error.log
    CustomLog /var/log/apache2/$DOMAIN_NAME-access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME $DZ_DOMAIN_NAME $IM_DOMAIN_NAME $DM_DOMAIN_NAME $ADM_DOMAIN_NAME
    ServerAdmin $ADMIN_CONTACT

    # SSL Configuration using Cloudflare Origin CA
    SSLEngine on
    SSLCertificateFile /etc/ssl/cloudflare/danzaharia.com.pem
    SSLCertificateKeyFile /etc/ssl/cloudflare/danzaharia.com.key

    # SSL Security Settings
    SSLProtocol all -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE+AESGCM:ECDHE+AES256:ECDHE+AES128:!aNULL:!MD5:!DSS
    SSLHonorCipherOrder on

    # Proxy Configuration
    ProxyRequests Off
    ProxyPreserveHost On
    ProxyVia Full
    <Proxy *>
        Require all granted
    </Proxy>

    ProxyPass / http://127.0.0.1:$PORT/
    ProxyPassReverse / http://127.0.0.1:$PORT/

    ErrorLog /var/log/apache2/$DOMAIN_NAME-ssl-error.log
    CustomLog /var/log/apache2/$DOMAIN_NAME-ssl-access.log combined
</VirtualHost>" | sudo tee /etc/apache2/sites-available/$DOMAIN_NAME.conf > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created Apache config file at /etc/apache2/sites-available/$DOMAIN_NAME.conf"

	# Enable SSL module if not already enabled
	sudo a2enmod ssl
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Enabled SSL module"

else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create Apache config file at /etc/apache2/sites-available/$DOMAIN_NAME.conf"
fi

# Enable site in Apache
if sudo a2ensite $DOMAIN_NAME > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Enabled site in Apache"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot enable site in Apache"
fi

# Reload Apache
if sudo service apache2 reload; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Initialize Git repository
if cd $SERVICES_DIRECTORY/$SERVICE_ID && \
    git init && \
    git checkout -b main && \
    git config receive.denyCurrentBranch updateInstead > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created git repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create git repository"
fi

# Create basic gitignore file
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/.gitignore
if echo '.env
.DS_Store
.claude/
node_modules/
output.log
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.gitignore > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic gitignore file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic gitignore file"
fi

# Create GitHub Actions deploy workflow
if mkdir -p $SERVICES_DIRECTORY/$SERVICE_ID/.github/workflows; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created .github/workflows directory"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create .github/workflows directory"
fi

if echo 'name: Deploy to Server

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.DEPLOY_SSH_KEY }}" > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key
          ssh-keyscan -H ${{ secrets.DEPLOY_HOST }} >> ~/.ssh/known_hosts

      - name: Push to server
        run: |
          git remote add production ${{ secrets.DEPLOY_USER }}@${{ secrets.DEPLOY_HOST }}:'"$SERVICES_DIRECTORY/$SERVICE_ID"'
          GIT_SSH_COMMAND="ssh -i ~/.ssh/deploy_key" git push production main --force
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.github/workflows/deploy.yml > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created GitHub Actions deploy workflow"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create GitHub Actions deploy workflow"
fi

# Commit basic code
if git add . && git commit -m "Adding basic template" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Committed initial code to repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot commit initial code to repository"
fi

# Create private GitHub repo
if cd $SERVICES_DIRECTORY/$SERVICE_ID && \
    gh repo create "$SERVICE_ID" --private > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created GitHub repo at github.com/$GITHUB_REPO"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create GitHub repo"
fi

# Add GitHub remote and push
if cd $SERVICES_DIRECTORY/$SERVICE_ID && \
    git remote add origin "git@github.com:$GITHUB_REPO.git" 2>/dev/null && \
    git push -u origin main > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Pushed initial commit to GitHub"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot push to GitHub"
fi

# Set GitHub Actions secrets for deployment
if gh secret set DEPLOY_HOST --body "$DEPLOY_HOST" --repo "$GITHUB_REPO" > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Set DEPLOY_HOST secret on GitHub repo"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot set DEPLOY_HOST secret"
fi

if gh secret set DEPLOY_USER --body "$DEPLOY_USER" --repo "$GITHUB_REPO" > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Set DEPLOY_USER secret on GitHub repo"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot set DEPLOY_USER secret"
fi

if gh secret set DEPLOY_SSH_KEY --repo "$GITHUB_REPO" < "$DEPLOY_SSH_KEY_PATH" > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Set DEPLOY_SSH_KEY secret on GitHub repo"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot set DEPLOY_SSH_KEY secret"
fi

# Change permissions for all files in service directory to specified user
if sudo chown -R $USER $SERVICES_DIRECTORY/$SERVICE_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to set $USER as owner"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to set $USER as owner"
fi

# Set up a hook that deploys any commits made to this repo
sudo touch $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive
sudo chmod +x $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive
sudo chown $USER $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive

if echo "#!/bin/bash

cd "$SERVICES_DIRECTORY/$SERVICE_ID" || { echo "Failed to change directory"; exit 1; }

echo "Installing dependencies"
npm install --no-save || { echo "npm install failed"; exit 1; }

echo "Restarting process with pm2"
if pm2 restart "$SERVICE_ID"; then
    echo -e \"${BOLD_GREEN}SUCCESS${END_COLOR} Deployed main to $SERVICES_DIRECTORY/$SERVICE_ID\"
    pm2 save
else
    echo "Failed to restart process with pm2"
    exit 1
fi" | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.git/hooks/post-receive > /dev/null; then
	echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created post-receive hook"
else
	echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create post-receive hook"
fi

# Show confirmation messages depending on optional steps
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD}*** $SERVICE_ID is now set up! ***${END_COLOR}\n"
echo -e "* Visit ${BOLD}https://$DOMAIN_NAME${END_COLOR} to see the new site"
echo -e "* Or ${BOLD}https://$DZ_DOMAIN_NAME${END_COLOR}"
echo -e "* Or ${BOLD}https://$IM_DOMAIN_NAME${END_COLOR}"
echo -e "* Or ${BOLD}https://$DM_DOMAIN_NAME${END_COLOR}"
echo -e "* Or ${BOLD}https://$ADM_DOMAIN_NAME${END_COLOR}"
echo -e "\n* Clone this repository and push to deploy: \n${BOLD}git clone git@github.com:$GITHUB_REPO.git${END_COLOR}"
echo -e " "

# Output the clone command for the host manager to parse
echo "CLONE_COMMAND:git clone git@github.com:$GITHUB_REPO.git"
