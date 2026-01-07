# Homelab Docker Stack: Multi-Host Setup Guide

## Overview

This stack deploys a secure, distributed homelab across two hosts:
- **Optiplex (x86_64)**: Main host with Traefik, Headscale VPN, Portainer server, core services
- **Raspberry Pi 3 (armv7)**: Edge host with Portainer agent, AdGuard, Gatus, Paperless

**Domain**: `murphylab.app`
**Headscale VPN Subnet**: `100.64.0.0/10`
**TLS Certificate Resolver**: ACME (Let's Encrypt) via HTTP challenge

---

## Files Included

1. **docker-compose.optiplex.yml** — Main stack for Dell Optiplex 7040
2. **docker-compose.pi3.yml** — Services for Raspberry Pi 3
3. **traefik/traefik.yml** — Traefik static configuration (ACME, entrypoints, TLS)
4. **traefik/dynamic_pi3.yml** — Dynamic routing for Pi3 backend services
5. **setup.sh** — Interactive setup and verification script
6. **README.md** — This file

---

## Prerequisites

### Optiplex Requirements
- Docker Engine ≥ 20.10
- Docker Compose ≥ 1.29
- 16GB RAM (allocate 4-6GB for containers)
- External HDD mounted at `/mnt/2tb` (2TB)
- Port 80, 443 open to internet for HTTPS
- Port 3478/UDP open for Headscale UDP signaling

### Raspberry Pi 3 Requirements
- Docker & Docker Compose installed (use Raspberry Pi OS)
- 128GB USB mounted at `/mnt/usb`
- Static LAN IP (e.g., `192.168.1.100`) — note this for later
- Network connectivity to Optiplex on LAN
- Port 9001/TCP open for Portainer agent (LAN only)

---

## Quick Start

### 1. Prepare Environment Variables

Create a `.env` file in the project root:

```bash
cat > .env << 'EOF'
# TLS / Let's Encrypt
LETSENCRYPT_EMAIL=admin@murphylab.app

# DNS provider credentials (if using DNS challenge; optional for HTTP challenge)
DNS_PROVIDER_API_KEY=your-cloudflare-api-key

# Service credentials (generate strong passwords)
VAULTWARDEN_ADMIN_TOKEN=$(openssl rand -base64 32)
IMMICH_DB_PASSWORD=$(openssl rand -base64 16)
IMMICH_ADMIN_PASSWORD=$(openssl rand -base64 16)
ACTUALBUDGET_ADMIN_PASSWORD=$(openssl rand -base64 16)
N8N_BASIC_AUTH_PASSWORD=$(openssl rand -base64 16)
BESZEL_ADMIN_PASSWORD=$(openssl rand -base64 16)
HEADSCALE_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Pi3 specifics (update with actual Pi3 IP)
PI3_IP=192.168.1.100
OPTIPLEX_IP=192.168.1.50
PORTAINER_AGENT_SECRET=$(openssl rand -base64 32)
EOF

# Make environment variables available
source .env
```

### 2. Update Dynamic Configuration for Pi3

Before bringing up the stack, update `traefik/dynamic_pi3.yml` with the actual Pi3 LAN IP:

```bash
# Replace placeholder PI3_IP with actual Pi3 IP (e.g., 192.168.1.100)
sed -i '' 's/PI3_IP/192.168.1.100/g' traefik/dynamic_pi3.yml
```

Or manually edit the file and replace `PI3_IP` in two places:
- `adguard-pi3` service URL
- `gatus-pi3` service URL

### 3. Bring Up Optiplex Stack

```bash
# Create necessary directories
mkdir -p traefik/dynamic volumes/paperless/{data,media,export}

# Start Optiplex services
docker-compose -f docker-compose.optiplex.yml up -d

# Verify all services are running
docker-compose -f docker-compose.optiplex.yml ps
```

**Expected output**: Traefik, Headscale, Portainer, Vaultwarden, Immich, and all other services in `Up` state.

### 4. Bring Up Pi3 Stack

SSH into Pi3 and run:

```bash
# Copy Pi3 compose file to Pi
scp docker-compose.pi3.yml pi@192.168.1.100:~/

# SSH into Pi
ssh pi@192.168.1.100

# Create necessary directories
mkdir -p /home/pi/docker/paperless/{data,export}
mkdir -p /mnt/usb/paperless/media

# Start Pi3 services
docker-compose -f docker-compose.pi3.yml up -d

# Verify
docker-compose -f docker-compose.pi3.yml ps
```

---

## Traefik Configuration

### TLS/Let's Encrypt Strategy

**HTTP Challenge** (current default):
- ✅ Simpler, no DNS provider API key needed
- ✅ Works for any DNS provider
- ⚠️ Requires port 80 to be open to internet
- ⚠️ Cannot issue wildcard certificates
- 📝 Certificates issued per hostname (e.g., `vault.murphylab.app`)

**DNS Challenge** (alternative):
- ✅ Can issue wildcard certificates (`*.murphylab.app`)
- ✅ Works behind firewall (no public port 80 needed)
- ⚠️ Requires DNS provider API credentials
- 📝 More complex but better for fully private internal networks

**To use DNS challenge**, edit `traefik/traefik.yml`:
1. Comment out `httpChallenge` section
2. Uncomment `dnsChallenge` section
3. Set provider (e.g., `cloudflare`)
4. Export DNS provider API key: `export CLOUDFLARE_API_KEY=<key>`

### VPN-Only Enforcement Options

#### Option 1: Middleware IP Whitelist (Current)

All VPN-only services use the `vpn-only@file` middleware defined in `traefik/dynamic_pi3.yml` (and in dynamic files for Optiplex services).

This middleware restricts access to the Headscale subnet (`100.64.0.0/10`).

**Advantage**: Simple, flexible, works with dynamic IPs on VPN
**Disadvantage**: Requires proper whitelist maintenance

#### Option 2: Separate Headscale EntryPoint

Create an internal-only HTTPS port bound to the Headscale interface IP.

**In traefik.yml**, entrypoint `headscale-https` is already defined on port 8443.

To use it:
1. Add services to use `headscale-https` entrypoint instead of `websecure`
2. Bind to Headscale interface IP (requires advanced network setup)

**Advantage**: Physically isolated routing
**Disadvantage**: Complex, requires separate certificates, static IPs

**Recommendation**: Use Option 1 (IP whitelist middleware) for ease and flexibility.

---

## Security: VPN-Only Services

The following services are marked **VPN-only** and accessible only from Headscale tunnel IPs:

### On Optiplex:
- Traefik Dashboard (`traefik.murphylab.app`)
- Vaultwarden (`vault.murphylab.app`)
- ActualBudget (`budget.murphylab.app`)
- Immich (`photos.murphylab.app`)
- Paperless (`paperless.murphylab.app`)
- OpenBooks (`openbooks.murphylab.app`)
- N8N (`n8n.murphylab.app`)
- Beszel (`beszel.murphylab.app`)
- Portainer UI (`portainer.murphylab.app`)
- Headscale (`headscale.murphylab.app`)

### On Pi3:
- AdGuard (`adguard.pi3.murphylab.app`)
- Gatus (`gatus.pi3.murphylab.app`)
> Note: Paperless is intentionally hosted on the Optiplex host (https://paperless.murphylab.app). The Raspberry Pi 3 does not run Paperless due to resource constraints.

### Public Services (optional auth):
- Booklore (`booklore.murphylab.app`) — basic app auth available

---

## Portainer: Server & Agent Setup

### Server (Optiplex)
- Running in `docker-compose.optiplex.yml`
- UI at `https://portainer.murphylab.app` (VPN-only)
- Port 9000 internal

### Agent (Pi3)
- Running in `docker-compose.pi3.yml`
- Port 9001 (LAN only, no internet exposure)
- Automatically connects to server if reachable

### Register Pi3 Agent in Portainer UI:
1. Log in to Portainer (`https://portainer.murphylab.app`)
2. **Environments → Add Environment → Docker Standalone Edge**
3. Set:
   - **Agent URL**: `http://192.168.1.100:9001` (replace with actual Pi3 IP)
   - **Name**: `pi3` or `Raspberry-Pi-3`
4. Save and verify connection status

---

## Headscale: Setup & Add Clients

### Initialize Headscale (one-time)

```bash
# Get Headscale container shell
docker exec -it headscale bash

# Create initial admin user
headscale users create admin

# Create a reusable pre-auth key (24-hour expiry)
headscale pre-auth-keys create --user admin --reusable --expiration 24h

# Output will show a key like: abc123def456...
# Save this key for registering devices
```

### Add Tailscale Client to Pi3

```bash
# SSH to Pi3
ssh pi@192.168.1.100

# Install Tailscale (on Raspberry Pi OS)
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate with Headscale
sudo tailscale up \
  --login-server=https://headscale.murphylab.app \
  --authkey=<pre-auth-key-from-above>

# Verify connection
sudo tailscale status

# You should see Pi3's Headscale IP (e.g., 100.64.0.2)
```

### Add Client Device (e.g., laptop, phone)

Same as above, but run locally on your device:

```bash
# macOS
brew install tailscale

# Linux
curl -fsSL https://tailscale.com/install.sh | sh

# Windows: Download from https://tailscale.com/download

# Authenticate
tailscale up \
  --login-server=https://headscale.murphylab.app \
  --authkey=<pre-auth-key>

# Check status
tailscale status
```

---

## Verify Deployment

### 1. Check Service Health

```bash
# Optiplex
docker-compose -f docker-compose.optiplex.yml ps

# Pi3
docker-compose -f docker-compose.pi3.yml ps
```

All services should show `Up` (or `Up (healthy)` if healthchecks are configured).

### 2. Verify TLS Certificates

```bash
# Check certificate existence
ls -la traefik/acme.json

# View certificate details
docker exec traefik cat /acme/acme.json | jq '.[] | .Certificates[0] | {domain: .Domain, expiration: .Certificate.Expiration}'
```

### 3. Test Headscale Connectivity

```bash
# From your VPN-connected device (e.g., laptop on Tailscale)
ping 100.64.0.1  # Headscale control plane
ping 100.64.0.2  # Pi3 (if registered)

# Check machines list
docker exec headscale headscale machines list
```

### 4. Test Public vs VPN-Only Access

```bash
# PUBLIC ACCESS (should work)
curl -k https://booklore.murphylab.app

# VPN-ONLY ACCESS (should return 403 from non-VPN IP)
curl -k https://vault.murphylab.app
# Expected: HTTP 403 Forbidden

# ACCESS FROM VPN (should work)
# Connect to Tailscale, then:
curl -k https://vault.murphylab.app
# Expected: HTTP 200 OK
```

### 5. Check Traefik Dashboard

```bash
# From VPN-connected device only:
# https://traefik.murphylab.app

# Verify routers, services, and middlewares are loaded
# Look for `vpn-only@file` middleware in all VPN-only services
```

---

## Monitoring & Logs

### View Service Logs

```bash
# Traefik logs
docker-compose -f docker-compose.optiplex.yml logs -f traefik

# Headscale logs
docker-compose -f docker-compose.optiplex.yml logs -f headscale

# Portainer logs
docker-compose -f docker-compose.optiplex.yml logs -f portainer

# Pi3 services
docker-compose -f docker-compose.pi3.yml logs -f adguard
```

### Gatus Uptime Monitoring

- **Endpoint**: `https://gatus.pi3.murphylab.app` (VPN-only)
- Monitor health of all services on Pi3 and upstream

---

## Maintenance

### Update Service Images

```bash
# Optiplex
docker-compose -f docker-compose.optiplex.yml pull
docker-compose -f docker-compose.optiplex.yml up -d

# Pi3
docker-compose -f docker-compose.pi3.yml pull
docker-compose -f docker-compose.pi3.yml up -d
```

### Backup Data

```bash
# Backup Optiplex volumes
docker run --rm -v optiplex_db:/data -v /backups:/backup alpine tar czf /backup/optiplex-backup.tar.gz /data

# Backup Pi3 volumes
ssh pi@192.168.1.100 "tar czf ~/backup.tar.gz /home/pi/docker /mnt/usb"
scp pi@192.168.1.100:~/backup.tar.gz /backups/pi3-backup.tar.gz
```

### Rotate Secrets

```bash
# Generate new password
new_secret=$(openssl rand -base64 32)

# Update .env
sed -i '' "s/OLD_SECRET/$new_secret/" .env

# Redeploy affected service
docker-compose -f docker-compose.optiplex.yml up -d <service-name>
```

---

## Troubleshooting

### TLS Certificates Not Issuing

**Symptoms**: Traefik returns self-signed cert, HTTP challenge fails

**Solutions**:
1. Verify port 80 is open to internet: `curl -I http://yourip`
2. Check Traefik logs: `docker logs traefik`
3. Verify LETSENCRYPT_EMAIL is set
4. Wait 2-3 minutes for ACME challenge to complete
5. Try `docker restart traefik`

### Headscale Clients Can't Connect

**Symptoms**: `tailscale status` shows "connecting"

**Solutions**:
1. Verify `headscale.murphylab.app` is resolvable from client device
2. Ensure port 3478/UDP is open on Optiplex
3. Check Headscale logs: `docker logs headscale`
4. Verify pre-auth key is still valid (not expired)

### Pi3 Services Not Accessible via Pi3 Domain

**Symptoms**: `adguard.pi3.murphylab.app` returns 404 or timeout

**Solutions**:
1. Verify `PI3_IP` in `traefik/dynamic_pi3.yml` is correct
2. Test direct access: `curl -k http://192.168.1.100:3000` (AdGuard)
3. Verify Pi3 IP is reachable from Optiplex: `ping 192.168.1.100`
4. Check Traefik logs for routing errors
5. Verify dynamic_pi3.yml is loaded: `curl http://localhost:8080/api/routes` (from Optiplex)

### VPN-Only Services Accessible Without VPN

**Symptoms**: Can curl `https://vault.murphylab.app` from public internet

**Solutions**:
1. Verify `vpn-only@file` middleware is loaded in Traefik
2. Check IP whitelist range in dynamic config: `100.64.0.0/10`
3. Verify client IP is actually in Headscale subnet: `tailscale status` shows 100.64.x.x
4. Restart Traefik to reload middleware: `docker restart traefik`

### Container OOM (Out of Memory)

**Symptoms**: Containers killed with exit code 137

**Solutions**:
1. Check memory limits in compose files
2. Increase Docker memory limit on Pi3 (only 1GB available)
3. Reduce service resource requests or disable less-critical services
4. Add memory swaps (not recommended for SD card Pi)

---

## Rollback & Cleanup

### Stop All Services

```bash
# Optiplex
docker-compose -f docker-compose.optiplex.yml down

# Pi3
docker-compose -f docker-compose.pi3.yml down
```

### Remove Volumes (WARNING: Data Loss)

```bash
# Optiplex
docker-compose -f docker-compose.optiplex.yml down -v

# Pi3
docker-compose -f docker-compose.pi3.yml down -v
```

### Remove Networks

```bash
docker network rm homelab_web homelab_headscale_net
```

### Clean Up Docker System

```bash
docker system prune -a --volumes
```

---

## Advanced: Custom Service Routing

To add a new service to either Optiplex or Pi3:

### 1. Add to docker-compose file

```yaml
myservice:
  image: myservice:latest
  container_name: myservice
  restart: unless-stopped
  environment:
    LOG_LEVEL: "info"
  volumes:
    - ./volumes/myservice:/data
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 256M
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 5s
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.myservice.rule=Host(`myservice.murphylab.app`)"
    - "traefik.http.routers.myservice.entrypoints=websecure"
    - "traefik.http.routers.myservice.tls.certresolver=letsencrypt"
    - "traefik.http.services.myservice.loadbalancer.server.port=3000"
    # For VPN-only:
    - "traefik.http.routers.myservice.middlewares=vpn-only@file"
  networks:
    - web
    - headscale_net  # if VPN-only
```

### 2. Restart services

```bash
docker-compose -f docker-compose.optiplex.yml up -d myservice
```

### 3. Verify routing in Traefik dashboard

---

## Performance Tuning

### Traefik
- Set `maxConcurrentStreams: 500` in `traefik.yml` for high load
- Enable access logging only if needed (disk I/O overhead)

### Immich
- Increase memory limit to 4GB if handling large photo libraries
- Use `/srv/docker/immich` on external SSD for fast thumbnail generation

### Paperless
- Increase CPU to 2 cores if OCR is slow
- Use fast storage (SSD preferred)

### Headscale
- Monitor `/var/lib/headscale/db.sqlite3` growth
- Prune old machine keys periodically

---

## Support & References

- **Traefik Docs**: https://doc.traefik.io/traefik/
- **Headscale**: https://github.com/juanfont/headscale
- **Docker Compose**: https://docs.docker.com/compose/compose-file/compose-file-v3-8/
- **Let's Encrypt**: https://letsencrypt.org/
- **Tailscale (client)**: https://tailscale.com/

---

## Summary Checklist

- [ ] `.env` file created with all secrets
- [ ] Pi3 LAN IP noted and `dynamic_pi3.yml` updated
- [ ] Optiplex stack brought up (`docker-compose.optiplex.yml up -d`)
- [ ] TLS certificates issued (check `traefik/acme.json`)
- [ ] Headscale initialized and pre-auth key created
- [ ] Pi3 stack brought up (`docker-compose.pi3.yml up -d`)
- [ ] Pi3 registered with Portainer agent
- [ ] Tailscale clients (Pi3, laptop, etc.) connected via Headscale
- [ ] Public services tested (e.g., booklore)
- [ ] VPN-only services verified (403 without VPN, 200 with VPN)
- [ ] Gatus uptime monitoring active

**Deployment complete!** 🎉
