#!/usr/bin/env bash

# Required packages: pyenv pyenv-virtualenv
# Modify .bashrc using pyenv init bash
# Commands that need to be run beforehand:
# pyenv install 3.11
# pyenv virtualenv 3.11 swarmui

# I add the following to my .zshrc:
# alias swarmuiu="cd /home/zen/m2b/ai-img/swarmui/ && sh /home/zen/m2a/fillets/linux/scripts/swarmui-comfyui-install-and-update-everything.sh && cd /home/zen/m2b/ai-img/swarmui/ && sh launch-linux.sh"
# alias swarmui="cd /home/zen/m2b/ai-img/swarmui/ && sh launch-linux.sh"

# Function to handle errors
handle_error() {
  # Shellcheck warning can be ignored
  local status=$?
  local last_command="${BASH_COMMAND[@]}"
  echo "Error: Command failed: $last_command (exit code: $status)" >&2
  exit "$status"
}

# Set the trap to call handle_error on ERR (any command returning non-zero exit status)
trap handle_error ERR

# Check if an argument is provided
if [ -z "$1" ]; then
  echo "Error: No directory provided."
  echo "Usage: $0 <directory>"
  exit 1
fi

# Check if the provided argument is a directory
if [ ! -d "$1" ]; then
  echo "Error: '$1' is not a directory."
  exit 1
fi

# Change directory
cd "$1" # trap handles failures

# Optional: Print the current working directory after changing
echo "Successfully changed directory to: $(pwd)"

# Clone the SwarmUI repository, navigate, and run the script
echo "Cloning SwarmUI..."
git clone https://github.com/mcmonkeyprojects/SwarmUI swarmui
echo "Cloning successful. Navigating to SwarmUI directory..."
cd swarmui # trap handles failures
echo "Setting up access to the pyenv virtualenv..."
pyenv local swarmui
echo "Checking for script..."
SCRIPT2="/home/zen/m2a/fillets/linux/scripts/swarmui-comfyui-install-and-update-everything.sh"
[ -f $SCRIPT2 ] # Make sure script exists.
[ -x $SCRIPT2 ] # Make sure script is executable.
$SCRIPT2
echo "SwarmUI setup complete."
echo "Make sure to customize settings during install and skip installing ComfyUI."
echo "Once in the UI, add ComfyUI in the Server/Backends tab,"
echo "set StartScript to dlbackend/comfyui/main.py and click save."

# Remove the trap before exiting to prevent it from triggering on the final exit
trap - ERR

exit 0
