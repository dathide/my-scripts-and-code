#!/bin/bash

# Ensure the NEXUS_API_KEY environment variable is set
if [ -z "$NEXUS_API_KEY" ]; then
    echo "Error: NEXUS_API_KEY is not set."
    echo "Please export it using: export NEXUS_API_KEY='your_api_key'"
    exit 1
fi

# Ensure jq is installed, as it's needed to filter the JSON
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. It is required to parse the JSON."
    echo "Please install it using your package manager (e.g., 'sudo rpm-ostree install jq' or 'brew install jq')."
    exit 1
fi

# Mod details
GAME_DOMAIN="skyrimspecialedition"
MOD_ID="63953"

# Nexus Mods API endpoint
API_URL="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files.json"

# Make the API request using curl
response=$(curl -s -w "%{http_code}" -X GET "$API_URL" \
    -H "accept: application/json" \
    -H "apikey: $NEXUS_API_KEY")

# Extract the HTTP status code (last 3 characters) and the JSON body
http_code="${response:${#response}-3}"
body="${response:0:${#response}-3}"

# Check if the request was successful
if [ "$http_code" -eq 200 ]; then
    # Use jq to extract and pretty-print ONLY the "file_updates" array
    echo "$body" | jq '.file_updates'
else
    echo "Error: Failed to fetch data. HTTP Status Code: $http_code"
    echo "Response: $body"
    exit 1
fi
