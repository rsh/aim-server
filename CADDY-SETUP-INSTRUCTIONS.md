# Caddy Setup Instructions for AIM Server Integration

This guide shows how to modify your existing Caddy setup to share certificates with the AIM server using bind mounts instead of Docker volumes.

## Step 1: Modify Caddy Docker Compose

Update your Caddy `docker-compose.yml` to use bind mounts for certificate storage.

**Before (using volumes):**
```yaml
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks:
      - caddy_network

volumes:
  caddy_data:
  caddy_config:

networks:
  caddy_network:
    driver: bridge
```

**After (using bind mounts):**
```yaml
services:
  caddy:
    image: caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy-data:/data          # Changed: bind mount to host directory
      - ./caddy-config:/config      # Changed: bind mount to host directory
    networks:
      - caddy_network

networks:
  caddy_network:
    driver: bridge
    external: false  # Changed: make network non-external so it can be created
```

**What changed:**
- `caddy_data:/data` → `./caddy-data:/data` (bind mount to host)
- `caddy_config:/config` → `./caddy-config:/config` (bind mount to host)
- Removed the `volumes:` section at the bottom
- Made `caddy_network` non-external (or keep external if you prefer)

## Step 2: Create Directories on Production Server

On your production server, create the directories:

```bash
# In your Caddy deployment directory
mkdir -p caddy-data caddy-config

# Set proper permissions (Caddy runs as user 1000 by default)
sudo chown -R 1000:1000 caddy-data caddy-config
```

## Step 3: Restart Caddy

```bash
# In your Caddy directory
docker compose down
docker compose up -d
```

Caddy will now store certificates in `./caddy-data` on your host.

## Step 4: Verify Certificate Location

After Caddy restarts and gets certificates, verify they exist:

```bash
ls -la caddy-data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
```

You should see directories for each domain Caddy manages.

## Step 5: Update AIM Server Configuration

The modified `docker-compose.caddy.yml` (see next step) will reference this shared directory.

**Important:** Make sure both Caddy and the AIM server can access the same certificate directory on the host filesystem.

## Architecture After Changes

```
Host Filesystem:
  /path/to/caddy/
    ├── caddy-data/              ← Caddy writes certs here
    │   └── caddy/certificates/

  /path/to/aim-server/
    └── ../caddy/caddy-data/     ← stunnel reads certs from here (relative path)

Docker Containers:
  [Caddy] /data → Host: ./caddy-data
  [stunnel] /certs:ro → Host: ../caddy/caddy-data (shared filesystem!)
```
