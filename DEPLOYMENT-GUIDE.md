# AIM Server Deployment Guide (with Caddy bind mounts)

This guide walks you through deploying the Retro AIM Server alongside your existing Caddy server using filesystem bind mounts for certificate sharing.

## Overview

Instead of using Docker volumes, we'll use bind mounts so both Caddy and the AIM server can access certificates via the host filesystem.

## Prerequisites

- Existing Caddy server running in Docker
- Docker and Docker Compose installed
- Two subdomains pointing to your server:
  - `aim.yourdomain.com` - Management API
  - `chat.yourdomain.com` - Chat connections
- Firewall configured for ports: 443, 5190, 5193, 9898, 9899

## Step 1: Update Caddy Configuration

### 1.1 Modify Caddy's docker-compose.yml

Update your Caddy deployment to use bind mounts instead of volumes:

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
      - ./caddy-data:/data          # Changed from volume to bind mount
      - ./caddy-config:/config      # Changed from volume to bind mount
    networks:
      - caddy_network

networks:
  caddy_network:
    driver: bridge
```

**Key changes:**
- `caddy_data:/data` → `./caddy-data:/data`
- `caddy_config:/config` → `./caddy-config:/config`
- Removed `volumes:` section at the bottom

### 1.2 Create directories

On your server (in Caddy's directory):

```bash
mkdir -p caddy-data caddy-config
sudo chown -R 1000:1000 caddy-data caddy-config  # Caddy runs as UID 1000
```

### 1.3 Restart Caddy

```bash
# In your Caddy directory
docker compose down
docker compose up -d
```

### 1.4 Verify certificates

After Caddy gets certificates:

```bash
ls -la caddy-data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
```

You should see directories for your domains.

## Step 2: Configure AIM Server

### 2.1 Update .env file

Edit `.env` and set:

```bash
# Your chat subdomain
CHAT_DOMAIN=chat.yourdomain.com

# Path to Caddy's data directory (relative or absolute)
# If AIM server is in /opt/aim-server and Caddy is in /opt/caddy:
CADDY_DATA_PATH=/opt/caddy/caddy-data

# Or use a relative path if they're siblings:
# CADDY_DATA_PATH=../caddy/caddy-data
```

**Important:** The path should point to where Caddy stores its data on the host.

### 2.2 Directory structure example

```
/opt/
├── caddy/
│   ├── docker-compose.yml
│   ├── Caddyfile
│   ├── caddy-data/           ← Certificates stored here
│   │   └── caddy/certificates/
│   └── caddy-config/
│
└── aim-server/
    ├── docker-compose.yml
    ├── docker-compose.caddy.yml
    ├── .env                  ← Set CADDY_DATA_PATH=../caddy/caddy-data
    └── ...
```

## Step 3: Add Caddyfile Configuration

Add these blocks to your main Caddyfile:

```caddy
# Management API - HTTPS
aim.yourdomain.com {
    reverse_proxy retro-aim-server:8080
    encode gzip zstd

    # Admin authentication (from .admin-credentials)
    basicauth {
        admin $2a$14$YOUR_HASH_FROM_ADMIN_CREDENTIALS
    }

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# Chat subdomain (for SSL certificate)
chat.yourdomain.com {
    respond "AIM Server - Use ports 5193 (OSCAR) or 9899 (TOC) for encrypted chat" 200
}
```

**Tip:** Use the auto-generated `Caddyfile.generated` which has the bcrypt hash already filled in!

Reload Caddy:
```bash
docker exec -w /etc/caddy caddy caddy reload
```

## Step 4: Deploy AIM Server

```bash
# Run setup if you haven't already
./setup.sh

# Deploy with Caddy configuration
./deploy-caddy.sh
```

The script will:
- Check that `CADDY_DATA_PATH` directory exists
- Build the AIM server
- Start services (aim-server + stunnel)
- Connect to `caddy_network`

## Step 5: Verify Deployment

### Check containers

```bash
docker ps | grep -E "caddy|aim|stunnel"
```

You should see:
- `caddy` - Running
- `retro-aim-server` - Running
- `retro-aim-stunnel` - Running

### Check stunnel logs

```bash
docker logs retro-aim-stunnel
```

Look for messages indicating successful certificate loading.

### Test SSL connection

```bash
# Test OSCAR SSL port
openssl s_client -connect chat.yourdomain.com:5193

# Should show certificate details and successful connection
```

### Test Management API

```bash
# Get admin credentials
cat .admin-credentials

# Test API (replace with your credentials and domain)
curl -u admin:YOUR_PASSWORD https://aim.yourdomain.com/user
```

## Troubleshooting

### stunnel can't find certificates

**Problem:** stunnel logs show certificate errors

**Solution:**
1. Verify `CADDY_DATA_PATH` in `.env` points to the correct location
2. Check certificates exist:
   ```bash
   ls -la $CADDY_DATA_PATH/caddy/certificates/acme-v02.api.letsencrypt.org-directory/chat.yourdomain.com/
   ```
3. Ensure permissions allow reading:
   ```bash
   sudo chmod -R 755 $CADDY_DATA_PATH
   ```

### caddy_network not found

**Problem:** `deploy-caddy.sh` reports `caddy_network does not exist`

**Solution:**
```bash
# Create the network
docker network create caddy_network

# Ensure Caddy is connected to it
docker network connect caddy_network caddy
```

### Certificates not updating

**Problem:** Old certificates after Caddy renewal

**Solution:**
- stunnel automatically picks up new certificates
- Restart stunnel to force reload:
  ```bash
  docker restart retro-aim-stunnel
  ```

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│          Host Filesystem                     │
│                                              │
│  /opt/caddy/caddy-data/                     │
│    └── caddy/certificates/                  │
│         └── acme-v02.api.letsencrypt.org/   │
│             ├── aim.yourdomain.com/         │
│             └── chat.yourdomain.com/  ←──┐  │
│                                          │  │
│  [Caddy Container]                       │  │
│    /data (mounted) ──────────────────────┘  │
│    - Obtains certs                          │
│    - Auto-renews                            │
│                                             │
│  [stunnel Container]                        │
│    /certs:ro (mounted) ──────────────────┐  │
│    - Reads certs                         │  │
│    - Provides SSL for OSCAR/TOC          │  │
│                                          │  │
│  Shared via filesystem! ─────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

## Next Steps

- Configure AIM clients to connect to your server
- Set up user accounts via Management API
- Configure firewall rules
- Set up monitoring/backups

See README.md for more details on user management and client configuration.
