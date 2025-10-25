#!/bin/bash
# Restore Retro AIM Server from backup

set -e

echo "🔄 Restoring Retro AIM Server from backup..."
echo ""

# Check if backups directory exists
if [ ! -d "backups" ] || [ -z "$(ls -A backups 2>/dev/null)" ]; then
    echo "❌ No backups found in ./backups directory"
    echo ""
    echo "Create a backup first with: ./backup.sh"
    exit 1
fi

# List available backups
echo "Available backups:"
echo ""

BACKUP_LIST=()
i=1

# Find both compressed and uncompressed backups
for backup in backups/backup_* backups/*.tar.gz; do
    if [ -e "$backup" ]; then
        # Get basename and format nicely
        backup_name=$(basename "$backup")

        # Extract timestamp if possible
        if [[ $backup_name =~ backup_([0-9]{8}_[0-9]{6}) ]]; then
            timestamp="${BASH_REMATCH[1]}"
            # Format: YYYYMMDD_HHMMSS -> YYYY-MM-DD HH:MM:SS
            formatted_date=$(echo "$timestamp" | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)/\1-\2-\3 \4:\5:\6/')
            echo "  [$i] $backup_name ($formatted_date)"
        else
            echo "  [$i] $backup_name"
        fi

        BACKUP_LIST+=("$backup")
        ((i++))
    fi
done

if [ ${#BACKUP_LIST[@]} -eq 0 ]; then
    echo "❌ No valid backups found"
    exit 1
fi

echo ""
read -p "Select backup to restore (1-${#BACKUP_LIST[@]}): " selection

# Validate selection
if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#BACKUP_LIST[@]} ]; then
    echo "❌ Invalid selection"
    exit 1
fi

SELECTED_BACKUP="${BACKUP_LIST[$((selection-1))]}"
echo ""
echo "Selected: $(basename "$SELECTED_BACKUP")"

# Extract if compressed
RESTORE_DIR=""
if [[ "$SELECTED_BACKUP" == *.tar.gz ]]; then
    echo ""
    echo "Extracting compressed backup..."
    TEMP_DIR=$(mktemp -d)
    tar -xzf "$SELECTED_BACKUP" -C "$TEMP_DIR"
    # Find the extracted backup directory
    RESTORE_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "backup_*" | head -n 1)
    if [ -z "$RESTORE_DIR" ]; then
        echo "❌ Could not find backup in archive"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    echo "✓ Backup extracted"
else
    RESTORE_DIR="$SELECTED_BACKUP"
fi

# Verify backup contents
if [ ! -f "$RESTORE_DIR/backup_info.txt" ]; then
    echo "⚠ Warning: backup_info.txt not found - this may not be a valid backup"
fi

echo ""
echo "Backup contains:"
[ -d "$RESTORE_DIR/data" ] && echo "  ✓ Database (data/)"
[ -f "$RESTORE_DIR/.env" ] && echo "  ✓ Configuration (.env)"
[ -f "$RESTORE_DIR/docker-compose.yml" ] && echo "  ✓ Docker compose file"

echo ""
echo "⚠️  WARNING: This will REPLACE your current data!"
echo ""
read -p "Continue with restore? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled"
    # Cleanup temp dir if it was extracted
    [[ "$SELECTED_BACKUP" == *.tar.gz ]] && rm -rf "$TEMP_DIR"
    exit 0
fi

# Check if server is running
if docker compose ps 2>/dev/null | grep -q "retro-aim-server.*Up"; then
    echo ""
    echo "Stopping server..."
    docker compose stop
    echo "✓ Server stopped"
fi

# Backup current data (just in case)
if [ -d "data" ] || [ -f ".env" ]; then
    SAFETY_BACKUP="backups/pre_restore_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$SAFETY_BACKUP"
    echo ""
    echo "Creating safety backup of current data..."
    [ -d "data" ] && cp -r data "$SAFETY_BACKUP/"
    [ -f ".env" ] && cp .env "$SAFETY_BACKUP/"
    echo "✓ Current data backed up to: $SAFETY_BACKUP"
fi

# Restore data
echo ""
if [ -d "$RESTORE_DIR/data" ]; then
    echo "Restoring database..."
    rm -rf data
    cp -r "$RESTORE_DIR/data" ./
    echo "✓ Database restored"
fi

# Restore configuration
if [ -f "$RESTORE_DIR/.env" ]; then
    echo "Restoring configuration..."
    cp "$RESTORE_DIR/.env" ./
    echo "✓ Configuration restored"
fi

# Restore docker-compose if present
if [ -f "$RESTORE_DIR/docker-compose.yml" ]; then
    echo "Restoring docker-compose.yml..."
    cp "$RESTORE_DIR/docker-compose.yml" ./
    echo "✓ Docker compose file restored"
fi

# Cleanup temp dir if it was extracted
[[ "$SELECTED_BACKUP" == *.tar.gz ]] && rm -rf "$TEMP_DIR"

echo ""
echo "✅ Restore complete!"
echo ""
read -p "Start server now? (Y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Starting server..."
    docker compose up -d
    sleep 3
    echo ""
    echo "✅ Server started!"
    echo ""
    echo "Server is running at:"
    echo "  OSCAR (AIM): 127.0.0.1:5190"
    echo "  Management API: http://localhost:8080"
else
    echo "Server not started. Start manually with: ./start.sh"
fi

echo ""
