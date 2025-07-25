#!/bin/bash

# Set up variables
USER="dan"
APPS_DIRECTORY="/home/$USER/vite-apps"

# Set up formatting for use later
BOLD='\e[1m'
BOLD_RED='\e[1;31m'
BOLD_GREEN='\e[1;32m'
END_COLOR='\e[0m' # This ends formatting

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --app-id) APP_ID="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for APP_ID if not set by CLI flag
if [ -z "$APP_ID" ]; then
    read -p "App ID: " APP_ID
fi

# Function to clean APP_ID
clean_app_id() {
    echo "$1" | tr -d '\r'
}

# Clean APP_ID
APP_ID=$(clean_app_id "$APP_ID")

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
SETUP_LOG_FILE="$APPS_DIRECTORY/$APP_ID/setup-log.json"
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

# Disable site in Apache
if sudo a2dissite "$DOMAIN_NAME" > /dev/null; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Disabled site in Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot disable site in Apache"
fi

# Delete Apache config file
if sudo rm -f "/etc/apache2/sites-available/$DOMAIN_NAME.conf" && sudo rm -f "/etc/apache2/sites-available/$DOMAIN_NAME-le-ssl.conf"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted Apache config file"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete Apache config file"
fi

# Delete app directory
if sudo rm -r "$APPS_DIRECTORY/$APP_ID/"; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted app directory"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete app directory"
fi

# Reload Apache
if sudo service apache2 reload; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Reloaded Apache"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot reload Apache"
fi

# Show confirmation messages
echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD_RED}*** $APP_ID is now removed! ***${END_COLOR}\n"
echo -e " " 