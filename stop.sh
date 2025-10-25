#!/bin/bash
# Stop Retro AIM Server

echo "🛑 Stopping Retro AIM Server..."
echo ""

docker compose stop

echo ""
echo "✅ Server stopped"
echo ""
echo "To start again: ./start.sh"
echo "To remove containers: ./teardown.sh"
echo ""
