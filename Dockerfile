# ============================================================================
# Google Antigravity IDE + Chrome — Dockerized with noVNC GUI Access
# ============================================================================
# PRODUCTION VERSION — All issues resolved:
#   ✅ WSL2 kernel detection bypassed
#   ✅ /dev/shm permissions fixed at boot
#   ✅ Right-click menu launches Antigravity & Chrome correctly
#   ✅ Resolution optimized for noVNC (1366x768)
#   ✅ Clipboard sync via autocutsel
#   ✅ Config directory ownership auto-fixed on boot
#   ✅ D-Bus session properly initialized
# ============================================================================
# Access: http://localhost:6080/vnc.html  |  Password: antigravity
# ============================================================================

FROM ubuntu:22.04

LABEL maintainer="antigravity-docker"
LABEL description="Google Antigravity IDE with Google Chrome, accessible via noVNC"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Kolkata

# ── System packages ───────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    xvfb x11vnc fluxbox \
    novnc websockify \
    xterm pcmanfm \
    autocutsel xclip xdotool xsel \
    dbus dbus-x11 at-spi2-core \
    supervisor wget curl gnupg2 \
    ca-certificates apt-transport-https \
    software-properties-common procps \
    libgtk-3-0 libnotify4 libnss3 libxss1 \
    libxtst6 libatspi2.0-0 libasound2 \
    libdrm2 libgbm1 libxshmfence1 \
    libsecret-1-0 libxkbfile1 libx11-xcb1 \
    libxcb-dri3-0 libxcomposite1 libxcursor1 \
    libxdamage1 libxfixes3 libxi6 libxrandr2 \
    libxrender1 libxext6 libxkbcommon0 \
    libpango-1.0-0 libcairo2 \
    fonts-liberation fonts-dejavu-core \
    fonts-noto-color-emoji fontconfig \
    net-tools locales sudo git xdg-utils \
    python3 python3-numpy \
    && rm -rf /var/lib/apt/lists/*

# ── Locale ────────────────────────────────────────────────────────────────
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ── Google Chrome ─────────────────────────────────────────────────────────
RUN wget -qO - https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
    http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# ── Google Antigravity IDE ────────────────────────────────────────────────
RUN curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
    https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ \
    antigravity-debian main" \
    > /etc/apt/sources.list.d/antigravity.list && \
    apt-get update && \
    apt-get install -y antigravity && \
    rm -rf /var/lib/apt/lists/*

# ── Non-root user ────────────────────────────────────────────────────────
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=1000

RUN groupadd --gid ${USER_GID} ${USERNAME} && \
    useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME} && \
    chmod 0440 /etc/sudoers.d/${USERNAME}

# ── Environment ───────────────────────────────────────────────────────────
ENV DISPLAY=:99
ENV RESOLUTION=1366x768x24
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV HOME=/home/${USERNAME}
ENV DONT_PROMPT_WSL_INSTALL=1
ENV ELECTRON_DISABLE_SANDBOX=1
ENV ELECTRON_NO_SANDBOX=1

# ── VNC password ──────────────────────────────────────────────────────────
ARG VNC_PASSWORD=antigravity
RUN mkdir -p ${HOME}/.vnc && \
    x11vnc -storepasswd "${VNC_PASSWORD}" ${HOME}/.vnc/passwd && \
    chown -R ${USERNAME}:${USERNAME} ${HOME}/.vnc

# ── Pre-create config directories ────────────────────────────────────────
RUN mkdir -p ${HOME}/.config/Antigravity \
             ${HOME}/.antigravity/extensions \
             ${HOME}/.config/google-chrome \
             ${HOME}/.cache \
             ${HOME}/.local/share \
             ${HOME}/workspace && \
    chown -R ${USERNAME}:${USERNAME} ${HOME}

# ── Launcher wrapper scripts (bypass the WSL-checking shell wrapper) ─────
# These call the Electron binary DIRECTLY, skipping the /usr/bin/antigravity
# shell script that does `grep -qi Microsoft /proc/version` and blocks launch.

RUN cat > /usr/local/bin/launch-antigravity.sh << 'LAUNCHEOF'
#!/bin/bash
export DONT_PROMPT_WSL_INSTALL=1
export ELECTRON_DISABLE_SANDBOX=1
export ELECTRON_NO_SANDBOX=1
export XDG_RUNTIME_DIR=/tmp/runtime-developer

# Call the Electron binary directly, bypassing the wrapper script
/usr/share/antigravity/antigravity \
    --no-sandbox \
    --disable-gpu-sandbox \
    "$@" &
LAUNCHEOF

RUN cat > /usr/local/bin/launch-chrome.sh << 'CHROMEEOF'
#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-developer

google-chrome-stable \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    "$@" &
CHROMEEOF

RUN chmod +x /usr/local/bin/launch-antigravity.sh \
             /usr/local/bin/launch-chrome.sh

# ── Fluxbox menu (uses launcher scripts) ──────────────────────────────────
RUN mkdir -p ${HOME}/.fluxbox && \
    cat > ${HOME}/.fluxbox/menu << 'EOF'
[begin] (Antigravity Desktop)
  [exec] (Antigravity IDE) {/usr/local/bin/launch-antigravity.sh}
  [exec] (Google Chrome) {/usr/local/bin/launch-chrome.sh}
  [exec] (Terminal) {xterm -fa "DejaVu Sans Mono" -fs 12 -bg "#1a1a2e" -fg "#e0e0e0" -geometry 110x30}
  [exec] (File Manager) {pcmanfm --no-desktop}
  [separator]
  [restart] (Restart Fluxbox)
  [exit] (Exit)
[end]
EOF

# ── Fluxbox startup ──────────────────────────────────────────────────────
RUN cat > ${HOME}/.fluxbox/startup << 'STARTEOF'
#!/bin/bash

# Desktop background
fbsetroot -solid "#1a1a2e"

# D-Bus session bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Clipboard sync (bridges X selections with VNC clipboard)
autocutsel -s PRIMARY -fork
autocutsel -s CLIPBOARD -fork

# Auto-start Antigravity
(sleep 5 && /usr/local/bin/launch-antigravity.sh) &

# Fluxbox (must be last)
exec fluxbox
STARTEOF
RUN chmod +x ${HOME}/.fluxbox/startup && \
    chown -R ${USERNAME}:${USERNAME} ${HOME}/.fluxbox

# ── XTerm config ──────────────────────────────────────────────────────────
RUN cat > ${HOME}/.Xresources << 'EOF'
xterm*faceName: DejaVu Sans Mono
xterm*faceSize: 12
xterm*background: #1a1a2e
xterm*foreground: #e0e0e0
xterm*cursorColor: #00ff88
xterm*selectToClipboard: true
xterm*scrollBar: false
xterm*saveLines: 10000
xterm*geometry: 110x30
EOF
RUN chown ${USERNAME}:${USERNAME} ${HOME}/.Xresources

# ── Entrypoint ────────────────────────────────────────────────────────────
RUN cat > /usr/local/bin/entrypoint.sh << 'ENTRYEOF'
#!/bin/bash
set -e

# Fix /dev/shm permissions (CRITICAL for Chrome/Electron)
chmod 1777 /dev/shm

# XDG runtime directory
export XDG_RUNTIME_DIR=/tmp/runtime-developer
mkdir -p $XDG_RUNTIME_DIR
chmod 700 $XDG_RUNTIME_DIR
chown developer:developer $XDG_RUNTIME_DIR

# Fix ownership of config dirs (volumes may mount as root)
chown -R developer:developer /home/developer/.config 2>/dev/null || true
chown -R developer:developer /home/developer/.antigravity 2>/dev/null || true
chown -R developer:developer /home/developer/.cache 2>/dev/null || true
chown -R developer:developer /home/developer/.local 2>/dev/null || true
chown -R developer:developer /home/developer/.vnc 2>/dev/null || true
chown -R developer:developer /home/developer/.fluxbox 2>/dev/null || true

# System D-Bus
mkdir -p /var/run/dbus
dbus-daemon --system --fork 2>/dev/null || true

# Launch supervisor
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
ENTRYEOF
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Supervisor ────────────────────────────────────────────────────────────
RUN cat > /etc/supervisor/conf.d/supervisord.conf << 'SUPERVISOREOF'
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=Xvfb %(ENV_DISPLAY)s -screen 0 %(ENV_RESOLUTION)s -ac +extension GLX +render -noreset
autorestart=true
priority=10

[program:xrdb]
command=bash -c "sleep 2 && xrdb -merge /home/developer/.Xresources"
user=developer
environment=DISPLAY="%(ENV_DISPLAY)s",HOME="/home/developer"
autorestart=false
startsecs=0
priority=15

[program:fluxbox]
command=bash -c "sleep 3 && exec /home/developer/.fluxbox/startup"
user=developer
environment=DISPLAY="%(ENV_DISPLAY)s",HOME="/home/developer",XDG_RUNTIME_DIR="/tmp/runtime-developer",DONT_PROMPT_WSL_INSTALL="1",ELECTRON_DISABLE_SANDBOX="1",ELECTRON_NO_SANDBOX="1"
autorestart=true
priority=20

[program:x11vnc]
command=x11vnc -display %(ENV_DISPLAY)s -rfbport %(ENV_VNC_PORT)s -rfbauth /home/developer/.vnc/passwd -shared -forever -noxdamage -noxfixes -noxrecord
autorestart=true
priority=30
startsecs=3

[program:novnc]
command=websockify --web=/usr/share/novnc/ %(ENV_NOVNC_PORT)s localhost:%(ENV_VNC_PORT)s
autorestart=true
priority=40
startsecs=3
SUPERVISOREOF

VOLUME /dev/shm
EXPOSE 6080 5900

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

CMD ["/usr/local/bin/entrypoint.sh"]
