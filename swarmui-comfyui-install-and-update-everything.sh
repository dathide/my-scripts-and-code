#!/usr/bin/env bash

# No error handling needed since some of these commands will fail during an update

# Run swarmui's updater
./update-linuxmac.sh

git clone https://github.com/comfyanonymous/ComfyUI dlbackend/comfyui
cd dlbackend/comfyui || exit
git pull
cd ../.. || exit
pip install --upgrade pip wheel
pip install --upgrade torch torchvision torchaudio xformers
pip install --upgrade -r dlbackend/comfyui/requirements.txt
pip install --upgrade -r src/BuiltinExtensions/ComfyUIBackend/ExtraNodes/SwarmComfyExtra/requirements.txt
# For some reason, these aren't in the requirements files
pip install onnxruntime-gpu imageio_ffmpeg

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

# Install and update extensions
cd dlbackend/comfyui/custom_nodes || exit

git clone https://github.com/ltdrdata/ComfyUI-Manager
cd ComfyUI-Manager || exit
git pull
pip install --upgrade -r requirements.txt
cd .. || exit

git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack
cd ComfyUI-Impact-Pack || exit
git pull
pip install --upgrade -r requirements.txt
python install.py
cd .. || exit

git clone https://github.com/WASasquatch/was-node-suite-comfyui
cd was-node-suite-comfyui || exit
git pull
pip install --upgrade -r requirements.txt
cd .. || exit

git clone https://github.com/blepping/comfyui_jankdiffusehigh
cd comfyui_jankdiffusehigh || exit
git pull
pip install --upgrade -r requirements.txt
cd .. || exit

git clone https://github.com/pamparamm/ComfyUI-ppm
cd ComfyUI-ppm || exit
git pull
cd .. || exit

git clone https://github.com/exectails/comfyui-et_dynamicprompts
cd comfyui-et_dynamicprompts || exit
git pull
pip install --upgrade -r requirements.txt
cd .. || exit

git clone https://github.com/Fannovel16/comfyui_controlnet_aux
cd comfyui_controlnet_aux || exit
git pull
pip install --upgrade -r requirements.txt
cd .. || exit

git clone https://github.com/Munkyfoot/ComfyUI-TextOverlay
cd ComfyUI-TextOverlay || exit
git pull
cd .. || exit

git clone https://github.com/city96/ComfyUI-GGUF
cd ComfyUI-GGUF || exit
git pull
pip install --upgrade -r requirements.txt
cd .. || exit

git clone https://github.com/Extraltodeus/Skimmed_CFG
cd Skimmed_CFG || exit
git pull
cd .. || exit

exit 0
