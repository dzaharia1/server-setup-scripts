#!/bin/bash

# Set up variables
USER="dan"
SERVICES_DIRECTORY="/home/$USER/services"

# Initialize NVM to ensure pm2 is available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
BOLD_CYAN='\e[1;36m'
END_COLOR='\e[0m' # This ends formatting

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --service-id) SERVICE_ID="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for SERVICE_ID if not set by CLI flag
if [ -z "$SERVICE_ID" ]; then
    read -p "Service ID: " SERVICE_ID
fi

# Function to clean SERVICE_ID
clean_service_id() {
    echo "$1" | tr -d '\r'
}

# Clean SERVICE_ID
SERVICE_ID=$(clean_service_id "$SERVICE_ID")

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

# Find pm2 executable
PM2_CMD=$(which pm2)
if [ -z "$PM2_CMD" ]; then
    echo -e "${BOLD_RED}FAILED${END_COLOR} pm2 not found. Please install pm2 globally: npm install -g pm2"
    exit 1
else
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Found pm2 at: $PM2_CMD"
fi

# Find the DOMAIN_NAME from setup-log.json
SETUP_LOG_FILE="$SERVICES_DIRECTORY/$SERVICE_ID/setup-log.json"
if [ -f "$SETUP_LOG_FILE" ]; then
    DOMAIN_NAME=$(jq -r '.domain' "$SETUP_LOG_FILE" | sed 's|https://||')
    if [ -z "$DOMAIN_NAME" ] || [ "$DOMAIN_NAME" == "null" ]; then
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot find domain name in setup-log.json"
        exit 1
    else
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Found domain name $DOMAIN_NAME in setup-log.json "
    fi
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot find file setup-log.json"
    exit 1
fi

# Install node modules
if cd $SERVICES_DIRECTORY/$SERVICE_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Check for build script and run it if it exists
echo -e "${BOLD_CYAN}INFO${END_COLOR} Running build script (if present)"
if cd "$SERVICES_DIRECTORY/$SERVICE_ID" && npm run build > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Ran build script"
else
    echo -e "${BOLD_CYAN}INFO${END_COLOR} No build script found or build failed (this is normal for some projects)"
fi

# Restart node process with pm2
if $PM2_CMD restart "$SERVICE_ID"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Restarted node process with pm2"
    $PM2_CMD save
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot restart node process with pm2"
fi

# Reload Apache
if sudo service apache2 reload; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Show confirmation messages depending on optional steps
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD_CYAN}*** $SERVICE_ID has been restarted! ***${END_COLOR}\n"
echo -e " "
