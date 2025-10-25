# Changes Summary: Docker Volume → Bind Mount

## What Changed

The AIM server deployment has been updated to use **filesystem bind mounts** instead of **Docker volumes** for certificate sharing with Caddy.

### Why?

The previous setup required a `caddy_data` Docker volume to exist, which only works when Caddy creates it. Since Caddy may not have been configured to create this volume, stunnel couldn't access the certificates.

With bind mounts, both Caddy and stunnel can access the same directory on the host filesystem, making certificate sharing much simpler and more flexible.

## Modified Files

### 1. `docker-compose.caddy.yml`
- **Changed:** stunnel volume mount from `caddy_data:/certs:ro` to `${CADDY_DATA_PATH:-../caddy/caddy-data}:/certs:ro`
- **Changed:** Removed `volumes: caddy_data: external: true` section
- **Effect:** stunnel now reads certificates from a host directory instead of a Docker volume

### 2. `.env` and `.env.example`
- **Added:** `CADDY_DATA_PATH` variable
- **Purpose:** Allows you to specify where Caddy stores certificates on your host
- **Default:** `../caddy/caddy-data` (assumes Caddy is in a sibling directory)

### 3. `deploy-caddy.sh`
- **Changed:** Check for directory existence instead of Docker volume
- **Changed:** More helpful error messages with instructions
- **Effect:** Better validation and user guidance during deployment

### 4. `README.md`
- **Updated:** Prerequisites section to mention bind mounts
- **Updated:** Configuration steps to include `CADDY_DATA_PATH` setup
- **Added:** References to new documentation files

## New Files Created

### 1. `CADDY-SETUP-INSTRUCTIONS.md`
Step-by-step guide for modifying your Caddy deployment to use bind mounts.

### 2. `DEPLOYMENT-GUIDE.md`
Complete end-to-end deployment guide with bind mount configuration.

### 3. `CHANGES-SUMMARY.md` (this file)
Summary of what changed and why.

## How to Use

### For New Deployments

Follow `DEPLOYMENT-GUIDE.md` - it walks through the complete setup from scratch.

### For Existing Deployments

1. **Update Caddy** (on production server):
   - Modify Caddy's `docker-compose.yml` to use bind mounts (see `CADDY-SETUP-INSTRUCTIONS.md`)
   - Create `caddy-data` and `caddy-config` directories
   - Restart Caddy

2. **Update AIM Server** (on production server):
   - Pull these changes to your server
   - Set `CADDY_DATA_PATH` in `.env` to point to Caddy's data directory
   - Example: `CADDY_DATA_PATH=/opt/caddy/caddy-data`

3. **Deploy**:
   ```bash
   ./deploy-caddy.sh
   ```

## Configuration Variables

### New Environment Variable

```bash
# In .env file:
CADDY_DATA_PATH=/path/to/caddy/caddy-data
```

**Relative paths:**
```bash
# If directory structure is:
# /opt/caddy/
# /opt/aim-server/
CADDY_DATA_PATH=../caddy/caddy-data
```

**Absolute paths:**
```bash
# Explicit full path
CADDY_DATA_PATH=/opt/caddy/caddy-data
```

## Example Directory Structure

```
/opt/
├── caddy/
│   ├── docker-compose.yml
│   ├── Caddyfile
│   ├── caddy-data/              ← Shared via filesystem
│   │   └── caddy/
│   │       └── certificates/
│   │           └── acme-v02.api.letsencrypt.org-directory/
│   │               └── chat.yourdomain.com/
│   │                   ├── chat.yourdomain.com.crt
│   │                   └── chat.yourdomain.com.key
│   └── caddy-config/
│
└── aim-server/
    ├── docker-compose.yml
    ├── docker-compose.caddy.yml
    ├── .env
    │   └── CADDY_DATA_PATH=../caddy/caddy-data
    └── ...
```

## Verification

After deploying, verify the setup:

1. **Check stunnel can access certificates:**
   ```bash
   docker exec retro-aim-stunnel ls -la /certs/caddy/certificates/
   ```

2. **Check stunnel logs:**
   ```bash
   docker logs retro-aim-stunnel
   ```
   Should show successful certificate loading

3. **Test SSL connection:**
   ```bash
   openssl s_client -connect chat.yourdomain.com:5193
   ```

## Troubleshooting

### "Caddy data directory does not exist"

**Solution:** Set `CADDY_DATA_PATH` in `.env` to the correct path where Caddy stores its data.

### "Permission denied" reading certificates

**Solution:** Ensure the directory is readable:
```bash
sudo chmod -R 755 /path/to/caddy/caddy-data
```

### stunnel shows certificate errors

**Solution:**
1. Verify certificates exist in Caddy's directory
2. Check `CADDY_DATA_PATH` points to the correct location
3. Ensure the path in stunnel.conf matches your chat subdomain

## Benefits of This Approach

✅ **Simpler:** No need for Docker volumes
✅ **Portable:** Works across different server setups
✅ **Debuggable:** Easy to inspect certificates on host filesystem
✅ **Flexible:** Can use relative or absolute paths
✅ **Secure:** Still read-only access for stunnel

## Backward Compatibility

If you have an existing setup with Docker volumes that works, you can continue using it. However, the bind mount approach is recommended for new deployments and is now the default.
