# Umbriel + fooyin: borde audio-reactivo

Paquete portable para reproducir desde cero un efecto de borde audio-reactivo
en Umbriel, usando **cava** como analizador y un pequeño puente que habla el
protocolo `effect-audio` v2 del compositor.

No depende de DMS ni de Noctalia: solo de Umbriel, cava y Python 3.

```
PipeWire / PulseAudio
        │
        ▼
      cava  (64 bandas, 30 fps, salida raw ASCII)
        │
        ▼
umbriel-audio-bridge  (Python, snapshots JSON por el socket Unix)
        │
        ▼
$UMBRIEL_SOCKET  ──►  shader fooyin_osc  ──►  borde de la ventana de fooyin
```

## Estructura

```
umbriel-fooyin-audio-border/
├── install.sh
├── uninstall.sh
├── README.md
├── bin/
│   └── umbriel-audio-bridge        # cava -> effect-audio v2
├── cava/
│   └── cava-audio.conf             # instancia privada de cava
├── effects/
│   └── border/
│       └── fooyin_osc/
│           ├── effect.toml         # preset de Umbriel (kind = "border")
│           └── shader.glsl         # osciloscopio de 64 bandas
├── systemd/
│   └── umbriel-audio-bridge.service.in
└── config/
    └── umbriel-snippet.toml        # fragmento para config.toml
```

## Requisitos

- **Umbriel** 0.1 o posterior, con soporte de efectos (`umbriel effects`).
- **cava** con salida `raw` (paquete `cava`).
- **Python 3** (solo biblioteca estándar).
- Servidor de audio: PulseAudio o PipeWire. El config usa `method = pulse`,
  que funciona con PipeWire a través de `pipewire-pulse`. Para el backend
  nativo de PipeWire cambia a `method = pipewire`.
- **systemd de usuario** para el servicio. Si no lo hay, `install.sh
  --no-service` instala los archivos y el README explica cómo arrancarlo.
- **fooyin** con `app_id` `org.fooyin.fooyin`. Para otra aplicación cambia
  `match.app_id` en la regla de ventana.
- El shader usa `umbriel_audio_spectrum()`, la API pública documentada.

Paquetes orientativos:

| Distro | Paquetes |
|---|---|
| Arch | `umbriel cava python` |
| Debian/Ubuntu | `umbriel cava python3` |
| Fedora | `umbriel cava python3` |
| NixOS | `umbriel cava python3` en el perfil del usuario |

## Instalación

```bash
git clone https://github.com/Jolmas/Fooyin-Shader-Umbriel.git
cd Fooyin-Shader-Umbriel
chmod +x install.sh
./install.sh
```

El instalador:

1. copia el puente a `~/.local/bin/`;
2. instala el preset en `~/.local/share/umbriel/effects/border/fooyin_osc/`;
3. instala `~/.local/share/umbriel/cava-audio.conf`;
4. crea y arranca `~/.config/systemd/user/umbriel-audio-bridge.service`
   (habilitado en `umbriel-session.target`);
5. imprime el fragmento exacto que falta añadir a tu configuración.

Sin systemd:

```bash
./install.sh --no-service
```

## Configurar Umbriel

Añade el include y la regla a `~/.config/umbriel/config.toml`:

```toml
[include]
files = ["/home/TU_USUARIO/.local/share/umbriel/effects/border/fooyin_osc/effect.toml"]

[[window_rule]]
match.app_id = "^org[.]fooyin[.]fooyin$"
border_effect = "fooyin_osc"
```

Si ya existe una tabla `[include]`, añade solo la ruta a su array `files`.
Si ya existe una `[[window_rule]]` para fooyin, añade `border_effect` a esa
regla.

Valida y comprueba:

```bash
umbriel config validate
umbriel effects
umbriel windows --json
```

En `umbriel effects` debe aparecer:

```
fooyin_osc    border    compiled
```

y la ventana de fooyin debe tener `border = fooyin_osc` con origen `rule`.

Por defecto el efecto se dibuja **solo cuando fooyin tiene el foco**. Para
mantenerlo siempre visible:

```toml
[effects]
border_unfocused = true
```

Como solo fooyin tiene `border_effect`, el resto de ventanas no muestran nada.

### Probar sin editar la configuración

Con el preset ya incluido:

```bash
umbriel msg effect-border-set fooyin_osc
umbriel msg effect-border-toggle
umbriel msg effect-border-reset
```

## Verificación

```bash
systemctl --user status umbriel-audio-bridge
journalctl --user -u umbriel-audio-bridge -f
```

Debe aparecer `connected to /run/user/.../umbriel-wayland-0.sock` una vez y
ningún `feed lost`. Con música sonando, el haz del borde inferior de fooyin
oscila. El shader solo anima el borde inferior y algo el superior: su
`EDGE_MASK` da peso 1.0 abajo, 0.1 arriba y 0 a izquierda/derecha.

Depuración del flujo de audio:

```bash
systemctl --user stop umbriel-audio-bridge
UMBRIEL_AUDIO_DEBUG=1 ~/.local/bin/umbriel-audio-bridge
```

Con `UMBRIEL_AUDIO_DEBUG=1` imprime cada 2 s cuántos snapshots envió y el
valor máximo de banda.

## Ajustes

| Qué | Dónde | Notas |
|---|---|---|
| Sensibilidad | `sensitivity` en `cava-audio.conf` | 250 por defecto; súbelo si el borde se mueve poco |
| Suavizado | bloque `[smoothing]` | `gravity` alto = caída más rápida |
| FPS del análisis | `framerate` | 30 por defecto; 20–24 baja CPU |
| Amplitud en el shader | `UMBRIEL_AUDIO_GAIN` | 3.0 por defecto; añade `Environment="UMBRIEL_AUDIO_GAIN=4"` al servicio |
| Backend de audio | `method` | `pulse` (compatible) o `pipewire` (nativo) |
| Ruta de cava | `UMBRIEL_CAVA_BIN` | Útil en NixOS o si `cava` no está en el `PATH` del servicio |
| Movimiento continuo | `animated` en `effect.toml` | `false` reacciona al audio sin animación temporal; `true` anima y usa más GPU |
| Espacio del borde | `padding` en `effect.toml` | 24 reserva sitio para el trazo |
| Colores del tema | `palette = true` en `effect.toml` | Usa `umbriel_palette_at()` |
| Límite de frames | `[effects] max_fps = 30` | Reduce GPU si `animated = true` |

## Portabilidad

- **Rutas**: el instalador respeta `XDG_DATA_HOME`, `XDG_CONFIG_HOME` y
  `XDG_BIN_HOME`. El servicio se genera con rutas absolutas.
- **Socket**: el puente usa `UMBRIEL_SOCKET`; si no existe, prueba
  `$XDG_RUNTIME_DIR/umbriel-$WAYLAND_DISPLAY.sock` y luego cualquier
  `umbriel-*.sock`. No depende de `WAYLAND_DISPLAY` dentro del servicio.
- **systemd**: la unidad se engancha a `umbriel-session.target` con
  `PartOf` y `BindsTo`. En distros sin systemd usa `--no-service` y arranca
  el puente desde el autostart de Umbriel:
  ```toml
  [general]
  autostart = ["dms", "/home/TU_USUARIO/.local/bin/umbriel-audio-bridge"]
  ```
- **Un solo productor**: Umbriel acepta un único productor `effect-audio`.
  Para el puente antes de arrancar otro (DMS, Noctalia, etc.). Si ves
  `feed lost: ... already ...`, hay otro proceso ocupando el feed.
- **Otra app**: cambia `match.app_id` y el nombre del preset si quieres.
  El shader debe seguir siendo `kind = "border"` y definir
  `vec4 border(vec2 uv)`.
- **Otra versión de Umbriel**: si `umbriel_audio_spectrum()` no existe,
  actualiza Umbriel; el shader evita deliberadamente helpers internos.

## Solución de problemas

| Síntoma | Causa probable | Solución |
|---|---|---|
| `fooyin_osc` en estado `failed` | Error de compilación GLSL | Mira el log de Umbriel; valida `shader.glsl` |
| `fooyin_osc` en estado `inert` | Falta el shader o la ruta no existe | Reinstala o corrige `shader` en `effect.toml` |
| El preset no aparece | Falta el include | Añade la ruta a `[include] files` y guarda |
| La ventana no cambia | La regla no coincide | `umbriel windows --json` para ver el `app_id` real |
| No se ve nada | La ventana no tiene el foco | Enfoca fooyin o usa `border_unfocused = true` |
| Se ve una línea fija | No hay feed de audio | `systemctl status`, `journalctl`, `UMBRIEL_AUDIO_DEBUG=1` |
| El feed se cae | Otro productor o Umbriel reiniciado | Para el otro productor; el puente reconecta solo |
| cava no arranca | Falta cava o el backend de audio | Instala cava; prueba `method = pulse` |
| Mucha CPU | 64 bandas a 30 fps | Baja `framerate` a 20–24 |

## Desinstalar

```bash
cd ~/git/umbriel-fooyin-audio-border
./uninstall.sh
```

Después elimina a mano el include y la regla de
`~/.config/umbriel/config.toml` y ejecuta `umbriel config validate`.
