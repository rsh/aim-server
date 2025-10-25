#!/bin/bash
# Backup Retro AIM Server database and configuration

set -e

echo "💾 Backing up Retro AIM Server..."
echo ""

# Check if server is running
SERVER_RUNNING=false
if docker compose ps 2>/dev/null | grep -q "retro-aim-server.*Up"; then
    SERVER_RUNNING=true
    echo "⚠ Server is currently running"
    echo "For a consistent backup, the server must be stopped temporarily."
    echo ""
    read -p "Stop server for backup? (Y/n): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo ""
        echo "❌ Backup cancelled - server must be stopped for consistent backup"
        echo "   Stop server manually with: ./stop.sh"
        echo "   Then run backup again: ./backup.sh"
        exit 1
    fi

    echo "Stopping server..."
    docker compose stop
    echo "✓ Server stopped"
    echo ""
fi

# Create backup directory with timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/backup_${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"

# Backup database if it exists
if [ -d "data" ]; then
    echo "Backing up database..."
    cp -r data "$BACKUP_DIR/"
    echo "✓ Database backed up"
else
    echo "⚠ No data directory found, skipping database backup"
fi

# Backup configuration
if [ -f ".env" ]; then
    echo "Backing up configuration..."
    cp .env "$BACKUP_DIR/"
    echo "✓ Configuration backed up"
else
    echo "⚠ No .env file found, skipping configuration backup"
fi

# Backup docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    cp docker-compose.yml "$BACKUP_DIR/"
    echo "✓ Docker compose file backed up"
fi

# Create backup info file
cat > "$BACKUP_DIR/backup_info.txt" << EOF
Retro AIM Server Backup
Created: $(date)
Hostname: $(hostname)
Contents:
  - data/ (SQLite database)
  - .env (configuration)
  - docker-compose.yml
EOF

echo ""
echo "✅ Backup complete!"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
echo "To restore from this backup:"
echo "  1. Stop the server: ./stop.sh"
echo "  2. Restore data: cp -r $BACKUP_DIR/data ./"
echo "  3. Restore config: cp $BACKUP_DIR/.env ./"
echo "  4. Start server: ./start.sh"
echo ""

# Compress backup
read -p "Do you want to compress this backup? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Compressing backup..."
    tar -czf "${BACKUP_DIR}.tar.gz" -C backups "backup_${TIMESTAMP}"
    rm -rf "$BACKUP_DIR"
    echo "✓ Backup compressed: ${BACKUP_DIR}.tar.gz"
    echo ""
fi

# Restart server if it was running
if [ "$SERVER_RUNNING" = true ]; then
    echo ""
    read -p "Restart server now? (Y/n): " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Starting server..."
        docker compose up -d
        echo "✓ Server restarted"
    fi
fi
