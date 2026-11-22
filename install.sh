#!/bin/sh
# Instala o actualiza el plasmoide para el usuario actual.
set -e
cd "$(dirname "$0")"
kpackagetool6 -t Plasma/Applet --upgrade package >/dev/null 2>&1 \
    || kpackagetool6 -t Plasma/Applet --install package
echo "Listo. Si ya estaba en el panel, reinicia Plasma: systemctl --user restart plasma-plasmashell"
