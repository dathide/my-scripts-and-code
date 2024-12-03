#!/bin/bash

AUR_PKGS="waydroid"

# Set up Waydroid for Android emulation
waydroid init -s GAPPS
systemctl enable --now waydroid-container.service
