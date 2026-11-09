#!/usr/bin/env bash
# Remove the installed files and the systemd user service.
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
UMBRIEL_DATA="$DATA_HOME/umbriel"
EFFECT_DIR="$UMBRIEL_DATA/effects/border/fooyin_osc"
UNIT="$CONFIG_HOME/systemd/user/umbriel-audio-bridge.service"

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

for arg in "$@"; do
    case "$arg" in
        -h|--help)
            cat <<EOF
Uso: ./uninstall.sh

Elimina el binario, el preset, la configuración de cava y el servicio
systemd. No modifica ~/.config/umbriel/config.toml: elimina a mano el
include y la [[window_rule]] de fooyin.
EOF
            exit 0
            ;;
        *)
            echo "Argumento desconocido: $arg" >&2
            exit 2
            ;;
    esac
done

if systemctl --user show-environment >/dev/null 2>&1; then
    say "Parando y deshabilitando el servicio"
    systemctl --user disable --now umbriel-audio-bridge.service 2>/dev/null || true
    rm -f "$UNIT"
    systemctl --user daemon-reload
fi

say "Eliminando archivos instalados"
rm -f "$BIN_DIR/umbriel-audio-bridge"
rm -rf "$EFFECT_DIR"
rm -f "$UMBRIEL_DATA/cava-audio.conf"

cat <<EOF

$(printf '\033[1;32mDesinstalación completada\033[0m')

Queda pendiente quitar a mano de $CONFIG_HOME/umbriel/config.toml:

  files = ["$EFFECT_DIR/effect.toml"]

y la regla:

  [[window_rule]]
  match.app_id = "^org[.]fooyin[.]fooyin$"
  border_effect = "fooyin_osc"

Luego ejecuta:

  umbriel config validate
  umbriel effects
EOF
