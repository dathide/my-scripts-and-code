#!/bin/bash
ALL_FRAMES="$HOME/all-frames"
AMT="$HOME/amt"
IN="input-frames"
OUT_FPS=120

# How many images to process at a time. Higher=more VRAM usage
BATCH_SIZE=110

# Get the number of jpg files in the source folder
ALL_JPG_NUM=$(find "$ALL_FRAMES" -maxdepth 1 -name "*.jpg" | wc -l)

# This keeps track of which jpgs have already been copied
COUNTER=0

# Make sure the proper directories exist
mkdir -p "$AMT/$IN"

cd "$AMT/$IN" || exit
if ls ./*.jpg &> /dev/null; then
  echo "Error: $AMT/$IN shouldn't have any .jpg files in it when starting."
  exit 1; fi

SAMPLES="$AMT/results/2x/samples"
mkdir -p "$SAMPLES"
cd "$AMT/results/2x/samples" || exit
if ls ./*.jpg &> /dev/null; then
  echo "Error: $AMT/results/2x/samples shouldn't have any .jpg files in it when starting."
  exit 1; fi

# Loop until all files are processed
while [ "$COUNTER" -lt "$ALL_JPG_NUM" ]; do

    cd "$ALL_FRAMES" || exit
    # Ensure correct behavior depending on how many jpgs are left
    REMAINING=$(( ALL_JPG_NUM - COUNTER ))
    if [ $REMAINING -lt $BATCH_SIZE ]; then
        # Copy the next batch of files to the destination folder
        find . -maxdepth 1 -name "*.jpg" | sort | head -n $((COUNTER + BATCH_SIZE)) | tail -n $REMAINING | xargs -I {} cp {} "$AMT/$IN"
    else
        # Copy the next batch of files to the destination folder
        find . -maxdepth 1 -name "*.jpg" | sort | head -n $((COUNTER + BATCH_SIZE)) | tail -n $BATCH_SIZE | xargs -I {} cp {} "$AMT/$IN"
    fi

    # Use AMT to interpolate frames and save them in results/2x/samples
    cd "$AMT" || exit
    python demos/demo_2x.py -c cfgs/AMT-S.yaml -p pretrained/amt-s.pth --save_images -n 1 -r "$OUT_FPS" -i ./$IN/*.jpg

    # Delete the last result jpg file so that there aren't duplicates in the final video
    cd "$SAMPLES" || exit
    find "$SAMPLES" -name "*.jpg" | sort | tail -n 1 | xargs rm

    # Delete all but the last file in the input-frames folder
    cd "$AMT/$IN" || exit
    AMOUNT_OF_INPUT_FRAMES=$(find "$AMT/$IN" -maxdepth 1 -name "*.jpg" | wc -l)
    find "$AMT/$IN" -name "*.jpg" | sort | head -n $((AMOUNT_OF_INPUT_FRAMES - 1)) | xargs -I {} rm {}

    # Increment the COUNTER by the batch size
    COUNTER=$((COUNTER + BATCH_SIZE))
done

# Remove any leftover jpgs
cd "$AMT/$IN" || exit
rm ./*.jpg
