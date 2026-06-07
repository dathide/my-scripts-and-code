#!/bin/bash

# This script is called nexusmods-modpack-installer-1.sh
# get_full_json_for_one_id() <MOD_ID> [GAME_DOMAIN] outputs raw json for one mod id's full file history
# get_json_section_file_updates() "$RAW_JSON" outputs raw json for the 'file_updates' section

# Function to fetch the full JSON for a given mod ID
# Usage: get_mod_file_json <MOD_ID> [GAME_DOMAIN]
get_full_json_for_one_id() {
    local mod_id="$1"
    # Default to skyrimspecialedition if no second argument is provided
    local game_domain="${2:-skyrimspecialedition}"

    # Validate inputs
    if [ -z "$mod_id" ]; then
        echo "Error: Mod ID is required as the first argument." >&2
        return 1
    fi

    # Ensure the NEXUSMODS_API_KEY environment variable is set
    if [ -z "$NEXUSMODS_API_KEY" ]; then
        echo "Error: NEXUSMODS_API_KEY is not set." >&2
        echo "Please export it using: export NEXUSMODS_API_KEY='your_api_key'" >&2
        return 1
    fi

    # Nexus Mods API endpoint for retrieving mod files
    local api_url="https://api.nexusmods.com/v1/games/${game_domain}/mods/${mod_id}/files.json"

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
# Usage 1: get_file_updates_json "$RAW_JSON"
# Usage 2: echo "$RAW_JSON" | get_file_updates_json
get_json_section_file_updates() {
    local input_json

    # Check if JSON was passed as a positional argument
    if [ -n "$1" ]; then
        input_json="$1"
    # Otherwise, check if data is being piped in via stdin
    elif ! [ -t 0 ]; then
        input_json=$(cat)
    else
        echo "Error: No JSON input provided to get_file_updates_json." >&2
        return 1
    fi

    # Ensure jq is installed
    if command -v jq &> /dev/null; then
        # Use -c (--compact-output) to ensure the output is raw, unformatted JSON
        echo "$input_json" | jq -c '.file_updates'
    else
        echo "Error: 'jq' is required to extract specific JSON sections. Please install jq." >&2
        return 1
    fi
}

# --- Execution Block ---
# If the script is executed directly (not sourced by another script), run the function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [ -z "$1" ]; then
        echo "Usage: $0 <MOD_ID> [GAME_DOMAIN]" >&2
        exit 1
    fi

    # Call the function with the provided command-line arguments
    get_full_json_for_one_id "$1" | get_json_section_file_updates
fi
