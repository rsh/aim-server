# Retro AIM Server - Docker Setup

This directory contains scripts to easily set up, manage, and back up a [Retro AIM Server](https://github.com/mk6i/retro-aim-server) using Docker.

## Quick Start

```bash
# Initial setup (clones repo, builds image, creates config)
./setup.sh

# Start the server
./start.sh

# Stop the server
./stop.sh
```

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

Create users via the Management API:

```bash
# Create a user
curl -d'{"screen_name":"MyScreenName", "password":"mypassword"}' http://localhost:8080/user

# List users
curl http://localhost:8080/user

# Delete user
curl -X DELETE -d'{"screen_name":"MyScreenName"}' http://localhost:8080/user

# Change password
curl -X PUT -d'{"screen_name":"MyScreenName", "password":"newpassword"}' http://localhost:8080/user/password
```

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
├── setup.sh              # Initial setup
├── start.sh              # Start server
├── stop.sh               # Stop server
├── teardown.sh           # Complete cleanup
├── backup.sh             # Backup utility
└── restore.sh            # Restore from backup
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

## Links

- [Retro AIM Server GitHub](https://github.com/mk6i/retro-aim-server)
- [AIM Client Setup Guide](https://github.com/mk6i/retro-aim-server/blob/main/docs/CLIENT.md)
- [ICQ Client Setup Guide](https://github.com/mk6i/retro-aim-server/blob/main/docs/CLIENT_ICQ.md)
