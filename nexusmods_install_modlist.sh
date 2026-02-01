#!/bin/bash
curl -H "$NEXUSMODS_API_KEY" \
  "https://api.nexusmods.com/v1/games/skyrimspecialedition/mods/266/files.json" | \
  jq '.files[] | {id: .file_id, name: .name, filename: .file_name, version: .version}'
