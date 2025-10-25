# Retro AIM Server - Docker Setup

This directory contains scripts to easily set up, manage, and back up a [Retro AIM Server](https://github.com/mk6i/retro-aim-server) using Docker.

## Quick Start

**Choose your deployment method:**

### Development/Local Use (No Caddy)

For testing locally without SSL/TLS or Caddy:

```bash
# 1. Initial setup (clones repo, builds image, creates config)
./setup.sh

# 2. Start the server (dev mode)
./start.sh

# 3. Stop the server
./stop.sh
```

**Access:**
- Management API: `http://localhost:8080`
- OSCAR: `localhost:5190` (plain only, no SSL)
- TOC: `localhost:9898` (plain only, no SSL)

---

### Production Deployment with Caddy (SSL/TLS)

For production with HTTPS and SSL-encrypted chat connections:

```bash
# 1. Initial setup - generates credentials and configs
./setup.sh

# 2. Add Caddyfile.generated to your main Caddy config
#    (See Production Deployment section below)

# 3. Deploy with Caddy + stunnel
./deploy-caddy.sh

# View status
./deploy-caddy.sh status

# View logs
./deploy-caddy.sh logs
```

**Access:**
- Management API: `https://aim.yourdomain.com` (HTTPS + auth)
- OSCAR SSL: `chat.yourdomain.com:5193` (encrypted)
- TOC SSL: `chat.yourdomain.com:9899` (encrypted)

**Important:** After `setup.sh`, use `deploy-caddy.sh` (NOT `start.sh`) for production!

See [Production Deployment](#production-deployment-with-ssltls) section below for full details.

## Scripts

### `setup.sh`
Initial setup script that:
- Checks for Docker and Docker Compose
- Clones retro-aim-server repo (if needed)
- Creates `.env` configuration from `.env.example`
- Creates data directory
- Builds Docker image

Run this once before starting the server for the first time.

### `start.sh`
Starts the AIM server in Docker containers.

Server will be accessible at:
- **OSCAR (AIM)**: `127.0.0.1:5190`
- **Management API**: `http://localhost:8080`
- **TOC Protocol**: `127.0.0.1:9898`

### `stop.sh`
Stops the running server without removing containers or data.

### `teardown.sh`
Complete cleanup script with prompts to:
- Stop and remove containers
- Remove database and data
- Remove Docker volumes
- Remove Docker images

Use this to completely clean up your installation.

### `backup.sh`
Creates timestamped backups of:
- Database (SQLite file in `data/`)
- Configuration (`.env`)
- Docker compose file

The server must be stopped for a consistent backup. The script will:
1. Prompt to stop the server if running (required)
2. Create the backup
3. Optionally compress to `.tar.gz`
4. Offer to restart the server

Backups are saved to `backups/backup_YYYYMMDD_HHMMSS/`

### `restore.sh`
Restores a previous backup. The script will:
1. Show available backups (both compressed and uncompressed)
2. Let you select which backup to restore
3. Create a safety backup of current data
4. Stop the server if running
5. Restore database and configuration
6. Offer to restart the server

**Warning**: Restoring will replace your current data!

### `deploy-caddy.sh`
Production deployment script for use with Caddy reverse proxy. Supports commands:
- `deploy` - Build and start with Caddy configuration (default)
- `rebuild` - Rebuild without cache and restart
- `stop` - Stop all services
- `restart` - Restart services
- `logs` - View server logs
- `status` - Check service and network status
- `update` - Pull latest changes and redeploy
- `clean` - Remove everything including data

Uses `docker-compose.caddy.yml` overlay to:
- Expose Management API via Caddy (HTTPS)
- Keep OSCAR (5190) and TOC (9898) ports exposed directly
- Connect to external `caddy_network`

## Configuration

Edit `.env` to configure the server:

```bash
# Development mode - auto-create users at login (INSECURE!)
# Uncomment for development only:
# DISABLE_AUTH=true

# Logging level
LOG_LEVEL=info
```

**Security Note**: Never enable `DISABLE_AUTH` in production - it allows anyone to create accounts without passwords!

## User Management

### Admin Credentials

The Management API is protected with basic authentication. During `./setup.sh`, admin credentials are automatically generated and saved to `.admin-credentials`:

```bash
# View your admin credentials
cat .admin-credentials
```

**Username:** `admin`
**Password:** Auto-generated during setup (stored in `.admin-credentials`)

### Managing AIM Users

Create users via the Management API (requires authentication):

```bash
# For production (with authentication) - use aim subdomain
curl -u admin:YOUR_PASSWORD -d'{"screen_name":"MyScreenName", "password":"mypassword"}' https://aim.yourdomain.com/user

# For local development (no auth)
curl -d'{"screen_name":"MyScreenName", "password":"mypassword"}' http://localhost:8080/user

# List users
curl -u admin:YOUR_PASSWORD https://aim.yourdomain.com/user

# Delete user
curl -u admin:YOUR_PASSWORD -X DELETE -d'{"screen_name":"MyScreenName"}' https://aim.yourdomain.com/user

# Change password
curl -u admin:YOUR_PASSWORD -X PUT -d'{"screen_name":"MyScreenName", "password":"newpassword"}' https://aim.yourdomain.com/user/password
```

**Note:** The Management API uses the `aim` subdomain, while chat clients connect to the `chat` subdomain.

## Docker Commands

```bash
# View logs
docker compose logs -f

# Rebuild after changes
docker compose up -d --build

# Check status
docker compose ps

# Access container shell
docker compose exec retro-aim-server sh
```

## Directory Structure

```
aim-server/
├── retro-aim-server/     # Cloned repository
├── data/                 # SQLite database (persisted)
├── backups/              # Created by backup.sh
├── docker-compose.yml    # Docker configuration
├── .env                  # Environment configuration
├── .env.example          # Template configuration
├── setup.sh                   # Initial setup
├── start.sh                   # Start server (dev)
├── stop.sh                    # Stop server
├── deploy-caddy.sh            # Production deployment with Caddy
├── teardown.sh                # Complete cleanup
├── backup.sh                  # Backup utility
├── restore.sh                 # Restore from backup
├── Caddyfile.template         # Caddy config template (used by setup.sh)
├── Caddyfile.generated        # Auto-generated Caddy config with credentials
└── docker-compose.caddy.yml   # Production Docker compose overlay
```

## Updating

To update to the latest version of retro-aim-server:

```bash
./stop.sh
cd retro-aim-server
git pull
cd ..
docker compose build
./start.sh
```

Or run `./setup.sh` again - it will prompt to update if changes are available.

## Production Deployment with SSL/TLS

The Caddy deployment includes SSL/TLS support for OSCAR and TOC protocols using stunnel. Caddy automatically manages Let's Encrypt certificates, and stunnel uses them to provide encrypted connections.

### Prerequisites
- Existing Caddy server with `caddy_network` Docker network
- Caddy certificate directory accessible on host filesystem (bind mount recommended)
  - **New Setup:** See `DEPLOYMENT-GUIDE.md` for bind mount configuration
  - **Legacy Setup:** `caddy_data` Docker volume (deprecated approach)
- Domain name with subdomains pointing to your server:
  - `aim.yourdomain.com` - Management API
  - `chat.yourdomain.com` - Chat connections (OSCAR/TOC)
- Firewall configured for ports: 443, 5190, 5193, 9898, 9899

**Note:** This setup now uses bind mounts for certificate sharing instead of Docker volumes. See `DEPLOYMENT-GUIDE.md` for complete instructions.

### DNS Setup

Create two A records pointing to your server's IP:
```
aim.yourdomain.com  → your.server.ip.address
chat.yourdomain.com → your.server.ip.address
```

### Configuration Steps

**For detailed deployment instructions with bind mounts, see `DEPLOYMENT-GUIDE.md`**

1. **Configure Caddy for bind mounts** (if not already done):
   - Update Caddy's docker-compose.yml to use bind mounts
   - See `CADDY-SETUP-INSTRUCTIONS.md` for details

2. **Run setup.sh** (if not done already):
   ```bash
   ./setup.sh
   ```
   This will generate admin credentials and `Caddyfile.generated`

3. **Set CADDY_DATA_PATH in .env**:
   ```bash
   # Path to where Caddy stores certificates on host
   CADDY_DATA_PATH=/path/to/caddy/caddy-data
   # Or use relative path if Caddy is in a sibling directory:
   # CADDY_DATA_PATH=../caddy/caddy-data
   ```

4. **Update stunnel configuration** with your chat subdomain:
   ```bash
   nano config/ssl/stunnel.conf
   # Replace 'chat.example.com' with your actual chat subdomain
   # (e.g., chat.yourdomain.com)
   ```

5. **Add Caddyfile configuration** (use the auto-generated `Caddyfile.generated`):
   ```bash
   # Add to your main Caddyfile - two subdomain blocks:

   # 1. Management API
   aim.yourdomain.com {
       reverse_proxy retro-aim-server:8080
       basicauth {
           admin YOUR_HASH_FROM_ADMIN_CREDENTIALS
       }
   }

   # 2. Chat subdomain (for SSL certificate)
   chat.yourdomain.com {
       respond "AIM Server - Use ports 5193 (OSCAR) or 9899 (TOC) for encrypted chat" 200
   }
   ```
   **Tip:** Use the pre-generated `Caddyfile.generated` which has the bcrypt hash already filled in!

6. **Deploy with Caddy**:
   ```bash
   ./deploy-caddy.sh
   ```

7. **Reload Caddy** to apply configuration:
   ```bash
   docker exec -w /etc/caddy caddy caddy reload
   ```

### How It Works

**Architecture Diagram:**
```
┌─────────────────────────────────────────────────┐
│              Your Server                        │
│                                                 │
│  ┌──────────┐     Automatic Certificate        │
│  │  Caddy   │     Management (Let's Encrypt)   │
│  │          │                                   │
│  │  Stores  ├─────┐                            │
│  │  Certs   │     │                            │
│  └────┬─────┘     │                            │
│       │           │ caddy_data volume          │
│       │           │ (read-only)                │
│       ↓           │                            │
│  Port 443 ←───────┘                            │
│  (HTTPS API)      ↓                            │
│              ┌──────────┐                      │
│              │ stunnel  │ Uses Caddy's certs!  │
│              └────┬─────┘                      │
│                   │                             │
│              Port 5193 (OSCAR SSL)             │
│              Port 9899 (TOC SSL)               │
│                   │                             │
│              ┌────┴─────────┐                  │
│              │ retro-aim-   │                  │
│              │ server       │                  │
│              └──────────────┘                  │
│              Port 5190 (OSCAR plain)           │
│              Port 9898 (TOC plain)             │
└─────────────────────────────────────────────────┘
```

**Certificate Management:**
- Caddy automatically obtains Let's Encrypt certificates for **both subdomains**:
  - `aim.yourdomain.com` - Used by Caddy for Management API HTTPS
  - `chat.yourdomain.com` - Used by stunnel for OSCAR/TOC SSL
- Certificates stored in `caddy_data` Docker volume
- stunnel mounts this volume (read-only) and uses the chat subdomain certificate
- Caddy handles automatic renewal - stunnel picks up new certs automatically
- **No manual certificate work needed!** (No certbot, no cron jobs)

**Subdomain Configuration:**
- **aim.yourdomain.com** - Management API (HTTPS via Caddy)
  - Port 443 (HTTPS) - Web-based administration
- **chat.yourdomain.com** - Chat connections (both plain and SSL)
  - Port 5190 - OSCAR plain (for legacy clients)
  - Port 5193 - OSCAR with SSL/TLS (via stunnel)
  - Port 9898 - TOC plain (for legacy clients)
  - Port 9899 - TOC with SSL/TLS (via stunnel)

**Client Configuration:**
- Management API: `https://aim.yourdomain.com`
- Modern AIM clients: `chat.yourdomain.com:5193` (encrypted OSCAR)
- Legacy AIM clients: `chat.yourdomain.com:5190` (plain OSCAR)

### Verification

Check that stunnel is using Caddy's certificates:
```bash
# View stunnel logs
docker logs retro-aim-stunnel

# Should show certificate loaded successfully
# Look for lines like: "Configuration successful"
```

Test SSL connection:
```bash
openssl s_client -connect chat.yourdomain.com:5193
# Should show certificate details for chat.yourdomain.com and successful connection
```

## Troubleshooting

**Server won't start:**
```bash
# Check logs
docker compose logs

# Rebuild image
docker compose build --no-cache
```

**Port conflicts:**
Edit `docker-compose.yml` to change port mappings:
```yaml
ports:
  - "5190:5190"  # Change left side: "NEW_PORT:5190"
```

**Database issues:**
```bash
# Backup first!
./backup.sh

# Remove and recreate
./teardown.sh
./setup.sh
./start.sh
```

**stunnel/SSL issues:**
```bash
# Check if stunnel can access certificates
docker logs retro-aim-stunnel

# Verify caddy_data volume is mounted
docker inspect retro-aim-stunnel | grep caddy_data

# Check certificate path (find your domain's cert)
docker exec caddy ls -la /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/

# Manually test stunnel can read cert
docker exec retro-aim-stunnel ls -la /certs/certificates/acme-v02.api.letsencrypt.org-directory/yourdomain.com/
```

**Clients can't connect with SSL:**
- Verify firewall allows ports 5193 and 9899
- Check stunnel logs: `docker logs retro-aim-stunnel`
- Test with openssl: `openssl s_client -connect yourserver:5193`
- Some very old AIM clients don't support TLS - use plain ports (5190, 9898)

## Links

- [Retro AIM Server GitHub](https://github.com/mk6i/retro-aim-server)
- [AIM Client Setup Guide](https://github.com/mk6i/retro-aim-server/blob/main/docs/CLIENT.md)
- [ICQ Client Setup Guide](https://github.com/mk6i/retro-aim-server/blob/main/docs/CLIENT_ICQ.md)
