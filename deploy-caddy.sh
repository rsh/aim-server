#!/bin/bash

# Deploy Retro AIM Server with Caddy Reverse Proxy
# This script deploys the AIM server behind an existing Caddy instance

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Retro AIM Server - Caddy Deployment${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo "Please install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not installed${NC}"
    echo "Please install Docker Compose first: https://docs.docker.com/compose/install/"
    exit 1
fi

# Use 'docker compose' (v2) or 'docker-compose' (v1)
if docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    DOCKER_COMPOSE="docker-compose"
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}Warning: .env file not found${NC}"
    echo -e "${YELLOW}Creating .env from .env.example...${NC}"

    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓${NC} Created .env file from .env.example"
        echo ""
        echo -e "${YELLOW}⚠ IMPORTANT: Review .env file settings${NC}"
        echo "  - DISABLE_AUTH should remain commented for production"
        echo "  - LOG_LEVEL is set to 'info' (recommended)"
        echo ""
    else
        echo -e "${RED}Error: .env.example not found${NC}"
        exit 1
    fi
    read -p "Press Enter after reviewing .env file or Ctrl+C to exit..."
fi

# Load environment variables
source .env

# Check if DISABLE_AUTH is enabled (security warning)
if [ "$DISABLE_AUTH" == "true" ]; then
    echo -e "${RED}⚠ WARNING: DISABLE_AUTH is enabled!${NC}"
    echo "This is a SERIOUS SECURITY RISK in production!"
    echo "Anyone can create accounts without passwords."
    echo ""
    read -p "Continue with DISABLE_AUTH enabled? (yes/NO): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled"
        echo "Edit .env and comment out: DISABLE_AUTH=true"
        exit 0
    fi
    echo ""
fi

echo -e "${BLUE}Configuration:${NC}"
echo "  DISABLE_AUTH: ${DISABLE_AUTH:-false (commented)}"
echo "  LOG_LEVEL: ${LOG_LEVEL:-info}"
echo ""

# Check if caddy_network exists
if ! docker network ls | grep -q caddy_network; then
    echo -e "${YELLOW}Warning: caddy_network does not exist${NC}"
    echo "This network should be created by your Caddy instance"
    read -p "Create caddy_network now? (y/N): " create_network
    if [[ $create_network =~ ^[Yy]$ ]]; then
        docker network create caddy_network
        echo -e "${GREEN}✓${NC} Created caddy_network"
    else
        echo -e "${RED}Error: caddy_network is required for deployment${NC}"
        exit 1
    fi
fi

# Check if CADDY_DATA_PATH is set and exists
CADDY_DATA_PATH=${CADDY_DATA_PATH:-../caddy/caddy-data}
if [ ! -d "$CADDY_DATA_PATH" ]; then
    echo -e "${YELLOW}Warning: Caddy data directory does not exist: $CADDY_DATA_PATH${NC}"
    echo "This directory should contain Let's Encrypt certificates from your Caddy instance"
    echo ""
    echo "Options:"
    echo "  1. Update CADDY_DATA_PATH in .env to point to your Caddy data directory"
    echo "  2. Follow CADDY-SETUP-INSTRUCTIONS.md to configure Caddy with bind mounts"
    echo "  3. Create the directory now (certificates will be added when Caddy runs)"
    echo ""
    read -p "Continue anyway? (y/N): " continue_anyway
    if [[ ! $continue_anyway =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        echo ""
        echo "To fix: Set CADDY_DATA_PATH in .env or see CADDY-SETUP-INSTRUCTIONS.md"
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} Caddy data directory found: $CADDY_DATA_PATH"
fi

# Check if stunnel config exists and has been generated
if [ ! -f "config/ssl/stunnel.conf" ]; then
    echo -e "${YELLOW}⚠ WARNING: stunnel.conf not found!${NC}"
    echo ""
    echo "Run ./setup.sh to generate stunnel configuration with your chat subdomain."
    echo ""
    read -p "Continue without stunnel (no SSL for OSCAR/TOC)? (y/N): " continue_without_stunnel
    if [[ ! $continue_without_stunnel =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        echo ""
        echo "Run: ./setup.sh"
        exit 1
    fi
elif grep -q "CHAT_DOMAIN_PLACEHOLDER" config/ssl/stunnel.conf 2>/dev/null; then
    echo -e "${YELLOW}⚠ WARNING: stunnel.conf contains placeholder domain!${NC}"
    echo ""
    echo "It looks like stunnel.conf wasn't generated properly."
    echo "The CHAT_DOMAIN_PLACEHOLDER was not replaced with your actual domain."
    echo ""
    echo "Run ./setup.sh again to properly configure stunnel."
    echo ""
    read -p "Continue anyway? (y/N): " continue_stunnel
    if [[ ! $continue_stunnel =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        echo ""
        echo "Run: ./setup.sh"
        exit 1
    fi
fi

# Parse command line arguments
COMMAND=${1:-deploy}

case $COMMAND in
    deploy)
        echo -e "${BLUE}Building application...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml build
        echo -e "${GREEN}✓${NC} Build complete"
        echo ""

        echo -e "${BLUE}Starting services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml up -d
        echo -e "${GREEN}✓${NC} Services started"
        echo ""

        echo -e "${BLUE}Checking service status...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml ps
        echo ""

        # Automatically reload Caddy if it's running
        echo -e "${BLUE}Reloading Caddy configuration...${NC}"
        if docker ps --filter "name=caddy" --filter "status=running" --format "{{.Names}}" | grep -q "^caddy$"; then
            if docker exec -w /etc/caddy caddy caddy reload 2>/dev/null; then
                echo -e "${GREEN}✓${NC} Caddy configuration reloaded successfully"
            else
                echo -e "${YELLOW}⚠${NC}  Caddy reload failed - you may need to reload manually"
                echo "  Command: docker exec -w /etc/caddy caddy caddy reload"
            fi
        else
            echo -e "${YELLOW}ℹ${NC}  Caddy container not found or not running"
            echo "  If you have Caddy configured separately, reload it manually:"
            echo "  docker exec -w /etc/caddy caddy caddy reload"
        fi
        echo ""

        echo -e "${GREEN}================================${NC}"
        echo -e "${GREEN}Deployment Complete!${NC}"
        echo -e "${GREEN}================================${NC}"
        echo ""
        echo -e "${BLUE}Next steps:${NC}"
        echo "1. Configure Caddy to route to retro-aim-server:8080"
        echo "   Use Caddyfile.generated (auto-generated with your credentials)"
        echo ""
        echo "2. Open firewall ports for AIM clients:"
        echo "   - Port 5190/tcp (OSCAR plain)"
        echo "   - Port 5193/tcp (OSCAR with SSL)"
        echo "   - Port 9898/tcp (TOC plain)"
        echo "   - Port 9899/tcp (TOC with SSL)"
        echo ""
        echo "3. Test Management API connectivity:"
        echo "   docker exec caddy wget -O- http://retro-aim-server:8080/user"
        echo ""
        echo "4. Verify stunnel is using Caddy's certificates:"
        echo "   docker logs retro-aim-stunnel"
        echo ""
        echo -e "${BLUE}Access points:${NC}"
        echo "  Management API: https://your-domain.com (via Caddy)"
        echo "  OSCAR plain: your-server:5190"
        echo "  OSCAR SSL: your-server:5193 (using Caddy's Let's Encrypt cert)"
        echo "  TOC plain: your-server:9898"
        echo "  TOC SSL: your-server:9899 (using Caddy's Let's Encrypt cert)"
        echo ""
        echo -e "${BLUE}View logs:${NC}"
        echo "  docker logs retro-aim-server -f"
        ;;

    rebuild)
        echo -e "${BLUE}Rebuilding application...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml build --no-cache
        echo -e "${GREEN}✓${NC} Rebuild complete"
        echo ""

        echo -e "${BLUE}Restarting services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml up -d
        echo -e "${GREEN}✓${NC} Services restarted"
        ;;

    stop)
        echo -e "${BLUE}Stopping services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml down
        echo -e "${GREEN}✓${NC} Services stopped"
        ;;

    restart)
        echo -e "${BLUE}Restarting services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml restart
        echo -e "${GREEN}✓${NC} Services restarted"
        ;;

    logs)
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml logs -f retro-aim-server
        ;;

    status)
        echo -e "${BLUE}Service status:${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml ps
        echo ""
        echo -e "${BLUE}Network connectivity:${NC}"
        if docker network inspect caddy_network &> /dev/null; then
            echo -e "${GREEN}✓${NC} caddy_network exists"
            if docker ps --filter "name=retro-aim-server" --format "{{.Names}}" | grep -q retro-aim-server; then
                echo -e "${GREEN}✓${NC} retro-aim-server is running"
            else
                echo -e "${RED}✗${NC} retro-aim-server is not running"
            fi
        else
            echo -e "${RED}✗${NC} caddy_network does not exist"
        fi
        ;;

    update)
        echo -e "${BLUE}Updating application...${NC}"
        echo ""

        if [ -d "retro-aim-server" ]; then
            echo -e "${BLUE}Pulling latest changes from retro-aim-server repo...${NC}"
            cd retro-aim-server
            git pull
            cd ..
            echo -e "${GREEN}✓${NC} Code updated"
            echo ""
        else
            echo -e "${YELLOW}Warning: retro-aim-server directory not found${NC}"
            echo "Run ./setup.sh first"
            exit 1
        fi

        echo -e "${BLUE}Rebuilding services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml build
        echo -e "${GREEN}✓${NC} Build complete"
        echo ""

        echo -e "${BLUE}Restarting services...${NC}"
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml up -d
        echo -e "${GREEN}✓${NC} Services restarted"
        echo ""

        echo -e "${GREEN}Update complete!${NC}"
        ;;

    clean)
        echo -e "${YELLOW}Warning: This will stop services and remove volumes (database will be deleted)${NC}"
        read -p "Are you sure? (yes/NO): " confirm
        if [ "$confirm" == "yes" ]; then
            echo -e "${BLUE}Stopping and removing services...${NC}"
            $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.caddy.yml down -v
            echo -e "${GREEN}✓${NC} Services removed"
        else
            echo "Cancelled"
        fi
        ;;

    help|--help|-h)
        echo "Usage: $0 [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  deploy     Build and start services (default)"
        echo "  rebuild    Rebuild services without cache and restart"
        echo "  stop       Stop all services"
        echo "  restart    Restart services without rebuilding"
        echo "  logs       View server logs"
        echo "  status     Check service and network status"
        echo "  update     Pull latest retro-aim-server changes, rebuild, and restart"
        echo "  clean      Stop services and remove volumes (WARNING: deletes database)"
        echo "  help       Show this help message"
        echo ""
        echo "Examples:"
        echo "  $0              # Deploy application"
        echo "  $0 deploy       # Deploy application"
        echo "  $0 logs         # View logs"
        echo "  $0 status       # Check status"
        echo "  $0 update       # Update and redeploy"
        ;;

    *)
        echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac
