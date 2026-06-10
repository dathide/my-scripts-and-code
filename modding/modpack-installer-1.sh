#!/bin/bash

# This script is called nexusmods-modpack-installer-1.sh
# get_full_json_for_one_id <MOD_STRING> outputs raw json for one mod id's full file history
# get_json_section_file_updates "$RAW_JSON" outputs raw json for the 'file_updates' section
# get_latest_update_by_prefix "Prefix String" "$FILE_UPDATES_JSON" outputs raw json for the section with the "new_file_name" that starts with the prefix string and has the latest "uploaded_time"
# download_latest_update "Prefix String" "$RAW_JSON" downloads a latest update into the downloads folder

# --- Global Variables ---
GAME_DOMAIN="skyrimspecialedition"

# --- Global Dependency Check ---
# Check for required commands once at the top to avoid redundancy inside functions.
for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: '$cmd' is required by this script. Please install $cmd." >&2
        # Safely exit if executed directly, or return if sourced
        [[ "${BASH_SOURCE[0]}" == "${0}" ]] && exit 1 || return 1
    fi
done

# Function to fetch the full JSON for a given mod string
# Usage: get_full_json_for_one_id <MOD_STRING>
get_full_json_for_one_id() {
    local mod_string="$1"

    # Validate inputs
    if [ -z "$mod_string" ]; then
        echo "Error: Mod string is required as the first argument." >&2
        return 1
    fi

    # Extract the mod ID from the string (everything after the last dash)
    local mod_id="${mod_string##*-}"

    # Ensure the NEXUSMODS_API_KEY environment variable is set
    if [ -z "$NEXUSMODS_API_KEY" ]; then
        echo "Error: NEXUSMODS_API_KEY is not set." >&2
        echo "Please export it using: export NEXUSMODS_API_KEY='your_api_key'" >&2
        return 1
    fi

    # Nexus Mods API endpoint for retrieving mod files
    local api_url="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${mod_id}/files.json"

    # Make the API request using curl, capturing both the response body and the HTTP status code
    local response
    response=$(curl -s -w "%{http_code}" -X GET "$api_url" \
        -H "accept: application/json" \
        -H "apikey: $NEXUSMODS_API_KEY")

    # Extract the HTTP status code (last 3 characters) and the JSON body
    local http_code="${response:${#response}-3}"
    local body="${response:0:${#response}-3}"

    # Check if the request was successful
    if [ "$http_code" -eq 200 ]; then
        # Just output the raw JSON for other functions to use
        echo "$body"
    else
        echo "Error: Failed to fetch data for mod $mod_id. HTTP Status Code: $http_code" >&2
        echo "Response: $body" >&2
        return 1
    fi
}

# Function to extract the 'file_updates' section from raw Nexus Mods JSON as raw/compact JSON
# Usage 1: get_json_section_file_updates "$RAW_JSON"
# Usage 2: echo "$RAW_JSON" | get_json_section_file_updates
get_json_section_file_updates() {
    local input_json

    # Check if JSON was passed as a positional argument
    if [ -n "$1" ]; then
        input_json="$1"
    # Otherwise, check if data is being piped in via stdin
    elif ! [ -t 0 ]; then
        input_json=$(cat)
    else
        echo "Error: No JSON input provided to get_json_section_file_updates." >&2
        return 1
    fi

    # Use -c (--compact-output) to ensure the output is raw, unformatted JSON
    echo "$input_json" | jq -c '.file_updates'
}

# Function to extract the latest file update matching a specific prefix
# Usage 1: get_latest_update_by_prefix "Prefix String" "$FILE_UPDATES_JSON"
# Usage 2: echo "$FILE_UPDATES_JSON" | get_latest_update_by_prefix "Prefix String"
get_latest_update_by_prefix() {
    local prefix="$1"
    local input_json

    # Validate that a prefix was provided
    if [ -z "$prefix" ]; then
        echo "Error: Prefix string is required as the first argument." >&2
        return 1
    fi

    # Check if JSON was passed as a second positional argument
    if [ -n "$2" ]; then
        input_json="$2"
    # Otherwise, check if data is being piped in via stdin
    elif ! [ -t 0 ]; then
        input_json=$(cat)
    else
        echo "Error: No JSON input provided to get_latest_update_by_prefix." >&2
        return 1
    fi

    # 1. map(select(...)): Filters the array to only include objects where new_file_name starts with the prefix
    # 2. max_by(.uploaded_timestamp): Finds the object in the filtered array with the highest timestamp
    # 3. -c: Outputs as raw/compact JSON
    echo "$input_json" | jq -c --arg prefix "$prefix" 'map(select(.new_file_name | startswith($prefix))) | max_by(.uploaded_timestamp)'
}

# Function to download the latest update file
# Usage 1: download_latest_update "Prefix String" "$RAW_JSON"
# Usage 2: echo "$RAW_JSON" | download_latest_update "Prefix String"
download_latest_update() {
    local prefix_string="$1"
    local input_json

    # Validate inputs
    if [ -z "$prefix_string" ]; then
        echo "Error: Prefix string is required as the first argument." >&2
        return 1
    fi

    # Check if data is being piped in via stdin
    if ! [ -t 0 ]; then
        input_json=$(cat)
    else
        # If not piped, $2 must be the JSON
        if [ -n "$2" ]; then
            input_json="$2"
        else
            echo "Error: No JSON input provided to download_latest_update." >&2
            return 1
        fi
    fi

    # Extract the mod ID from the prefix string (everything after the last dash)
    local mod_id="${prefix_string##*-}"

    # Ensure the NEXUSMODS_API_KEY environment variable is set
    if [ -z "$NEXUSMODS_API_KEY" ]; then
        echo "Error: NEXUSMODS_API_KEY is not set." >&2
        return 1
    fi

    # Extract file ID and file name from the JSON
    local file_id
    local file_name
    file_id=$(echo "$input_json" | jq -r '.new_file_id')
    file_name=$(echo "$input_json" | jq -r '.new_file_name')

    if [ -z "$file_id" ] || [ "$file_id" == "null" ]; then
        echo "Error: Could not extract 'new_file_id' from the provided JSON." >&2
        return 1
    fi

    echo "Fetching download link for $file_name (ID: $file_id)..." >&2

    # Fetch the download link for the specific file ID
    local dl_api_url="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${mod_id}/files/${file_id}/download_link.json"
    local dl_response
    dl_response=$(curl -s -w "%{http_code}" -X GET "$dl_api_url" \
        -H "accept: application/json" \
        -H "apikey: $NEXUSMODS_API_KEY")

    local dl_http_code="${dl_response:${#dl_response}-3}"
    local dl_body="${dl_response:0:${#dl_response}-3}"

    if [ "$dl_http_code" -eq 200 ]; then
        # Extract the first URI from the returned array of download links
        local download_url
        download_url=$(echo "$dl_body" | jq -r '.[0].URI' | tr -d '\r')

        if [ "$download_url" != "null" ] && [ -n "$download_url" ]; then
            # URL-encode spaces to %20 so curl doesn't reject the URL
            download_url="${download_url// /%20}"

            echo "Downloading $file_name..." >&2
            # Use curl to download the file, following redirects (-L)
            curl -L -o "$file_name" "$download_url"
            echo -e "\nDownload complete!" >&2
        else
            echo "Error: Could not extract a valid download URL from the response." >&2
            echo "Response body: $dl_body" >&2
            return 1
        fi
    else
        echo "Error: Failed to fetch download link. HTTP Status Code: $dl_http_code" >&2
        echo "Response: $dl_body" >&2
        return 1
    fi
}

# --- Execution Block ---
# If the script is executed directly (not sourced by another script), run the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -z "$1" ]; then
        echo "Usage: $0 <MOD_STRING>" >&2
        echo "Example: $0 \"Optional Quick Start - SE-63953\"" >&2
        exit 1
    fi

    # Find the latest file update starting with the string and download it
    get_full_json_for_one_id "$1" | \
        get_json_section_file_updates | \
        get_latest_update_by_prefix "$1" | \
        download_latest_update "$1"
fi
