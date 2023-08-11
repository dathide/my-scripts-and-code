#!/bin/bash

CRF=27
PRESET=6

function ffmpeg_cmd() {
    taskset -c 0-7 ffmpeg -hwaccel auto -threads 8 -i "[SubsPlease] Jujutsu Kaisen - 01v2 (720p) [9C673C00].mkv" -c:v libsvtav1 -crf "$CRF" -preset "$PRESET" -svtav1-params lp=8 -c:a libopus -b:a 96000 -ac 2 -mapping_family 1 -c:s copy -pix_fmt yuv420p10le -ss 0 -t 54.971 -metadata:s title= -metadata:s BPS-eng= -metadata:s DURATION-eng= -metadata:s _STATISTICS_TAGS-eng= -metadata:s _STATISTICS_WRITING_DATE_UTC-eng= -metadata:s NUMBER_OF_BYTES-eng= -metadata:s NUMBER_OF_FRAMES-eng= -metadata:s _STATISTICS_WRITING_APP-eng= -metadata:s:v:0 details="SVT-AV1 1.4.1 CRF $CRF PRESET $PRESET" "Jujutsu Kaisen 01 720p AV1 10bit svtav1 crf$CRF p$PRESET.mkv"
}

function encode() {
    # If there are two timestamps, no need to concatenate.
    if [ $# -eq 3 ]; then
        ffmpeg_cmd "$2" "$3"
    fi
}

# First string is episode number then alternating -ss and -t values
encode "01" "0" "54.971" "145.019" "1278.903"
encode "02" "0" "345.011" "434.976" "900.024"
