# ============================================================================
# Google Antigravity IDE + Chrome — Dockerized with noVNC GUI Access
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
    x11-xserver-utils x11-utils \
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
    python3 python3-numpy dos2unix \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ── Google Chrome ─────────────────────────────────────────────────────────
RUN wget -qO - https://dl.google.com/linux/linux_signing_key.pub | \
    gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
    > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# ── Google Antigravity IDE ────────────────────────────────────────────────
RUN curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
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
             ${HOME}/.fluxbox \
             ${HOME}/workspace && \
    chown -R ${USERNAME}:${USERNAME} ${HOME}

# ── All scripts created via printf (immune to Windows CRLF) ──────────────

# Antigravity launcher (bypasses WSL-checking wrapper)
RUN printf '#!/bin/bash\nexport DONT_PROMPT_WSL_INSTALL=1\nexport ELECTRON_DISABLE_SANDBOX=1\nexport ELECTRON_NO_SANDBOX=1\nexport XDG_RUNTIME_DIR=/tmp/runtime-developer\n/usr/share/antigravity/antigravity --no-sandbox --disable-gpu-sandbox "$@" &\n' > /usr/local/bin/launch-antigravity.sh && chmod +x /usr/local/bin/launch-antigravity.sh

# Chrome launcher
RUN printf '#!/bin/bash\nexport XDG_RUNTIME_DIR=/tmp/runtime-developer\ngoogle-chrome-stable --no-sandbox --disable-gpu --disable-dev-shm-usage "$@" &\n' > /usr/local/bin/launch-chrome.sh && chmod +x /usr/local/bin/launch-chrome.sh

# Clipboard helpers
RUN printf '#!/bin/bash\nxclip -selection clipboard -o 2>/dev/null\n' > /usr/local/bin/clip-paste && \
    printf '#!/bin/bash\nxclip -selection clipboard 2>/dev/null\n' > /usr/local/bin/clip-copy && \
    chmod +x /usr/local/bin/clip-paste /usr/local/bin/clip-copy

# Fluxbox menu
RUN printf '[begin] (Antigravity Desktop)\n  [exec] (Antigravity IDE) {/usr/local/bin/launch-antigravity.sh}\n  [exec] (Google Chrome) {/usr/local/bin/launch-chrome.sh}\n  [exec] (Terminal) {xterm}\n  [exec] (File Manager) {pcmanfm --no-desktop}\n  [separator]\n  [restart] (Restart Fluxbox)\n  [exit] (Exit)\n[end]\n' > ${HOME}/.fluxbox/menu

# Fluxbox keys
RUN printf 'OnDesktop Mouse3 :RootMenu\nMod1 F4 :Close\nMod1 Tab :NextWindow {groups} (workspace=[current])\nMod1 F9 :Minimize\nMod1 F10 :Maximize\nMod1 Left :MoveLeft 20\nMod1 Right :MoveRight 20\nMod1 Up :MoveUp 20\nMod1 Down :MoveDown 20\nControl Mod1 Left :PrevWorkspace\nControl Mod1 Right :NextWorkspace\n' > ${HOME}/.fluxbox/keys

# Fluxbox startup
RUN printf '#!/bin/bash\nfbsetroot -solid "#1a1a2e"\nif [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then\n    eval $(dbus-launch --sh-syntax)\n    export DBUS_SESSION_BUS_ADDRESS\nfi\nxset r on\nxset r rate 300 30\nautocutsel -s PRIMARY -fork\nautocutsel -s CLIPBOARD -fork\n(sleep 5 && /usr/local/bin/launch-antigravity.sh) &\nexec fluxbox\n' > ${HOME}/.fluxbox/startup && chmod +x ${HOME}/.fluxbox/startup

RUN chown -R ${USERNAME}:${USERNAME} ${HOME}/.fluxbox

# XTerm config
RUN printf 'xterm*faceName: DejaVu Sans Mono\nxterm*faceSize: 12\nxterm*background: #1a1a2e\nxterm*foreground: #e0e0e0\nxterm*cursorColor: #00ff88\nxterm*selectToClipboard: true\nxterm*scrollBar: false\nxterm*saveLines: 10000\nxterm*geometry: 110x30\nxterm*utf8: 2\nxterm*locale: true\nxterm*metaSendsEscape: true\nxterm*translations: #override \\\\n\\\n    Ctrl Shift <Key>C: copy-selection(CLIPBOARD) \\\\n\\\n    Ctrl Shift <Key>V: insert-selection(CLIPBOARD) \\\\n\\\n    Shift <Key>Insert: insert-selection(CLIPBOARD) \\\\n\\\n    Ctrl <Key>+: larger-vt-font() \\\\n\\\n    Ctrl <Key>-: smaller-vt-font()\n' > ${HOME}/.Xresources && chown ${USERNAME}:${USERNAME} ${HOME}/.Xresources

# Bash profile
RUN printf '\nalias ccopy="xclip -selection clipboard"\nalias cpaste="xclip -selection clipboard -o"\nPS1='"'"'\\[\\e[0;32m\\]\\u\\[\\e[0m\\]@\\[\\e[0;36m\\]antigravity\\[\\e[0m\\]:\\[\\e[0;33m\\]\\w\\[\\e[0m\\]\\$ '"'"'\nif [ -n "$DISPLAY" ]; then xset r on 2>/dev/null; xset r rate 300 30 2>/dev/null; fi\n' >> ${HOME}/.bashrc && chown ${USERNAME}:${USERNAME} ${HOME}/.bashrc

# Entrypoint script
RUN printf '#!/bin/bash\nset -e\nchmod 1777 /dev/shm\nexport XDG_RUNTIME_DIR=/tmp/runtime-developer\nmkdir -p $XDG_RUNTIME_DIR\nchmod 700 $XDG_RUNTIME_DIR\nchown developer:developer $XDG_RUNTIME_DIR\nchown -R developer:developer /home/developer/.config 2>/dev/null || true\nchown -R developer:developer /home/developer/.antigravity 2>/dev/null || true\nchown -R developer:developer /home/developer/.cache 2>/dev/null || true\nchown -R developer:developer /home/developer/.local 2>/dev/null || true\nchown -R developer:developer /home/developer/.vnc 2>/dev/null || true\nchown -R developer:developer /home/developer/.fluxbox 2>/dev/null || true\nmkdir -p /var/run/dbus\ndbus-daemon --system --fork 2>/dev/null || true\nexec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf\n' > /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

# Supervisor config
RUN printf '[supervisord]\nnodaemon=true\nuser=root\nlogfile=/var/log/supervisord.log\npidfile=/var/run/supervisord.pid\n\n[program:xvfb]\ncommand=Xvfb %%(ENV_DISPLAY)s -screen 0 %%(ENV_RESOLUTION)s -ac +extension GLX +render -noreset\nautorestart=true\npriority=10\n\n[program:xrdb]\ncommand=bash -c "sleep 2 && xrdb -merge /home/developer/.Xresources && xset r on && xset r rate 300 30"\nuser=developer\nenvironment=DISPLAY="%%(ENV_DISPLAY)s",HOME="/home/developer"\nautorestart=false\nstartsecs=0\npriority=15\n\n[program:fluxbox]\ncommand=bash -c "sleep 3 && exec /home/developer/.fluxbox/startup"\nuser=developer\nenvironment=DISPLAY="%%(ENV_DISPLAY)s",HOME="/home/developer",XDG_RUNTIME_DIR="/tmp/runtime-developer",DONT_PROMPT_WSL_INSTALL="1",ELECTRON_DISABLE_SANDBOX="1",ELECTRON_NO_SANDBOX="1"\nautorestart=true\npriority=20\n\n[program:x11vnc]\ncommand=x11vnc -display %%(ENV_DISPLAY)s -rfbport %%(ENV_VNC_PORT)s -rfbauth /home/developer/.vnc/passwd -shared -forever -repeat -noxdamage -noxfixes -noxrecord -xkb\nautorestart=true\npriority=30\nstartsecs=3\n\n[program:novnc]\ncommand=websockify --web=/usr/share/novnc/ %%(ENV_NOVNC_PORT)s localhost:%%(ENV_VNC_PORT)s\nautorestart=true\npriority=40\nstartsecs=3\n' > /etc/supervisor/conf.d/supervisord.conf

# ── Fix any CRLF that might have leaked in ────────────────────────────────
RUN dos2unix /usr/local/bin/*.sh /home/developer/.fluxbox/startup /etc/supervisor/conf.d/supervisord.conf 2>/dev/null || true

VOLUME /dev/shm
EXPOSE 6080 5900

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:6080/ || exit 1

CMD ["/usr/local/bin/entrypoint.sh"]
