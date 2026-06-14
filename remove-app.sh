#!/bin/bash

# Set up formatting
BOLD='\033[1m'
BOLD_RED='\033[1;31m'
BOLD_GREEN='\033[1;32m'
END_COLOR='\033[0m'

# Parse CLI arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --app-id) APP_ID="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Prompt for APP_ID if not set
if [ -z "$APP_ID" ]; then
    read -p "Enter App ID to remove: " APP_ID
fi

clean_app_id() {
    echo "$1" | tr -d '\r'
}
APP_ID=$(clean_app_id "$APP_ID")

# Source deploy secrets
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEPLOY_SECRETS_FILE="$SCRIPT_DIR/.deploy-secrets"
if [ -f "$DEPLOY_SECRETS_FILE" ]; then
    source "$DEPLOY_SECRETS_FILE"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot find deploy secrets at $DEPLOY_SECRETS_FILE"
    exit 1
fi

if [ -z "$LOCAL_PROJECTS_DIR" ]; then
    echo -e "${BOLD_RED}FAILED${END_COLOR} LOCAL_PROJECTS_DIR is not set in .deploy-secrets"
    exit 1
fi

eval LOCAL_PROJECTS_DIR="$LOCAL_PROJECTS_DIR"
REGISTRY_FILE="$SCRIPT_DIR/apps-registry/apps-registry.json"

# Check metadata in registry
DOMAIN_NAME=""
FIREBASE_PROJECT_ID=""
if [ -f "$REGISTRY_FILE" ]; then
    DOMAIN_NAME=$(jq -r ".[] | select(.id == \"$APP_ID\" and .status == \"active\") | .domain" "$REGISTRY_FILE" | sed 's|https://||')
    FIREBASE_PROJECT_ID=$(jq -r ".[] | select(.id == \"$APP_ID\" and .status == \"active\") | .firebase_project_id" "$REGISTRY_FILE")
fi

# Fallback to local .firebaserc if firebase_project_id is not in registry
if [ -z "$FIREBASE_PROJECT_ID" ] || [ "$FIREBASE_PROJECT_ID" = "null" ]; then
    if [ -f "$LOCAL_PROJECTS_DIR/$APP_ID/frontend/.firebaserc" ]; then
        FIREBASE_PROJECT_ID=$(jq -r '.projects.default' "$LOCAL_PROJECTS_DIR/$APP_ID/frontend/.firebaserc")
    elif [ -f "$LOCAL_PROJECTS_DIR/$APP_ID/backend/.firebaserc" ]; then
        FIREBASE_PROJECT_ID=$(jq -r '.projects.default' "$LOCAL_PROJECTS_DIR/$APP_ID/backend/.firebaserc")
    else
        FIREBASE_PROJECT_ID="$APP_ID"
    fi
fi

# 1. Delete local app folder
LOCAL_APP_DIR="$LOCAL_PROJECTS_DIR/$APP_ID"
if [ -d "$LOCAL_APP_DIR" ]; then
    rm -rf "$LOCAL_APP_DIR"
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted local project folder at $LOCAL_APP_DIR"
else
    echo -e "${BOLD}SKIPPED${END_COLOR} Local folder does not exist"
fi

# 2. Delete GCP/Firebase Project
echo "Deleting GCP/Firebase project $FIREBASE_PROJECT_ID..."
if gcloud projects delete "$FIREBASE_PROJECT_ID" --quiet >/dev/null 2>&1; then
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted GCP/Firebase project"
else
    echo -e "${BOLD_RED}FAILED${END_COLOR} Cannot delete GCP project (you may need to delete it manually in the console)"
fi

# 3. Delete DNS CNAME records in Cloudflare for both domains
if [ -n "$CLOUDFLARE_API_TOKEN" ]; then
    # Delete danzaharia.com record
    if [ -n "$DZ_ZONE_ID" ]; then
        target_domain="$APP_ID.danzaharia.com"
        echo "Finding DNS record in Cloudflare for $target_domain..."
        record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$DZ_ZONE_ID/dns_records?name=$target_domain" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
        
        if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
            echo "Deleting Cloudflare DNS record..."
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$DZ_ZONE_ID/dns_records/$record_id" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" > /dev/null
            echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted CNAME record for $target_domain"
        fi
    fi
    
    # Delete adanmade.app record
    if [ -n "$ADMA_ZONE_ID" ]; then
        target_domain="$APP_ID.adanmade.app"
        echo "Finding DNS record in Cloudflare for $target_domain..."
        record_id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ADMA_ZONE_ID/dns_records?name=$target_domain" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" | jq -r '.result[0].id // empty')
        
        if [ -n "$record_id" ] && [ "$record_id" != "null" ]; then
            echo "Deleting Cloudflare DNS record..."
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$ADMA_ZONE_ID/dns_records/$record_id" \
                -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
                -H "Content-Type: application/json" > /dev/null
            echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Deleted CNAME record for $target_domain"
        fi
    fi
fi



# 4. Update status in Registry
if [ -f "$REGISTRY_FILE" ]; then
    echo "Updating status in synchronized registry..."
    cd "$SCRIPT_DIR/apps-registry"
    jq "map(if .id == \"$APP_ID\" and .status == \"active\" then .status = \"removed\" else . end)" apps-registry.json > apps-registry.tmp.json && mv apps-registry.tmp.json apps-registry.json
    git add apps-registry.json
    git commit -m "Remove app: $APP_ID"
    git push >/dev/null 2>&1
    echo -e "${BOLD_GREEN}SUCCESS${END_COLOR} Registry updated and synchronized!"
fi

echo -e "\n------------------------------------"
echo -e "--------------- ${BOLD}DONE${END_COLOR} ---------------"
echo -e "------------------------------------ \n"
echo -e "${BOLD_RED}*** $APP_ID is now decommissioned! ***${END_COLOR}\n"
