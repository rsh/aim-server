#!/bin/bash
# Setup script for Retro AIM Server
# This script clones the repo if needed, builds the Docker image, and prepares the environment

set -e  # Exit on error

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  🎯 Retro AIM Server - Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# 1. Check Prerequisites
# ============================================================================

echo "📋 Checking prerequisites..."
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "   Please install Docker from https://docker.com"
    exit 1
fi

DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
echo -e "${GREEN}✓${NC} Docker $DOCKER_VERSION"

# Check Docker Compose
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    echo "   Please install Docker Compose"
    exit 1
fi

COMPOSE_VERSION=$(docker compose version | cut -d' ' -f4)
echo -e "${GREEN}✓${NC} Docker Compose $COMPOSE_VERSION"

echo ""

# ============================================================================
# 2. Clone Repository if Needed
# ============================================================================

echo "═══════════════════════════════════════════════════════"
echo "  📦 Repository Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ -d "retro-aim-server" ]; then
    echo -e "${GREEN}✓${NC} retro-aim-server directory exists"

    # Check if it's a git repo
    if [ -d "retro-aim-server/.git" ]; then
        echo "  Checking for updates..."
        cd retro-aim-server
        git fetch origin
        LOCAL=$(git rev-parse @)
        REMOTE=$(git rev-parse @{u})

        if [ "$LOCAL" != "$REMOTE" ]; then
            echo -e "${YELLOW}⚠${NC}  Updates available. Pull? (y/N): "
            read -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                git pull
                echo -e "${GREEN}✓${NC} Repository updated"
            fi
        else
            echo -e "${GREEN}✓${NC} Repository is up to date"
        fi
        cd ..
    else
        echo -e "${YELLOW}⚠${NC}  retro-aim-server exists but is not a git repo"
    fi
else
    echo "Cloning retro-aim-server repository..."
    git clone https://github.com/mk6i/retro-aim-server.git
    echo -e "${GREEN}✓${NC} Repository cloned"
fi

echo ""

# ============================================================================
# 3. Create Environment Configuration
# ============================================================================

echo "═══════════════════════════════════════════════════════"
echo "  ⚙️  Environment Configuration"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓${NC} Created .env file from .env.example"
    else
        echo -e "${YELLOW}⚠${NC}  No .env.example found, skipping .env creation"
    fi
else
    echo -e "${YELLOW}⚠${NC}  .env file already exists, skipping"
fi

echo ""

# ============================================================================
# 4. Create Data Directory
# ============================================================================

echo "═══════════════════════════════════════════════════════"
echo "  🗄️  Data Directory Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ ! -d "data" ]; then
    mkdir -p data
    echo -e "${GREEN}✓${NC} Created data directory"
else
    echo -e "${YELLOW}⚠${NC}  Data directory already exists"
fi

# Set proper permissions
chmod 755 data
echo -e "${GREEN}✓${NC} Set data directory permissions"

echo ""

# ============================================================================
# 5. Build Docker Image
# ============================================================================

echo "═══════════════════════════════════════════════════════"
echo "  🐳 Building Docker Image"
echo "═══════════════════════════════════════════════════════"
echo ""

echo "Building retro-aim-server image (this may take a few minutes)..."
docker compose build

echo ""
echo -e "${GREEN}✓${NC} Docker image built successfully"

echo ""

# ============================================================================
# 6. Success Message
# ============================================================================

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ✅ Setup Complete!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "Your Retro AIM Server is ready to run!"
echo ""
echo "📝 Quick Start:"
echo ""
echo "  Start the server:"
echo "    ./start.sh"
echo ""
echo "  Stop the server:"
echo "    ./stop.sh"
echo ""
echo "  View logs:"
echo "    docker compose logs -f"
echo ""
echo "  Create a user (after starting):"
echo "    curl -d'{\"screen_name\":\"YourName\", \"password\":\"yourpass\"}' http://localhost:8080/user"
echo ""
echo "  Server will be accessible at:"
echo "    OSCAR (AIM): 127.0.0.1:5190"
echo "    Management API: http://localhost:8080"
echo "    TOC Protocol: 127.0.0.1:9898"
echo ""
echo "💡 Development Tip:"
echo "  Edit .env and uncomment DISABLE_AUTH=true to auto-create users at login"
echo "  (Only use this in development - it's a security risk in production!)"
echo ""
echo "🎉 Happy chatting!"
echo ""
