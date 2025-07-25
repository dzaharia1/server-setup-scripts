#!/bin/bash

# Set up variables
USER="dan"
SERVICES_DIRECTORY="/home/$USER/services"

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

# Stop node process
if pkill -f "node.*$SERVICES_DIRECTORY/$SERVICE_ID/" > /dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Stopped node process"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot stop node process"
fi

# Install node modules
if cd $SERVICES_DIRECTORY/$SERVICE_ID && npm install --no-save; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Installed node modules"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot install node modules"
fi

# Start node process
if cd "$SERVICES_DIRECTORY/$SERVICE_ID"; then
    setsid nohup npm run start > ./output.log 2>&1 &
    NODE_PID=$!
    
    if kill -0 $NODE_PID > /dev/null 2>&1; then
        echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Started node with process ID $NODE_PID"
    else
        echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot start node"
    fi
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot change directory to $SERVICES_DIRECTORY/$SERVICE_ID"
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
