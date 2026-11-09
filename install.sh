#!/usr/bin/env bash
# Install the cava -> Umbriel effect-audio bridge and the fooyin border preset.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
UMBRIEL_DATA="$DATA_HOME/umbriel"
EFFECT_DIR="$UMBRIEL_DATA/effects/border/fooyin_osc"
CAVA_CONF="$UMBRIEL_DATA/cava-audio.conf"
CONFIG_FILE="$CONFIG_HOME/umbriel/config.toml"
SYSTEMD_DIR="$CONFIG_HOME/systemd/user"
UNIT="$SYSTEMD_DIR/umbriel-audio-bridge.service"

USE_SERVICE=1
for arg in "$@"; do
    case "$arg" in
        --no-service) USE_SERVICE=0 ;;
        -h|--help)
            cat <<EOF
Uso: ./install.sh [--no-service]

  --no-service   Instala los archivos pero no crea ni arranca el servicio systemd.
                 Útil en distros sin systemd; arranca el puente desde el
                 autostart de Umbriel o desde el shell.

Variables opcionales:
  XDG_DATA_HOME, XDG_CONFIG_HOME, XDG_BIN_HOME
EOF
            exit 0
            ;;
        *)
            echo "Argumento desconocido: $arg" >&2
            exit 2
            ;;
    esac
done

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33maviso:\033[0m %s\n' "$*" >&2; }

say "Comprobando dependencias"
for dep in umbriel cava python3; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "Falta '$dep' en PATH. Instálalo antes de continuar." >&2
        exit 1
    fi
done

if command -v pactl >/dev/null 2>&1; then
    if pactl info 2>/dev/null | grep -qi 'PipeWire'; then
        CAVA_BACKEND="PipeWire (pulse compatibility)"
    else
        CAVA_BACKEND="PulseAudio"
    fi
else
    CAVA_BACKEND="desconocido (cava usará 'source = auto')"
fi

say "Instalando archivos"
install -d "$EFFECT_DIR" "$BIN_DIR" "$UMBRIEL_DATA"
install -m 0755 "$ROOT/bin/umbriel-audio-bridge" "$BIN_DIR/umbriel-audio-bridge"
install -m 0644 "$ROOT/effects/border/fooyin_osc/effect.toml" "$EFFECT_DIR/effect.toml"
install -m 0644 "$ROOT/effects/border/fooyin_osc/shader.glsl" "$EFFECT_DIR/shader.glsl"
install -m 0644 "$ROOT/cava/cava-audio.conf" "$CAVA_CONF"

if (( USE_SERVICE )); then
    if ! systemctl --user show-environment >/dev/null 2>&1; then
        warn "systemd de usuario no disponible; se omite el servicio."
        USE_SERVICE=0
    fi
fi

if (( USE_SERVICE )); then
    say "Instalando servicio systemd de usuario"
    install -d "$SYSTEMD_DIR"
    python3 - "$ROOT/systemd/umbriel-audio-bridge.service.in" "$UNIT" \
        "$BIN_DIR/umbriel-audio-bridge" "$CAVA_CONF" <<'PY'
import pathlib
import sys

template, destination, binary, cava_conf = sys.argv[1:]
text = pathlib.Path(template).read_text()
text = text.replace("@BIN@", binary).replace("@CAVA_CONF@", cava_conf)
pathlib.Path(destination).write_text(text)
PY
    systemctl --user daemon-reload
    systemctl --user enable --now umbriel-audio-bridge.service
    say "Servicio activo: $(systemctl --user is-active umbriel-audio-bridge.service)"
else
    warn "Arranca el puente manualmente:"
    echo "    $BIN_DIR/umbriel-audio-bridge"
    warn "O añádelo al autostart de Umbriel:"
    echo "    [general]"
    echo "    autostart = [\"dms\", \"$BIN_DIR/umbriel-audio-bridge\"]"
fi

if [[ -f "$CONFIG_FILE" ]] && grep -Fq "$EFFECT_DIR/effect.toml" "$CONFIG_FILE"; then
    INCLUDE_STATUS="ya incluido en $CONFIG_FILE"
else
    INCLUDE_STATUS="pendiente de añadir a $CONFIG_FILE"
fi

cat <<EOF

$(printf '\033[1;32mInstalación completada\033[0m')

Backend de audio detectado: $CAVA_BACKEND
Puente:     $BIN_DIR/umbriel-audio-bridge
Cava conf:  $CAVA_CONF
Preset:     $EFFECT_DIR/effect.toml
Include:    $INCLUDE_STATUS

Añade esto a $CONFIG_FILE (si [include] ya existe, añade solo la ruta
a su array "files" en lugar de repetir la tabla):

[include]
files = ["$EFFECT_DIR/effect.toml"]

[[window_rule]]
match.app_id = "^org[.]fooyin[.]fooyin$"
border_effect = "fooyin_osc"

Después:

  umbriel config validate
  umbriel effects
  systemctl --user status umbriel-audio-bridge

El borde se dibuja cuando fooyin tiene el foco. Para verlo siempre:

  [effects]
  border_unfocused = true

Prueba inmediata sin editar la config (con el preset ya incluido):

  umbriel msg effect-border-set fooyin_osc

Logs del puente:

  journalctl --user -u umbriel-audio-bridge -f

Para depurar el flujo de audio:

  UMBRIEL_AUDIO_DEBUG=1 $BIN_DIR/umbriel-audio-bridge

EOF
