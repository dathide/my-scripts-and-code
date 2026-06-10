#!/bin/bash

# Ensure the NEXUS_API_KEY environment variable is set
if [ -z "$NEXUS_API_KEY" ]; then
    echo "Error: NEXUS_API_KEY is not set."
    echo "Please export it using: export NEXUS_API_KEY='your_api_key'"
    exit 1
fi

# Ensure jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. It is required to parse the JSON."
    exit 1
fi

# Mod details
GAME_DOMAIN="skyrimspecialedition"
MOD_ID="63953"

# Nexus Mods API endpoint for retrieving mod files
API_URL="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files.json"

echo "Fetching file information for $GAME_DOMAIN mod $MOD_ID..."

# Make the API request using curl
response=$(curl -s -w "%{http_code}" -X GET "$API_URL" \
    -H "accept: application/json" \
    -H "apikey: $NEXUS_API_KEY")

# Extract the HTTP status code and the JSON body
http_code="${response:${#response}-3}"
body="${response:0:${#response}-3}"

# Check if the request was successful
if [ "$http_code" -eq 200 ]; then
    # 1. Output the file_updates array, which starts like this:
    #--- file_updates ---
    #[
    #   {
    #       "old_file_id": 265600,
    #       "new_file_id": 266650,
    #       "old_file_name": "Optional Quick Start - SE-63953-1-0-1-1645348417.7z",
    #       "new_file_name": "Optional Quick Start - SE-63953-1-0-2-1645792984.7z",
    #       "uploaded_timestamp": 1645792984,
    #       "uploaded_time": "2022-02-25T12:43:04.000+00:00"
    #},
    echo "--- file_updates ---"
    echo "$body" | jq '.file_updates'
    echo "--------------------"

    # 2. Find the latest file matching the NEW criteria
    # We filter by new_file_name starting with "Optional Quick Start - SE-63953-"
    LATEST_FILE=$(echo "$body" | jq -c '.file_updates | map(select(.new_file_name | startswith("Optional Quick Start - SE-63953-"))) | sort_by(.uploaded_timestamp) | last')

    if [ -z "$LATEST_FILE" ] || [ "$LATEST_FILE" == "null" ]; then
        echo "Error: No file found with 'new_file_name' starting with 'Optional Quick Start - SE-63953-'."
        exit 1
    fi

    FILE_ID=$(echo "$LATEST_FILE" | jq -r '.new_file_id')
    FILE_NAME=$(echo "$LATEST_FILE" | jq -r '.new_file_name')

    echo "Latest matching file: $FILE_NAME (ID: $FILE_ID)"
    echo "Fetching download link..."

    # 3. Fetch the download link for the specific file ID
    DL_API_URL="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files/${FILE_ID}/download_link.json"
    dl_response=$(curl -s -w "%{http_code}" -X GET "$DL_API_URL" \
        -H "accept: application/json" \
        -H "apikey: $NEXUS_API_KEY")

    dl_http_code="${dl_response:${#dl_response}-3}"
    dl_body="${dl_response:0:${#dl_response}-3}"

    if [ "$dl_http_code" -eq 200 ]; then
        # Extract the first URI from the returned array of download links
        # tr -d '\r' removes any hidden carriage returns that might also break curl
        DOWNLOAD_URL=$(echo "$dl_body" | jq -r '.[0].URI' | tr -d '\r')

        if [ "$DOWNLOAD_URL" != "null" ] && [ -n "$DOWNLOAD_URL" ]; then

            # FIX: URL-encode spaces to %20 so curl doesn't reject the URL
            DOWNLOAD_URL="${DOWNLOAD_URL// /%20}"

            echo "Downloading $FILE_NAME..."
            # Use curl to download the file, following redirects (-L)
            curl -L -o "$FILE_NAME" "$DOWNLOAD_URL"
            echo -e "\nDownload complete!"
        else
            echo "Error: Could not extract a valid download URL from the response."
            echo "Response body: $dl_body"
        fi
    else
        echo "Error: Failed to fetch download link. HTTP Status Code: $dl_http_code"
        echo "Response: $dl_body"
    fi
else
    echo "Error: Failed to fetch data. HTTP Status Code: $http_code"
    echo "Response: $body"
    exit 1
fi
