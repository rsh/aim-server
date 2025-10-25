#!/bin/bash
# Teardown - clean up containers and optionally remove data

set -e

echo "🧹 Cleaning up Retro AIM Server deployment..."
echo ""

# Check if containers are running
if docker compose ps 2>/dev/null | grep -q "retro-aim-server"; then
    echo "Stopping and removing containers..."
    docker compose down
    echo "✓ Containers stopped and removed"
else
    echo "Removing containers (if any exist)..."
    docker compose down 2>/dev/null || echo "No containers to remove"
fi

# Ask about data cleanup
echo ""
read -p "Do you want to remove the database and all data? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "./data" ]; then
        echo "Removing database directory..."
        rm -rf ./data
        echo "✓ Database removed"
    else
        echo "No data directory found"
    fi
fi

# Ask about Docker volumes
echo ""
read -p "Do you want to remove Docker volumes? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Docker volumes..."
    docker compose down -v 2>/dev/null || true
    echo "✓ Volumes removed"
fi

# Ask about images
echo ""
read -p "Do you want to remove Docker images? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Docker images..."
    docker rmi retro-aim-server-retro-aim-server 2>/dev/null || true
    echo "✓ Images removed"
fi

# Ask about generated configuration files
echo ""
read -p "Do you want to remove generated configuration files? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing generated configuration files..."

    # Remove admin credentials
    if [ -f ".admin-credentials" ]; then
        rm -f .admin-credentials
        echo "✓ Removed .admin-credentials"
    fi

    # Remove generated Caddyfile
    if [ -f "Caddyfile.generated" ]; then
        rm -f Caddyfile.generated
        echo "✓ Removed Caddyfile.generated"
    fi

    # Remove generated stunnel.conf
    if [ -f "config/ssl/stunnel.conf" ]; then
        rm -f config/ssl/stunnel.conf
        echo "✓ Removed config/ssl/stunnel.conf"
    fi

    echo "✓ Generated files removed"
    echo ""
    echo "Note: Run ./setup.sh to regenerate these files"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "To rebuild and redeploy, run: ./setup.sh"
