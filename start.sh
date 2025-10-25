#!/bin/bash
# Start Retro AIM Server

set -e

echo "🚀 Starting Retro AIM Server..."
echo ""

# Start containers
echo "Starting containers..."
docker compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 3

# Check if services are running
if docker compose ps | grep -q "retro-aim-server"; then
    echo ""
    echo "✅ Retro AIM Server is running!"
    echo ""
    echo "Access your server at:"
    echo "  OSCAR (AIM): 127.0.0.1:5190"
    echo "  Management API: http://localhost:8080"
    echo "  TOC Protocol: 127.0.0.1:9898"
    echo ""
    echo "View logs:"
    echo "  docker compose logs -f"
    echo ""
    echo "Stop server:"
    echo "  ./stop.sh"
    echo ""
else
    echo ""
    echo "❌ Failed to start. Check logs:"
    echo "  docker compose logs"
    exit 1
fi
