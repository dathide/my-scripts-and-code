#!/bin/bash

# Ensure the NEXUS_API_KEY environment variable is set
if [ -z "$NEXUS_API_KEY" ]; then
    echo "Error: NEXUS_API_KEY is not set."
    echo "Please export it using: export NEXUS_API_KEY='your_api_key'"
    exit 1
fi

# Mod details extracted from the URL
GAME_DOMAIN="skyrimspecialedition"
MOD_ID="63953"

# Nexus Mods API endpoint for retrieving mod files
API_URL="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files.json"

echo "Fetching file information for $GAME_DOMAIN mod $MOD_ID..."

# Make the API request using curl, capturing both the response body and the HTTP status code
response=$(curl -s -w "%{http_code}" -X GET "$API_URL" \
    -H "accept: application/json" \
    -H "apikey: $NEXUS_API_KEY")

# Extract the HTTP status code (last 3 characters) and the JSON body
http_code="${response:${#response}-3}"
body="${response:0:${#response}-3}"

# Check if the request was successful
if [ "$http_code" -eq 200 ]; then
    # If 'jq' is installed, use it to pretty-print the JSON output; otherwise, print raw JSON
    if command -v jq &> /dev/null; then
        echo "$body" | jq .
    else
        echo "$body"
    fi
else
    echo "Error: Failed to fetch data. HTTP Status Code: $http_code"
    echo "Response: $body"
    exit 1
fi
