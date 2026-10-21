#!/bin/bash
# Boot script: start the desktop first, then run Hermes in the foreground.
# Hermes and the desktop live in the SAME container on purpose: the
# computer_use driver can only drive the display of the machine it runs on.
export HOME=/home/user
export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"
export PATH="$HOME/.local/bin:$HOME/.venv/bin:$PATH"
cd "$HOME"

# ---------------------------------------------------------------- desktop --
mkdir -p "$HOME/.vnc"
VNC_PASS="${VNC_PASSWORD:-hermes}"
printf '%s' "$VNC_PASS" | vncpasswd -f > "$HOME/.vnc/passwd"
chmod 600 "$HOME/.vnc/passwd"

cat > "$HOME/.vnc/xstartup" <<'XEOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec dbus-launch --exit-with-session startxfce4
XEOF
chmod +x "$HOME/.vnc/xstartup"

# Kill any stale display left over from a previous boot in this container.
vncserver -kill :1 >/dev/null 2>&1 || true
rm -f /tmp/.X1-lock "$HOME/.vnc/"*-desktop.pid 2>/dev/null || true

vncserver :1 -geometry 1280x800 -depth 24 -rfbport 5901 \
    -PasswordFile "$HOME/.vnc/passwd" || true

# Browser access to the desktop: http://<domain>/vnc.html
websockify --web /usr/share/novnc 6080 localhost:5901 &

# -------------------------------------------------------------------- ssh --
# Terminal access from Termius etc. In Railway: Settings -> Networking ->
# TCP Proxy -> internal port 22. Login: user "user", password $SSH_PASSWORD
# (falls back to the VNC password, then to "hermes").
SSH_PASS="${SSH_PASSWORD:-${VNC_PASSWORD:-hermes}}"
echo "user:${SSH_PASS}" | sudo chpasswd
sudo mkdir -p /var/run/sshd
sudo ssh-keygen -A >/dev/null 2>&1 || true
sudo /usr/sbin/sshd || true

# ----------------------------------------------------------------- hermes --
mkdir -p "$HOME/.hermes"
{
    echo "RIVER_API_KEY=${RIVER_API_KEY:-}"
    echo "OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}"
    echo "TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}"
    if [ -n "${TELEGRAM_ALLOWED_USERS:-}" ]; then
        echo "TELEGRAM_ALLOWED_USERS=${TELEGRAM_ALLOWED_USERS}"
    fi
} > "$HOME/.hermes/.env"

# Provider priority: River (paid, Sam's choice) when its key is present,
# otherwise the free OpenRouter vision model.
if [ -n "${RIVER_API_KEY:-}" ]; then
    DEF_PROVIDER="river"
    DEF_MODEL="nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4"
else
    DEF_PROVIDER="openrouter"
    DEF_MODEL="nvidia/nemotron-3.5-super-vl:free"
fi

cat > "$HOME/.hermes/config.yaml" <<YEOF
model:
  provider: ${DEF_PROVIDER}
  default: ${DEF_MODEL}
providers:
  river:
    base_url: https://api.river.ai/v1
    key_env: RIVER_API_KEY
    models:
      - nvidia/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-NVFP4
      - deepseek-ai/DeepSeek-V4.1-Flash
      - zai-org/GLM-5.3-Flash
  openrouter:
    key_env: OPENROUTER_API_KEY
    base_url: https://openrouter.ai/api/v1
    models:
      - nvidia/nemotron-3.5-super-vl:free
platform_toolsets:
  telegram:
    - hermes-telegram
    - computer_use
YEOF

# Fallback: if the driver did not make it into the image, fetch it now.
if ! command -v cua-driver >/dev/null 2>&1; then
    echo "cua-driver missing - installing..."
    hermes computer-use install || true
fi

echo "=== Desktop is live on port 6080 (open /vnc.html) ==="
echo "=== Starting Hermes gateway ==="
exec hermes gateway run
