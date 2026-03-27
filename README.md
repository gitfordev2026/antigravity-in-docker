# 🚀 Google Antigravity IDE — Dockerized with GUI

Run **Google Antigravity IDE** + **Google Chrome** inside a Docker container, accessible from your browser via **noVNC**.

> **Zero host-side config needed.** Build once, run anywhere.

---

## 📋 What's Inside the Container

| Component              | Purpose                                          |
|------------------------|--------------------------------------------------|
| **Google Antigravity** | AI-powered agentic IDE (VS Code fork by Google)  |
| **Google Chrome**      | Required for OAuth login + agent browser testing |
| **Xvfb**              | Virtual framebuffer (headless display)           |
| **Fluxbox**           | Lightweight window manager                       |
| **x11vnc**            | VNC server                                        |
| **noVNC + websockify** | Browser-based VNC access                         |
| **Supervisor**        | Process manager for all services                  |

---

## ⚡ Quick Start

### Prerequisites
- Docker Engine 20.10+
- Docker Compose v2+
- ~4GB free disk space (for image build)

### 1. Clone & Build

```bash
git clone <this-repo> antigravity-docker
cd antigravity-docker

# Create workspace directory
mkdir -p workspace

# Build and run
docker compose up -d --build
```

### 2. Access the Desktop

Open your browser and go to:

```
http://localhost:6080/vnc.html
```

**Password:** `antigravity` (change in `docker-compose.yml`)

Or use a native VNC client:

```
vnc://localhost:5900
```

### 3. First Launch

1. **Antigravity auto-starts** on the virtual desktop
2. It will ask you to **sign in with Google** — this opens Chrome inside the container
3. Complete the OAuth flow in Chrome
4. Return to Antigravity — you're logged in!
5. Chrome stays available for Antigravity's agent browser testing

---

## 🔧 Configuration

### Change VNC Password

Edit `docker-compose.yml`:

```yaml
args:
  VNC_PASSWORD: your-secure-password
```

Then rebuild: `docker compose up -d --build`

### Change Resolution

```yaml
environment:
  - RESOLUTION=2560x1440x24    # For larger screens
  # - RESOLUTION=1280x720x24   # For smaller screens
```

### Mount Your Projects

Edit the volumes section in `docker-compose.yml`:

```yaml
volumes:
  - /path/to/your/projects:/home/developer/workspace
```

### Adjust Resources

```yaml
deploy:
  resources:
    limits:
      cpus: "8.0"      # More CPU for heavy agent tasks
      memory: 16G      # More RAM for large codebases
```

### Persist Git SSH Keys

Uncomment in `docker-compose.yml`:

```yaml
volumes:
  - ~/.ssh:/home/developer/.ssh:ro
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│  Docker Container                                    │
│                                                      │
│  ┌──────────┐   ┌─────────────────────────────────┐ │
│  │Supervisor│──▶│ Xvfb (Virtual Display :99)      │ │
│  │(pid 1)   │   └──────────┬──────────────────────┘ │
│  │          │              │                         │
│  │          │   ┌──────────▼──────────────────────┐ │
│  │          │──▶│ Fluxbox (Window Manager)        │ │
│  │          │   │  ├── Antigravity IDE            │ │
│  │          │   │  └── Google Chrome              │ │
│  │          │   └──────────┬──────────────────────┘ │
│  │          │              │                         │
│  │          │   ┌──────────▼──────────────────────┐ │
│  │          │──▶│ x11vnc (VNC Server :5900)       │ │
│  │          │   └──────────┬──────────────────────┘ │
│  │          │              │                         │
│  │          │   ┌──────────▼──────────────────────┐ │
│  │          │──▶│ noVNC/websockify (:6080)        │ │
│  └──────────┘   └──────────┬──────────────────────┘ │
│                            │                         │
└────────────────────────────┼─────────────────────────┘
                             │
                    Browser: http://localhost:6080/vnc.html
```

---

## 📌 Important Notes

### Why `--no-sandbox`?
Electron and Chrome require either a proper sandbox setup or the `--no-sandbox` flag inside containers. The `SYS_ADMIN` capability and `seccomp:unconfined` in docker-compose.yml handle this securely within the container boundary.

### Why `shm_size: 2gb`?
Chrome and Electron apps use `/dev/shm` for shared memory. The default Docker shm size (64MB) causes crashes. 2GB is recommended.

### Google Login Persistence
The `chrome-profile` volume persists your Chrome profile across container restarts, so you don't need to re-login every time.

### Antigravity Settings Persistence
The `antigravity-config` volume keeps your IDE settings, extensions, agent knowledge, and preferences intact between restarts.

---

## 🛠️ Useful Commands

```bash
# Start container
docker compose up -d

# View logs
docker compose logs -f

# Shell into container
docker compose exec antigravity bash

# Stop container
docker compose down

# Full rebuild (after Dockerfile changes)
docker compose up -d --build --force-recreate

# Update Antigravity inside running container
docker compose exec antigravity sudo apt update && sudo apt upgrade -y antigravity
```

---

## 🐛 Troubleshooting

| Problem | Solution |
|---------|----------|
| Black screen in noVNC | Wait 5-10s for Xvfb to start; refresh browser |
| Chrome crashes immediately | Increase `shm_size` to `4gb` |
| Can't type in Antigravity | Click the noVNC settings gear → uncheck "Shared Mode" |
| Login popup doesn't appear | Launch Chrome manually: right-click desktop → Chrome |
| Slow/laggy display | Reduce RESOLUTION to `1280x720x24` |
| Build fails on ARM (Apple Silicon) | Add `platform: linux/amd64` under the service |

---

## 📜 License

This Docker setup is provided as-is. Google Antigravity and Google Chrome are subject to their respective licenses and terms of service.
