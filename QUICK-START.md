# Quick Start - Production Deployment Checklist

Use this checklist for deploying to your production server with bind mounts.

## Prerequisites ✓

- [ ] Caddy running on production server
- [ ] DNS records configured (aim.yourdomain.com, chat.yourdomain.com)
- [ ] SSH access to production server
- [ ] Firewall allows ports: 80, 443, 5190, 5193, 9898, 9899

## Step 1: Update Caddy (On Production Server)

### 1.1 SSH to your server
```bash
ssh user@your-server.com
```

### 1.2 Locate Caddy deployment directory
```bash
cd /path/to/caddy  # e.g., /opt/caddy
```

### 1.3 Update docker-compose.yml
```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Change:
# volumes:
#   - caddy_data:/data
# To:
#   - ./caddy-data:/data
```

### 1.4 Create directories
```bash
mkdir -p caddy-data caddy-config
sudo chown -R 1000:1000 caddy-data caddy-config
```

### 1.5 Restart Caddy
```bash
docker compose down
docker compose up -d
```

### 1.6 Verify certificates
```bash
# Wait a minute for Caddy to obtain certs, then check:
ls -la caddy-data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
```

## Step 2: Deploy AIM Server (On Production Server)

### 2.1 Clone/upload AIM server code
```bash
cd /opt  # or wherever you want to deploy
git clone <your-repo> aim-server
cd aim-server
```

### 2.2 Run setup
```bash
./setup.sh
```
When prompted for chat domain, enter: `chat.yourdomain.com`

### 2.3 Configure .env
```bash
nano .env

# Set the path to Caddy's data directory
# If your directory structure is:
#   /opt/caddy/
#   /opt/aim-server/
# Then use:
CADDY_DATA_PATH=../caddy/caddy-data

# Or use absolute path:
# CADDY_DATA_PATH=/opt/caddy/caddy-data
```

### 2.4 Update Caddyfile (in Caddy directory)
```bash
cd /path/to/caddy
nano Caddyfile

# Add the content from your aim-server/Caddyfile.generated
# (or manually add the two blocks for aim.* and chat.* subdomains)
```

### 2.5 Reload Caddy
```bash
docker exec -w /etc/caddy caddy caddy reload
```

### 2.6 Deploy AIM server
```bash
cd /opt/aim-server  # or wherever you deployed
./deploy-caddy.sh
```

## Step 3: Verify

### 3.1 Check containers
```bash
docker ps | grep -E "caddy|aim|stunnel"
```
Should show 3 containers running:
- caddy
- retro-aim-server
- retro-aim-stunnel

### 3.2 Check stunnel logs
```bash
docker logs retro-aim-stunnel
```
Look for: "Configuration successful"

### 3.3 Test Management API
```bash
# Get admin password
cat /opt/aim-server/.admin-credentials

# Test API (replace with your credentials)
curl -u admin:YOUR_PASSWORD https://aim.yourdomain.com/user
```
Should return: `{"users":[]}`

### 3.4 Test SSL connection
```bash
openssl s_client -connect chat.yourdomain.com:5193
```
Should show certificate details and "Verify return code: 0 (ok)"

## Step 4: Create Users

```bash
# Create a test user
curl -u admin:YOUR_PASSWORD \
  -d'{"screen_name":"TestUser", "password":"testpass"}' \
  https://aim.yourdomain.com/user

# List users
curl -u admin:YOUR_PASSWORD https://aim.yourdomain.com/user
```

## Troubleshooting

### stunnel can't find certificates
```bash
# Check certificates exist
ls -la /opt/caddy/caddy-data/caddy/certificates/

# Verify CADDY_DATA_PATH in .env
cat /opt/aim-server/.env | grep CADDY_DATA_PATH

# Check stunnel can see them
docker exec retro-aim-stunnel ls -la /certs/
```

### caddy_network not found
```bash
# Create network
docker network create caddy_network

# Connect Caddy to it
docker network connect caddy_network caddy
```

### Permission errors
```bash
# Fix permissions on Caddy data
sudo chmod -R 755 /opt/caddy/caddy-data
```

## Next Steps

- [ ] Configure AIM/ICQ clients to connect
- [ ] Create user accounts
- [ ] Set up backups (use `./backup.sh`)
- [ ] Set up monitoring
- [ ] Configure firewall rules

## Common Commands

```bash
# View AIM server logs
docker logs retro-aim-server -f

# View stunnel logs
docker logs retro-aim-stunnel -f

# Restart AIM server
./deploy-caddy.sh restart

# Stop AIM server
./deploy-caddy.sh stop

# View status
./deploy-caddy.sh status

# Create backup
./backup.sh

# Update to latest version
./deploy-caddy.sh update
```

## Directory Paths Reference

Typical production setup:
```
/opt/caddy/
  ├── docker-compose.yml
  ├── Caddyfile
  ├── caddy-data/         ← Certificates here
  └── caddy-config/

/opt/aim-server/
  ├── .env                ← CADDY_DATA_PATH=../caddy/caddy-data
  ├── docker-compose.yml
  └── ...
```

## Support

- Full guide: `DEPLOYMENT-GUIDE.md`
- Caddy setup: `CADDY-SETUP-INSTRUCTIONS.md`
- Changes explained: `CHANGES-SUMMARY.md`
- General info: `README.md`
