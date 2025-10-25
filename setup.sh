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
BLUE='\033[0;34m'
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
# 5. Generate Admin Credentials for Management API
# ============================================================================

echo "═══════════════════════════════════════════════════════"
echo "  🔐 Admin Credentials Setup"
echo "═══════════════════════════════════════════════════════"
echo ""

if [ ! -f ".admin-credentials" ]; then
    echo "Generating secure admin password for Management API..."

    # Generate random password (16 characters, alphanumeric)
    ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d '/+=' | head -c 16)

    # Generate bcrypt hash using caddy (if available) or docker
    if command -v caddy &> /dev/null; then
        ADMIN_HASH=$(caddy hash-password --plaintext "$ADMIN_PASSWORD")
    elif command -v docker &> /dev/null; then
        # Use Caddy docker image to generate hash
        ADMIN_HASH=$(docker run --rm caddy:latest caddy hash-password --plaintext "$ADMIN_PASSWORD")
    else
        echo -e "${YELLOW}⚠${NC}  Cannot generate bcrypt hash (caddy not available)"
        echo "Password: $ADMIN_PASSWORD"
        echo "Generate hash manually with: caddy hash-password --plaintext '$ADMIN_PASSWORD'"
        ADMIN_HASH="GENERATE_MANUALLY"
    fi

    # Save credentials
    cat > .admin-credentials << EOF
# Management API Admin Credentials
# Generated: $(date)
#
# Add this to your Caddyfile for the Management API block:
#
#   basicauth {
#       admin $ADMIN_HASH
#   }

Username: admin
Password: $ADMIN_PASSWORD
Bcrypt Hash: $ADMIN_HASH
EOF

    chmod 600 .admin-credentials

    echo -e "${GREEN}✓${NC} Admin credentials generated and saved to .admin-credentials"
    echo ""
    echo -e "${BLUE}Admin Credentials:${NC}"
    echo "  Username: admin"
    echo "  Password: $ADMIN_PASSWORD"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT: Save this password! It's also stored in .admin-credentials${NC}"
    echo ""
    echo "To enable authentication, add this to your Caddyfile:"
    echo ""
    echo "  basicauth {"
    echo "      admin $ADMIN_HASH"
    echo "  }"
    echo ""

    # Generate Caddyfile from template
    if [ -f "Caddyfile.template" ]; then
        TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S %Z")
        sed -e "s|YOUR_BCRYPT_HASH_HERE|$ADMIN_HASH|g" \
            -e "s|TIMESTAMP_PLACEHOLDER|$TIMESTAMP|g" \
            Caddyfile.template > Caddyfile.generated
        echo -e "${GREEN}✓${NC} Generated Caddyfile.generated with admin credentials"
        echo "  Timestamp: $TIMESTAMP"
        echo ""
    fi
else
    echo -e "${YELLOW}⚠${NC}  .admin-credentials already exists, skipping generation"
    echo "  Existing credentials are in: .admin-credentials"
fi

echo ""

# ============================================================================
# 6. Build Docker Image
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
# 7. Success Message
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
