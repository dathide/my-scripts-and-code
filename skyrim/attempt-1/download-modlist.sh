#!/usr/bin/env zsh

set -e

# Get script directory and set up paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOWNLOAD_DIR="$SCRIPT_DIR/downloads"
MODLIST_FILE="$SCRIPT_DIR/modlist1.list.zsh"

# Create downloads directory
mkdir -p "$DOWNLOAD_DIR"

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "Error: 'curl' is required but not installed."
    exit 1
fi

# Source the modlist
if [[ ! -f "$MODLIST_FILE" ]]; then
    echo "Error: Modlist file not found: $MODLIST_FILE"
    exit 1
fi

source "$MODLIST_FILE"

if [[ ${#mod_list[@]} -eq 0 ]]; then
    echo "Error: mod_list is empty or not defined"
    exit 1
fi

# Configuration
GAME_DOMAIN="${NEXUS_GAME_DOMAIN:-skyrimspecialedition}"  # Default to Skyrim SE

echo "=================================="
echo "Mod Download Script"
echo "Game Domain: $GAME_DOMAIN"
echo "Download Dir: $DOWNLOAD_DIR"
echo "=================================="
echo ""

# Check if we need Nexus API key (only if there are non-URL entries)
has_nexus_mods=false
for ((i=2; i<=${#mod_list[@]}; i+=2)); do
    identifier="${mod_list[$i]}"
    if [[ ! "$identifier" =~ ^https?:// ]]; then
        has_nexus_mods=true
        break
    fi
done

if [[ "$has_nexus_mods" == true ]]; then
    if [[ -z "$NEXUS_API_KEY" ]]; then
        echo "Warning: NEXUS_API_KEY not set. Nexus Mods downloads will fail."
        echo "Set it with: export NEXUS_API_KEY='your_key'"
        echo ""
    fi
fi

# Process mod_list (pairs of description and identifier)
total=$(( ${#mod_list[@]} / 2 ))
count=1

for ((i=1; i<=${#mod_list[@]}; i+=2)); do
    desc="${mod_list[$i]}"
    identifier="${mod_list[$((i+1))]}"

    echo "[$count/$total] $desc"

    # Handle direct URL downloads
    if [[ "$identifier" =~ ^https?:// ]]; then
        filename=$(basename "$identifier")
        # Remove query parameters from filename
        filename="${filename%%\?*}"
        filepath="$DOWNLOAD_DIR/$filename"

        if [[ -f "$filepath" ]]; then
            echo "  ✓ Skipping (exists): $filename"
        else
            echo "  Downloading: $filename"
            if curl -fsSL -o "$filepath" "$identifier"; then
                echo "  ✓ Complete"
            else
                echo "  ✗ Failed"
            fi
        fi

    # Handle Nexus Mods downloads
    else
        if [[ -z "$NEXUS_API_KEY" ]]; then
            echo "  ✗ Skipping (NEXUS_API_KEY not set)"
            ((count++))
            continue
        fi

        # Extract mod ID (last number in identifier)
        mod_id=$(echo "$identifier" | grep -oE '[0-9]+$')
        if [[ -z "$mod_id" ]]; then
            echo "  ✗ Error: No mod ID found in '$identifier'"
            ((count++))
            continue
        fi

        # Add dash to prefix to ensure exact matching (e.g., "Name-123" matches "Name-123-1.0.zip")
        file_prefix="${identifier}-"

        # Fetch file information from Nexus API
        api_url="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${mod_id}/files.json"

        response=$(curl -s -w "%{http_code}" -X GET "$api_url" \
            -H "accept: application/json" \
            -H "apikey: $NEXUS_API_KEY")

        http_code="${response:${#response}-3}"
        body="${response:0:${#response}-3}"

        if [[ "$http_code" -ne 200 ]]; then
            echo "  ✗ API Error (HTTP $http_code)"
            ((count++))
            continue
        fi

        # Find latest file update matching the prefix
        latest_file=$(echo "$body" | jq -r --arg prefix "$file_prefix" \
            '.file_updates | map(select(.new_file_name | startswith($prefix))) | sort_by(.uploaded_timestamp) | last')

        if [[ -z "$latest_file" ]] || [[ "$latest_file" == "null" ]]; then
            echo "  ✗ Error: No file found with prefix '$file_prefix'"
            ((count++))
            continue
        fi

        file_id=$(echo "$latest_file" | jq -r '.new_file_id')
        file_name=$(echo "$latest_file" | jq -r '.new_file_name')
        filepath="$DOWNLOAD_DIR/$file_name"

        if [[ -f "$filepath" ]]; then
            echo "  ✓ Skipping (exists): $file_name"
        else
            echo "  Found: $file_name"
            echo "  Getting download link..."

            # Fetch download link
            dl_url="https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${mod_id}/files/${file_id}/download_link.json"
            dl_response=$(curl -s -w "%{http_code}" -X GET "$dl_url" \
                -H "accept: application/json" \
                -H "apikey: $NEXUS_API_KEY")

            dl_http_code="${dl_response:${#dl_response}-3}"
            dl_body="${dl_response:0:${#dl_response}-3}"

            if [[ "$dl_http_code" -ne 200 ]]; then
                echo "  ✗ Failed to get download link (HTTP $dl_http_code)"
                ((count++))
                continue
            fi

            download_url=$(echo "$dl_body" | jq -r '.[0].URI' | tr -d '\r')

            if [[ "$download_url" == "null" ]] || [[ -z "$download_url" ]]; then
                echo "  ✗ No download URL available"
                ((count++))
                continue
            fi

            # URL-encode spaces
            download_url="${download_url// /%20}"

            echo "  Downloading..."
            if curl -fsSL -o "$filepath" "$download_url"; then
                echo "  ✓ Complete: $file_name"
            else
                echo "  ✗ Download failed"
                rm -f "$filepath"  # Clean up partial file
            fi
        fi
    fi

    echo ""
    ((count++))
done

echo "=================================="
echo "Download process finished!"
echo "Files saved to: $DOWNLOAD_DIR"
echo "=================================="
