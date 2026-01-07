# 🚀 DEPLOYMENT GUIDE - 5 Steps to Get Running

## Prerequisites Checklist
- [ ] Docker & Docker Compose installed on Optiplex
- [ ] Docker & Docker Compose installed on Raspberry Pi 3
- [ ] **Pi3 connected via Ethernet (NOT WiFi)** to router with static LAN IP (e.g., 192.168.1.100)
  - **⚠️ CRITICAL**: Pi3 must use wired Ethernet connection for stability and reliability
  - WiFi is unreliable for a homelab server (disconnects, latency, interference)
  - Raspberry Pi 3 has built-in Ethernet via USB, or use USB Ethernet adapter
- [ ] Ports 80, 443, 3478/UDP open on Optiplex to internet
- [ ] Domain `murphylab.app` DNS pointing to Optiplex public IP
- [ ] `/mnt/2tb` mounted on Optiplex (2TB HDD)
- [ ] `/mnt/usb` mounted on Pi3 (optional, 128GB USB)

---

## STEP 0: Configure Pi3 Ethernet & Static IP (CRITICAL)

### Why Ethernet is Required

The Raspberry Pi 3 must be connected via **wired Ethernet (not WiFi)** because:
- **Stability**: WiFi on Pi3 has known reliability issues; containers will disconnect
- **Latency**: WiFi adds latency and jitter, breaking agent/service communication
- **VPN**: Headscale agent (tail scale) requires stable connectivity
- **Storage**: Pi3 may need to access network mounts or send data to Optiplex

### Ethernet Connection Options

**Option A: USB Ethernet Adapter (Recommended)**
- Raspberry Pi 3 has only USB 2.0 (no built-in Gigabit Ethernet)
- Use a USB Ethernet adapter: search for "USB 3.0 Ethernet Adapter" or "Raspberry Pi USB Ethernet"
- Connect: USB adapter → Pi3 USB port → Ethernet cable → router

**Option B: Pi3 B+ or Pi 4**
- If you have a Pi3 B+, it has built-in Gigabit Ethernet (recommended upgrade)
- If you have a Pi 4, it also has built-in Gigabit Ethernet

### Configure Static IP on Pi3

```bash
# SSH into Pi3 (find IP from router or run: sudo arp-scan --localnet)
ssh pi@<pi3-ip>

# Edit dhcpcd config for static IP
sudo nano /etc/dhcpcd.conf

# Add these lines at the end (replace with your network):
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1

# Save (Ctrl+O, Enter, Ctrl+X) and reboot
sudo reboot

# After reboot, verify static IP is set
ip addr show eth0
# Should show: inet 192.168.1.100/24 ...
```

**Update your `.env.pi3` with the correct static IP**:
```bash
PI3_IP=192.168.1.100  # Replace with your actual Pi3 static IP
```

---

## STEP 1: Prepare Environment Variables (Updated for New .env Structure)

### Create Shared `.env.common` (Copy to Both Hosts)

```bash
# Copy the template (already created in the repo)
# .env.common is shared across both Optiplex and Pi3
# It contains values that are identical on both hosts

cat .env.common
# Review and adjust if needed (e.g., LETSENCRYPT_EMAIL, TZ, BOOKDATA_PATH)
```

### Create Host-Specific `.env.optiplex` (Optiplex Only)

```bash
# On Optiplex, populate .env.optiplex with secrets and host-specific values
nano .env.optiplex

# Generate strong passwords and fill in:
# VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 32)
# IMMICH_DB_PASSWORD=$(openssl rand -base64 16)
# IMMICH_ADMIN_PASSWORD=$(openssl rand -base64 16)
# ACTUALBUDGET_ADMIN_PASSWORD=$(openssl rand -base64 16)
# N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 16)
# BESZEL_ADMIN_PASSWORD=$(openssl rand -base64 16)
# BESZEL_AGENT_TOKEN=$(openssl rand -hex 32)
# BESZEL_AGENT_KEY=$(openssl rand -base64 48)
# PORTAINER_AGENT_SECRET=$(openssl rand -base64 32)
# OPTIPLEX_IP=192.168.1.50 (replace with your Optiplex LAN IP)

chmod 600 .env.optiplex
```

### Create Host-Specific `.env.pi3` (Pi3 Only)

```bash
# On Pi3, populate .env.pi3 with Pi3-specific secrets
nano .env.pi3

# Generate unique tokens (different from Optiplex):
# BESZEL_AGENT_TOKEN=$(openssl rand -hex 32)
# BESZEL_AGENT_KEY=$(openssl rand -base64 48)
# PORTAINER_AGENT_SECRET=<same-as-optiplex-for-agent-pairing>
# PI3_IP=192.168.1.100 (your Pi3 static Ethernet IP)

chmod 600 .env.pi3
```

**⚠️ CRITICAL**: Replace these in the env files:
- `.env.common`:
  - `LETSENCRYPT_EMAIL`: Your actual email (for Let's Encrypt)
  - `TZ`: Your timezone (e.g., America/New_York)
  - `BOOKDATA_PATH`: Your shared book storage path
- `.env.optiplex`:
  - `OPTIPLEX_IP`: Your actual Optiplex LAN IP
  - All `PASSWORD` and `TOKEN` fields: Generate with `openssl rand -base64 16`
  - `VAULTWARDEN_DOMAIN`: Your domain (e.g., https://vault.murphylab.app)
- `.env.pi3`:
  - `PI3_IP`: Your actual Pi3 static Ethernet IP (from STEP 0)
  - Unique `BESZEL_AGENT_TOKEN` and `BESZEL_AGENT_KEY` (different from Optiplex)
  - `PORTAINER_AGENT_SECRET`: **Same value as Optiplex** (agents use this to pair with server)

---

## STEP 2: Update Dynamic Traefik Config for Pi3

Replace `PI3_IP` placeholder in `traefik/dynamic_pi3.yml`:

```bash
# If your Pi3 IP is 192.168.1.100:
sed -i '' 's/PI3_IP/192.168.1.100/g' traefik/dynamic_pi3.yml

# Verify the changes
grep "http://" traefik/dynamic_pi3.yml
# Should show: http://192.168.1.100:3000, http://192.168.1.100:8080, etc.
```

---

## STEP 3: Start Optiplex Stack

```bash
# Create required directories
mkdir -p traefik/dynamic volumes/paperless/{data,media,export}

# Start all services with env files
docker compose \
  --env-file .env.common \
  --env-file .env.optiplex \
  -f docker-compose.optiplex.yml up -d

# Wait 30 seconds for services to initialize
sleep 30

# Verify all services are running
docker compose -f docker-compose.optiplex.yml ps
```

**Expected Output**: All containers should show `Up` or `Up (healthy)`

**Verify TLS Certificates are Being Generated**:
```bash
# Wait up to 2 minutes for first certificate
sleep 60
ls -lah traefik/acme.json
file traefik/acme.json  # Should show: JSON data
```

---

## STEP 4: Start Pi3 Stack

SSH into your Raspberry Pi 3:

```bash
ssh pi@192.168.1.100  # Use your Pi3 static Ethernet IP from STEP 0

# Create required directories
mkdir -p ~/docker/gatus

# Copy the .env.common file from Optiplex (to keep synchronized)
scp user@optiplex:/path/to/.env.common ~/.env.common

# Create/populate .env.pi3 (already done if you followed STEP 1)
nano .env.pi3  # Verify PI3_IP and secrets are set

# Start services with env files
docker compose \
  --env-file .env.common \
  --env-file .env.pi3 \
  -f docker-compose.pi3.yml up -d

# Verify
docker compose -f docker-compose.pi3.yml ps
```

**Expected**: Portainer Agent, AdGuard, Gatus, Beszel Agent running

**Important**: Keep `.env.common` synchronized between hosts. If you update it on Optiplex, copy it to Pi3:
```bash
scp user@optiplex:~/.env.common ~/.env.common
docker compose -f docker-compose.pi3.yml up -d  # Restart to apply new common vars
```

---

## STEP 5: Connect VPN Clients & Verify

### Create Headscale Pre-Auth Key

```bash
# On Optiplex:
docker exec headscale headscale pre-auth-keys create --user admin --reusable --expiration 24h

# Output: Copy the key (looks like: abc123def456...)
```

### Register Pi3 with VPN

```bash
# On Pi3:
sudo tailscale up \
  --login-server=https://headscale.murphylab.app \
  --authkey=<paste-key-from-above>

# Verify connection
tailscale status
# Should show: 100.64.0.x IP for Pi3
```

### Register Your Laptop/Phone

```bash
# macOS:
brew install tailscale
tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>

# Linux:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>

# Windows:
# Download from https://tailscale.com/download/windows

# Verify
tailscale status
```

---

## ✅ Smoke Test: Verify Everything Works

### Test Public Service (NO VPN NEEDED)
```bash
# Should return HTTP 200
curl -k https://booklore.murphylab.app
```

### Test VPN-Only Service from VPN
```bash
# AFTER connecting to Tailscale, from your VPN-connected device:
curl -k https://vault.murphylab.app
# Should return HTTP 200 with login page
```

### Test VPN Enforcement
```bash
# From a non-VPN network (or different IP):
curl -k https://vault.murphylab.app
# Should return HTTP 403 Forbidden (proves VPN enforcement works!)
```

### Check Traefik Dashboard
```bash
# From VPN-connected device:
# https://traefik.murphylab.app
# Should show all routers, services, and middleware loaded
```

### Check Service Status
```bash
# On Optiplex:
docker-compose -f docker-compose.optiplex.yml ps

# On Pi3:
docker-compose -f docker-compose.pi3.yml ps

# All should show "Up" or "Up (healthy)"
```

---

## 🎉 Deployment Complete!

Your homelab is now running. Here's what you have:

### Admin/Control Interfaces (VPN-only)
- **Traefik Dashboard**: https://traefik.murphylab.app
- **Portainer**: https://portainer.murphylab.app
- **Headscale VPN**: https://headscale.murphylab.app

### Core Services (VPN-only)
- **Password Manager**: https://vault.murphylab.app
- **Photo Library**: https://photos.murphylab.app
- **Documents**: https://paperless.murphylab.app
- **Finance**: https://budget.murphylab.app
- **Workflows**: https://n8n.murphylab.app

### Pi3 Services (VPN-only)
- **DNS**: https://adguard.pi3.murphylab.app
- **Uptime Monitor**: https://gatus.pi3.murphylab.app

> Note: Paperless runs on the Optiplex host at https://paperless.murphylab.app — it is not deployed to the Raspberry Pi 3 due to hardware constraints.

### Public Services
- **Books**: https://booklore.murphylab.app

---

## 📋 Next Steps

1. **Initial Configuration**:
   - [ ] Log in to Portainer and add Pi3 agent
   - [ ] Set up Immich, Vaultwarden, N8N
   - [ ] Configure Paperless admin account (on Optiplex)
   - [ ] Check Gatus uptime dashboard

2. **Backups** (Important!):
   ```bash
   # Backup TLS certificates
   cp traefik/acme.json ~/backups/acme.json.backup
   
   # Backup Portainer data
   docker-compose -f docker-compose.optiplex.yml exec -T portainer tar czf - /data > ~/backups/portainer.tar.gz
   ```

3. **Security**:
   - [ ] Change all default passwords
   - [ ] Restrict .env permissions: `chmod 600 .env`
   - [ ] Set up firewall rules
   - [ ] Enable 2FA on all services

4. **Monitoring**:
   - [ ] Check Gatus dashboard daily
   - [ ] Monitor disk usage: `df -h`
   - [ ] Review Traefik access logs weekly

5. **Maintenance**:
   - [ ] Update images monthly: `docker-compose pull && docker-compose up -d`
   - [ ] Rotate secrets quarterly
   - [ ] Backup data monthly

---

## ⚠️ Troubleshooting Quick Tips

| Problem | Solution |
|---------|----------|
| **TLS cert not issued** | Wait 2-3 min, check `docker logs traefik` |
| **Service shows 502** | Check service logs: `docker logs <name>` |
| **Pi3 unreachable** | Verify `PI3_IP` in `dynamic_pi3.yml`, restart Traefik |
| **VPN won't connect** | Check `docker exec headscale headscale machines list` |
| **403 Forbidden on VPN service** | Verify you're connected to Tailscale: `tailscale status` |
| **Memory issues** | Check `docker stats`, reduce service limits |

For detailed troubleshooting, see **TROUBLESHOOTING.md**

---

## 📚 Documentation

- **README.md** — Full deployment guide with security & advanced config
- **QUICKREF.sh** — One-liner commands for common operations
- **TROUBLESHOOTING.md** — Detailed debugging for all issues
- **MANIFEST.md** — Complete file inventory and architecture

---

## 🛑 Emergency Cleanup (if needed)

```bash
# Stop all services (preserves data)
docker-compose -f docker-compose.optiplex.yml down
docker-compose -f docker-compose.pi3.yml down

# Reset everything (WARNING: deletes all data)
docker-compose -f docker-compose.optiplex.yml down -v
docker system prune -a --volumes
```

---

**🎯 Status**: Ready to deploy | **Version**: 1.0 | **Date**: January 2026
