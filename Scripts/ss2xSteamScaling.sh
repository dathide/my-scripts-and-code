#!/bin/bash
cp /usr/share/applications/steam.desktop /home/$USER/.local/share/applications/
sed -i 's#/usr/bin/steam-runtime %U#GDK_SCALE=2 steam#' /home/$USER/.local/share/applications/steam.desktop
# Reload .desktop files
kbuildsycoca5
