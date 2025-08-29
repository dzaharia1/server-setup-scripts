#!/bin/bash

# Set up variables
SERVER="server.danzaharia.com"
USER="dan"
ADMIN_CONTACT="zaharia.danny@gmail.com"
SERVICES_DIRECTORY="/home/$USER/services"
DZ_DOMAIN="danzaharia.com"
IM_DOMAIN="imadean.app"
DM_DOMAIN="danmade.app"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

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

# Prompt for the domain name with the default value
DZ_DOMAIN_NAME="$SERVICE_ID.$DZ_DOMAIN"
IM_DOMAIN_NAME="$SERVICE_ID.$IM_DOMAIN"
DM_DOMAIN_NAME="$SERVICE_ID.$DM_DOMAIN"

read -p "URL (Default: "${DZ_DOMAIN_NAME}"): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-$DZ_DOMAIN_NAME}

echo " "

# Display the collected information
echo "Service Name: $SERVICE_NAME"
echo "Service ID: $SERVICE_ID"
echo "URL: https://$DOMAIN_NAME"
echo "DZ Domain: https://$DZ_DOMAIN_NAME"
echo "IM Domain: https://$IM_DOMAIN_NAME"
echo "DM Domain: https://$DM_DOMAIN_NAME"

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

# Create a setup-log.json
sudo touch "$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json"
if echo "{
  \"service_id\": \"$SERVICE_ID\",
  \"service_name\": \"$SERVICE_NAME\",
  \"domain\": \"https://$DOMAIN_NAME\",
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
if echo '{
  "name": "'"$SERVICE_ID"'",
  "version": "1.0.0",
  "description": "",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "start": "node '"$SERVICES_DIRECTORY"'/'"$SERVICE_ID"'/server.js",
    "dev": "nodemon server.js"
  },
  "author": "",
  "license": "ISC",
  "dependencies": {
    "express": "^4.19.2",
    "path": "^0.12.7",
    "url": "^0.11.3"
  }
}
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/package.json > /dev/null; then
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

# Create a VirtualHost config file that proxies requests to node
sudo touch /etc/apache2/sites-available/$DOMAIN_NAME.conf
if echo "<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME $DZ_DOMAIN_NAME $IM_DOMAIN_NAME $DM_DOMAIN_NAME
    ServerAdmin $ADMIN_CONTACT

    # Redirect HTTP to HTTPS
    Redirect permanent / https://$DOMAIN_NAME/

    ErrorLog /var/log/apache2/$DOMAIN_NAME-error.log
    CustomLog /var/log/apache2/$DOMAIN_NAME-access.log combined
</VirtualHost>

<VirtualHost *:443>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME $DZ_DOMAIN_NAME $IM_DOMAIN_NAME $DM_DOMAIN_NAME
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
node_modules/
output.log
' | sudo tee $SERVICES_DIRECTORY/$SERVICE_ID/.gitignore > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic gitignore file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic gitignore file"
fi

# Commit basic code
if git add . && git commit -m "Adding basic template" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Committed initial code to repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot initial code to repository"
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
echo -e "\n* Clone this repository and push to origin to deploy: \n${BOLD}git clone $USER@$SERVER:$SERVICES_DIRECTORY/$SERVICE_ID${END_COLOR}"
echo -e " "

# Output the clone command for the host manager to parse
echo "CLONE_COMMAND:git clone $USER@$SERVER:$SERVICES_DIRECTORY/$SERVICE_ID"
