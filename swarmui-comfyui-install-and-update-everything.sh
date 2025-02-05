#!/usr/bin/env bash

# Add --use-sage-attention to ComfyUI args in SwarmUI

# No error handling needed since some of these commands will fail during an update

# Run swarmui's updater
./update-linuxmac.sh

git clone https://github.com/comfyanonymous/ComfyUI dlbackend/comfyui
cd dlbackend/comfyui || exit
git pull
cd ../.. || exit
pip install --upgrade pip wheel
pip install --upgrade torch torchvision torchaudio xformers sageattention
pip install --upgrade -r dlbackend/comfyui/requirements.txt
pip install --upgrade -r src/BuiltinExtensions/ComfyUIBackend/ExtraNodes/SwarmComfyExtra/requirements.txt
# For some reason, these aren't in the requirements files
pip install --upgrade onnxruntime-gpu imageio_ffmpeg

# Create symlinks
rm -r dlbackend/comfyui/output
ln -s "$(realpath ../output)" dlbackend/comfyui

DIR1="/home/zen/m2b/ai-img/igen-w8s"
cd Models/VAE || exit
ln -s "$DIR1/vae" '.'
cd ../.. || exit

cd Models/Stable-Diffusion || exit
ln -s "$DIR1/ill-ch-a" '.'
cd ../.. || exit

cd Models/Lora || exit
ln -s "$DIR1/ill-lo" '.'
cd ../.. || exit

cd Models/controlnet || exit
ln -s "$DIR1/ill-cnet" '.'
cd ../.. || exit

#####
# Install and update extensions
#####

cd dlbackend/comfyui/custom_nodes || exit

# Define extensions array
extensions=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
    "https://github.com/WASasquatch/was-node-suite-comfyui"
    "https://github.com/blepping/comfyui_jankdiffusehigh"
    "https://github.com/pamparamm/ComfyUI-ppm"
    "https://github.com/exectails/comfyui-et_dynamicprompts"
    "https://github.com/Fannovel16/comfyui_controlnet_aux"
    "https://github.com/Munkyfoot/ComfyUI-TextOverlay"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/Extraltodeus/Skimmed_CFG"
)

# Clone or update extensions
for url in "${extensions[@]}"; do
    repo_name=$(basename "$url" .git)
    if [ -d "$repo_name" ]; then
        echo "Updating $repo_name..."
        cd "$repo_name" && git pull && cd ..
    else
        echo "Cloning $repo_name..."
        git clone "$url"
    fi
done

# Collect requirements from all extensions
requirements=""
for dir in */; do
    dir=${dir%/}
    if [ -f "$dir/requirements.txt" ]; then
        echo "Processing requirements for $dir..."
        while IFS= read -r line || [ -n "$line" ]; do
            # Clean the line and extract package name
            line_clean=$(echo "$line" | sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -n "$line_clean" ]; then
                pkg_name=$(echo "$line_clean" | awk -F'[<>=!]' '{print $1}')
                requirements+="$pkg_name "
            fi
        done < "$dir/requirements.txt"
    fi
done

# Install all collected requirements
if [ -n "$requirements" ]; then
    echo "Installing packages: ${requirements}"
    # Convert to array and remove duplicates
    unique_requirements=($(echo "${requirements}" | tr ' ' '\n' | awk '!a[$0]++'))
    pip install --upgrade "${unique_requirements[@]}"
fi

# Special handling for Impact-Pack
if [ -d "ComfyUI-Impact-Pack" ]; then
    echo "Running Impact-Pack installation script..."
    cd ComfyUI-Impact-Pack && python install.py && cd ..
fi

exit 0
