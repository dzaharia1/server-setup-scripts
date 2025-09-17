#!/bin/bash

# Set up variables
SERVER="server.danzaharia.com"
USER="dan"
ADMIN_CONTACT="zaharia.danny@gmail.com"
APPS_DIRECTORY="/home/$USER/vite-apps"
DZ_DOMAIN="danzaharia.com"
IM_DOMAIN="imadean.app"
DM_DOMAIN="danmade.app"
ADM_DOMAIN="adanmade.app"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Function to convert app name to hyphenated app ID
generate_app_id() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Prompt for the app name and generate the default app ID
read -p "App Name (Title Case): " APP_NAME
DEFAULT_APP_ID=$(generate_app_id "$APP_NAME")

# Prompt for the app ID with the default value
read -p "App ID (Default: "${DEFAULT_APP_ID}"): " APP_ID
APP_ID=${APP_ID:-$DEFAULT_APP_ID}

# Prompt for the domain name with the default value
DZ_DOMAIN_NAME="$APP_ID.$DZ_DOMAIN"
IM_DOMAIN_NAME="$APP_ID.$IM_DOMAIN"
DM_DOMAIN_NAME="$APP_ID.$DM_DOMAIN"
ADM_DOMAIN_NAME="$APP_ID.$ADM_DOMAIN"

read -p "URL (Default: "${DM_DOMAIN_NAME}"): " DOMAIN_NAME
DOMAIN_NAME=${DOMAIN_NAME:-$DM_DOMAIN_NAME}

echo " "

# Display the collected information
echo "App Name: $APP_NAME"
echo "App ID: $APP_ID"
echo "DZ Domain: https://$DZ_DOMAIN_NAME"
echo "IM Domain: https://$IM_DOMAIN_NAME"
echo "DM Domain: https://$DM_DOMAIN_NAME"
echo "ADM Domain: https://$ADM_DOMAIN_NAME"

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

# Create root directory for app
if sudo mkdir $APPS_DIRECTORY/$APP_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created root directory at $APPS_DIRECTORY/$APP_ID"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create root directory at $APPS_DIRECTORY/$APP_ID"
fi

# Create src directory for app
if sudo mkdir $APPS_DIRECTORY/$APP_ID/src; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created src directory at $APPS_DIRECTORY/$APP_ID/src"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create src directory at $APPS_DIRECTORY/$APP_ID/src"
fi

# Create public directory for app
if sudo mkdir $APPS_DIRECTORY/$APP_ID/public; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created public directory at $APPS_DIRECTORY/$APP_ID/public"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create public directory at $APPS_DIRECTORY/$APP_ID/public"
fi

# Create a basic src/App.jsx file
sudo touch $APPS_DIRECTORY/$APP_ID/src/App.jsx
if echo "import React from \"react\";
import styled from \"styled-components\";

const Page = styled.div\`
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100vh;
  font-size: 24px;
  color: #333;
\`;

function App() {
  return <Page>Hello from ${APP_NAME}!</Page>;
}

export default App;
" | sudo tee $APPS_DIRECTORY/$APP_ID/src/App.jsx > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic src/App.jsx file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic src/App.jsx file"
fi

# Create a basic src/index.css
sudo touch $APPS_DIRECTORY/$APP_ID/src/index.css
if echo "body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, \"Segoe UI\", \"Roboto\", \"Oxygen\",
    \"Ubuntu\", \"Cantarell\", \"Fira Sans\", \"Droid Sans\", \"Helvetica Neue\",
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

code {
  font-family: source-code-pro, Menlo, Monaco, Consolas, \"Courier New\",
    monospace;
}
" | sudo tee $APPS_DIRECTORY/$APP_ID/src/index.css > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic src/index.css file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic src/index.css file"
fi

# Create a basic src/main.jsx
sudo touch $APPS_DIRECTORY/$APP_ID/src/main.jsx
if echo "import React from \"react\";
import ReactDOM from \"react-dom/client\";
import \"./index.css\";
import App from \"./App.jsx\";

ReactDOM.createRoot(document.getElementById(\"root\")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
" | sudo tee $APPS_DIRECTORY/$APP_ID/src/main.jsx > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic src/main.jsx file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic src/main.jsx file"
fi

# Create a basic index.html
sudo touch $APPS_DIRECTORY/$APP_ID/index.html
if echo "<!DOCTYPE html>
<html lang=\"en\">
  <head>
    <meta charset=\"UTF-8\" />
    <link rel=\"icon\" type=\"image/svg+xml\" href=\"/vite.svg\" />
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />
    <title>$APP_NAME</title>
  </head>
  <body>
    <div id=\"root\"></div>
    <script type=\"module\" src=\"/src/main.jsx\"></script>
  </body>
</html>
" | sudo tee $APPS_DIRECTORY/$APP_ID/index.html > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic index.html file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic index.html file"
fi

# Create a basic public/manifest.json
sudo touch $APPS_DIRECTORY/$APP_ID/public/manifest.json
if echo "{
  \"short_name\": \"$APP_NAME\",
  \"name\": \"$APP_NAME\",
  \"start_url\": \".\",
  \"display\": \"standalone\",
  \"theme_color\": \"#000000\",
  \"background_color\": \"#ffffff\"
}
" | sudo tee $APPS_DIRECTORY/$APP_ID/public/manifest.json > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic public/manifest.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic public/manifest.json file"
fi

# Create a basic public/robots.txt
sudo touch $APPS_DIRECTORY/$APP_ID/public/manifest.json
if echo "# https://www.robotstxt.org/robotstxt.html
User-agent: *
Disallow:
" | sudo tee $APPS_DIRECTORY/$APP_ID/public/robots.txt > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic public/robots.txt file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic public/robots.txt file"
fi

# Create a basic README.md
sudo touch $APPS_DIRECTORY/$APP_ID/README.md
if echo "# $APP_NAME

Identifier: $APP_ID

Created: $(date)" | sudo tee $APPS_DIRECTORY/$APP_ID/README.md > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic README.md file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic README.md file"
fi

# Create a basic package.json
sudo touch $APPS_DIRECTORY/$APP_ID/package.json
if echo "{
  \"name\": \"$APP_ID\",
  \"private\": true,
  \"version\": \"0.0.0\",
  \"type\": \"module\",
  \"scripts\": {
    \"dev\": \"vite\",
    \"build\": \"vite build\",
    \"lint\": \"eslint . --ext js,jsx --report-unused-disable-directives --max-warnings 0\",
    \"preview\": \"vite preview\"
  },
  \"dependencies\": {
    \"react\": \"^18.2.0\",
    \"react-dom\": \"^18.2.0\",
    \"styled-components\": \"^6.1.11\"
  },
  \"devDependencies\": {
    \"@types/react\": \"^18.2.43\",
    \"@types/react-dom\": \"^18.2.17\",
    \"@vitejs/plugin-react\": \"^4.2.1\",
    \"eslint\": \"^8.55.0\",
    \"eslint-plugin-react\": \"^7.33.2\",
    \"eslint-plugin-react-hooks\": \"^4.6.0\",
    \"eslint-plugin-react-refresh\": \"^0.4.5\",
    \"vite\": \"^5.0.8\"
  }
}" | sudo tee $APPS_DIRECTORY/$APP_ID/package.json > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic package.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic package.json file"
fi

# Create a setup-log.json
sudo touch $APPS_DIRECTORY/$APP_ID/setup-log.json
if echo "{
  \"app_id\": \"$APP_ID\",
  \"app_name\": \"$APP_NAME\",
  \"domain\": \"https://$DOMAIN_NAME\",
  \"author\": \"$USER\",
  \"created_on\": \"$(date)\"
}" | sudo tee $APPS_DIRECTORY/$APP_ID/setup-log.json > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created setup-log.json file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create setup-log.json file"
fi

# Change permissions for app directory to specified user
if sudo chown -R $USER $APPS_DIRECTORY/$APP_ID; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Changed permissions to set $USER as owner"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change permissions to set $USER as owner"
fi

# Install node modules
if cd $APPS_DIRECTORY/$APP_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Build app for production
if cd $APPS_DIRECTORY/$APP_ID && npm run build; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Built app for production"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot build app for production"
fi

# Create a VirtualHost config file that points to the app's build directory
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

    DocumentRoot $APPS_DIRECTORY/$APP_ID/dist
    
    <Directory $APPS_DIRECTORY/$APP_ID/dist>
        AllowOverride all
        Require all granted
    </Directory>

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
if cd $APPS_DIRECTORY/$APP_ID && \
    git init && \
    git checkout -b main && \
    git config receive.denyCurrentBranch updateInstead > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created git repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create git repository"
fi

# Create basic gitignore file
sudo touch $APPS_DIRECTORY/$APP_ID/.gitignore
if echo '.env
.DS_Store
node_modules/
dist/
' | sudo tee $APPS_DIRECTORY/$APP_ID/.gitignore > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic gitignore file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic gitignore file"
fi

# Set up a hook that deploys any commits made to this repo 
sudo touch $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive
sudo chmod +x $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive
sudo chown $USER $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive

if echo "#!/bin/bash

cd "$APPS_DIRECTORY/$APP_ID" || { echo "Failed to change directory"; exit 1; }

echo "Installing dependencies"
npm install --no-save || { echo "npm install failed"; exit 1; }

echo "Building app for production"
npm run build

echo -e \"${BOLD_GREEN}SUCCESS${END_COLOR} Deployed main to $APPS_DIRECTORY/$APP_ID\"
" | sudo tee $APPS_DIRECTORY/$APP_ID/.git/hooks/post-receive > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created post-receive hook"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create post-receive hook"
fi

# Create a basic vite.svg
sudo touch $APPS_DIRECTORY/$APP_ID/public/vite.svg
if echo "<svg xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" aria-hidden=\"true\" role=\"img\" class=\"iconify iconify--logos\" width=\"31.88\" height=\"32\" preserveAspectRatio=\"xMidYMid meet\" viewBox=\"0 0 256 257\"><defs><linearGradient id=\"IconifyId1813088fe1fbc01fb466\" x1=\"-.828%\" x2=\"57.636%\" y1=\"7.652%\" y2=\"78.411%\"><stop offset=\"0%\" stop-color=\"#41D1FF\"></stop><stop offset=\"100%\" stop-color=\"#BD34FE\"></stop></linearGradient><linearGradient id=\"IconifyId1813088fe1fbc01fb467\" x1=\"43.376%\" x2=\"50.316%\" y1=\"2.242%\" y2=\"89.03%\"><stop offset=\"0%\" stop-color=\"#FFEA83\"></stop><stop offset=\"8.333%\" stop-color=\"#FFDD35\"></stop><stop offset=\"100%\" stop-color=\"#FFA800\"></stop></linearGradient></defs><path fill=\"url(#IconifyId1813088fe1fbc01fb466)\" d=\"M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z\"></path><path fill=\"url(#IconifyId1813088fe1fbc01fb467)\" d=\"M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z\"></path></svg>" | sudo tee $APPS_DIRECTORY/$APP_ID/public/vite.svg > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic vite.svg file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic vite.svg file"
fi

# Create a basic vite.config.js
sudo touch $APPS_DIRECTORY/$APP_ID/vite.config.js
if echo "import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets'
  }
})" | sudo tee $APPS_DIRECTORY/$APP_ID/vite.config.js > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic vite.config.js file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic vite.config.js file"
fi

# Create a basic .eslintrc.cjs
sudo touch $APPS_DIRECTORY/$APP_ID/.eslintrc.cjs
if echo "module.exports = {
  root: true,
  env: { browser: true, es2020: true },
  extends: [
    'eslint:recommended',
    '@typescript-eslint/recommended',
    'plugin:react-hooks/recommended',
  ],
  ignorePatterns: ['dist', '.eslintrc.cjs'],
  parserOptions: { ecmaVersion: 'latest', sourceType: 'module' },
  settings: { react: { version: '18.2' } },
  plugins: ['react-refresh'],
  rules: {
    'react-refresh/only-export-components': [
      'warn',
      { allowConstantExport: true },
    ],
  },
}" | sudo tee $APPS_DIRECTORY/$APP_ID/.eslintrc.cjs > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Created basic .eslintrc.cjs file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot create basic .eslintrc.cjs file"
fi

# Commit basic code
if cd $APPS_DIRECTORY/$APP_ID && git add . && git commit -m "Adding basic template" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Committed initial code to repository"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot commit initial code to repository"
fi

# Show confirmation messages
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD}*** $APP_ID is now set up! ***${END_COLOR}\n"
echo -e "* Visit ${BOLD}https://$DOMAIN_NAME${END_COLOR} to see the new site"
echo -e "* Or ${BOLD}https://$DZ_DOMAIN_NAME${END_COLOR}"
echo -e "* Or ${BOLD}https://$IM_DOMAIN_NAME${END_COLOR}"
echo -e "* Or ${BOLD}https://$DM_DOMAIN_NAME${END_COLOR}"
echo -e "* Or ${BOLD}https://$ADM_DOMAIN_NAME${END_COLOR}"
echo -e "\n* Clone this repository and push to origin to deploy: \n${BOLD}git clone $USER@$SERVER:$APPS_DIRECTORY/$APP_ID${END_COLOR}"
echo -e " "
