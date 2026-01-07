# Homelab Docker Stack - File Manifest & Setup Summary

## Overview

This homelab Docker stack deploys a secure, distributed system across two hosts using Traefik v3 for reverse proxy/HTTPS, Headscale for VPN mesh networking, and Docker Compose for orchestration.

**Key Features:**
- ✅ Multi-host deployment (Optiplex x86_64 + Raspberry Pi 3 armv7)
- ✅ Traefik v3 with Let's Encrypt ACME (HTTP challenge)
- ✅ Headscale mesh VPN (Tailscale-compatible, subnet 100.64.0.0/10)
- ✅ VPN-only service access control (IP whitelist middleware)
- ✅ Portainer server/agent for remote management
- ✅ Automatic TLS certificates for all services
- ✅ Health checks and uptime monitoring (Gatus)

---

## Files Generated

### 1. Docker Compose Files

#### **docker-compose.optiplex.yml** (Primary Stack)
- **Purpose**: Services running on Dell Optiplex 7040 (x86_64)
- **Services**:
  - Traefik v3 (reverse proxy, HTTPS, Let's Encrypt)
  - Headscale (VPN control plane)
  - Portainer (container management server)
  - Vaultwarden (password manager, VPN-only)
  - ActualBudget (personal finance, VPN-only)
  - Immich + PostgreSQL (photo library, VPN-only)
  - Paperless-ngx + PostgreSQL (document management, VPN-only)
  - Booklore (book library, PUBLIC)
  - OpenBooks (book search, VPN-only)
  - N8N (workflow automation, VPN-only)
  - Beszel (uptime monitoring, VPN-only)
- **Networks**: `web` (public), `headscale_net` (VPN overlay)
- **Volumes**: All under `/mnt/2tb/docker/` (2TB HDD)

#### **docker-compose.pi3.yml** (Edge Stack)
- **Purpose**: Services running on Raspberry Pi 3 (armv7)
- **Services** (3):
  - Portainer Agent (connects to Optiplex server)
  - AdGuard Home (DNS sinkhole, VPN-only)
  - Gatus (uptime monitoring, VPN-only)
  - **Note**: Paperless removed (resource-constrained Pi3; runs on Optiplex only)
- **Networks**: `pi3_net` (local), `headscale_overlay` (VPN)
- **Volumes**: Mixed storage between `/home/pi/docker/` and `/mnt/usb/`
- **Notes**: Requires `PI3_IP` placeholder replacement in dynamic routing

### 2. Traefik Configuration

#### **traefik/traefik.yml** (Static Configuration)
- **Purpose**: Main Traefik configuration for Optiplex
- **Key Settings**:
  - Entrypoints: `web` (80), `websecure` (443), `headscale-https` (8443)
  - ACME provider: Let's Encrypt with HTTP challenge (default)
  - Provider: Docker (for service labels) + File (for dynamic configs)
  - Logging: INFO level, access logs enabled
  - TLS: TLS 1.2+, strong ciphers
- **Why HTTP Challenge?**: Simpler (no DNS API needed), works for any domain, only requires port 80 open

#### **traefik/dynamic_pi3.yml** (Dynamic Configuration)
- **Purpose**: Routing rules for Pi3 backend services
- **Routers Defined**:
  - `adguard.pi3.murphylab.app` → Pi3 port 3000
  - `gatus.pi3.murphylab.app` → Pi3 port 8080
  - **Note**: Paperless removed from Pi3 routing (runs on Optiplex only)
- **Middleware**: `vpn-only@file` restricts to Headscale subnet (100.64.0.0/10)
- **Important**: Replace `PI3_IP` placeholder with actual Pi3 LAN IP before use

### 3. Headscale (VPN Control Plane)

#### **headscale/config.yaml** (Headscale Configuration)
- **Purpose**: VPN control plane settings
- **Key Settings**:
  - Public URL: `https://headscale.murphylab.app`
  - VPN Subnet: `100.64.0.0/10` (IPv4), `fd7a:115c:a1e0::/48` (IPv6)
  - ACL Policy: `acl.hujson` file
  - Database: SQLite (`/var/lib/headscale/db.sqlite3`)
  - DERP: Uses Tailscale's public servers by default

#### **headscale/acl.hujson** (Access Control List)
- **Purpose**: Define which machines/groups can communicate on VPN
- **Groups**:
  - `group:admins` — full network access
  - `group:optiplex` — main host, unrestricted
  - `group:pi3` — edge host, selective access
  - `group:clients` — user devices, limited access
- **Rules**: HTTPS (443) and DNS (53) ports prioritized
- **Format**: hujson (human JSON, supports comments)

### 4. Gatus (Uptime Monitoring)

#### **gatus/config.yaml** (Gatus Configuration)
- **Purpose**: Service health monitoring for Pi3
- **Endpoints Monitored**:
  - Traefik health check (`/ping`)
  - Headscale API health
  - All major services (Vaultwarden, Immich, N8N, etc.)
  - DNS resolution tests
- **Interval**: 30-60 seconds
- **Alerting**: Slack/Discord webhook templates included
- **Web UI**: `https://gatus.pi3.murphylab.app` (VPN-only)

### 5. Documentation & Setup Tools

#### **README.md** (Comprehensive Guide)
- **Sections**:
  1. Quick Start (5 steps to deployment)
  2. Traefik Configuration (TLS, DNS vs HTTP challenge, VPN enforcement options)
  3. Security (VPN-only service list)
  4. Portainer Setup (server on Optiplex, agent on Pi3)
  5. Headscale Setup (machine registration, client setup, pre-auth keys)
  6. Verification (health checks, TLS validation, VPN testing)
  7. Monitoring (logs, Gatus dashboard)
  8. Maintenance (updates, backups, secret rotation)
  9. Troubleshooting (common issues and solutions)
  10. Advanced (custom service routing)

#### **QUICKREF.sh** (Quick Reference & Commands)
- **Purpose**: One-liner reference for common operations
- **Sections**:
  - Initial setup checklist
  - Docker/Compose management commands
  - Traefik dashboard & route inspection
  - Headscale VPN commands
  - Portainer agent registration
  - Network debugging & testing
  - Service-specific operations
  - TLS certificate verification
  - VPN access testing
  - Backup/restore procedures
  - Service URLs quick list

#### **TROUBLESHOOTING.md** (In-Depth Debugging)
- **Symptoms Covered**:
  1. TLS certificates not issuing (HTTP challenge failures)
  2. Service unreachable or connection refused
  3. 403 Forbidden on VPN-only services
  4. Pi3 services not accessible via Pi3 domain
  5. Headscale clients can't register
  6. High memory usage & container crashes
  7. Slow performance & timeouts
  8. Port already in use conflicts
  9. Traefik dashboard empty (no routes)
- **Each Issue Includes**: Diagnosis commands, root causes, step-by-step solutions

#### **.env.example** (Environment Variables Template)
- **Purpose**: Template for sensitive configuration
- **Variables Covered**:
  - Let's Encrypt: `LETSENCRYPT_EMAIL`
  - DNS provider: `DNS_PROVIDER_API_KEY`
  - Service secrets: 8 service admin passwords
  - Portainer agent: `PORTAINER_AGENT_SECRET`
  - Pi3 networking: `PI3_IP`, `OPTIPLEX_IP`
  - Optional: SMTP, Slack, Discord, S3 backup credentials
- **Security Notes**: Includes password generation examples

#### **setup.sh** (Interactive Setup Script)
- **Purpose**: Automate deployment & verification steps
- **Modes**:
  - Interactive menu (default)
  - Command-line mode (`setup.sh verify`, etc.)
- **Functions**:
  - Check prerequisites (Docker, Docker Compose)
  - Verify environment variables
  - Bring up stacks
  - Verify Traefik, TLS, Headscale
  - Test VPN enforcement
  - Show service status & networks
  - Create Headscale pre-auth keys
  - Full verification suite
  - Cleanup & rollback

---

## Deployment Workflow

### Step 1: Prepare Environment
```bash
cp .env.example .env
nano .env              # Edit with passwords, emails, IPs
source .env
```

### Step 2: Initial Setup (Optiplex)
```bash
mkdir -p traefik/dynamic volumes/paperless/{data,media,export}
sed -i '' 's/PI3_IP/192.168.1.100/g' traefik/dynamic_pi3.yml
docker-compose -f docker-compose.optiplex.yml up -d
```

### Step 3: Verify Optiplex
```bash
docker-compose -f docker-compose.optiplex.yml ps
sleep 60  # Wait for TLS cert generation
curl -k https://booklore.murphylab.app  # Test public service
```

### Step 4: Setup Pi3 (on Pi hardware)
```bash
docker-compose -f docker-compose.pi3.yml up -d
docker-compose -f docker-compose.pi3.yml ps
```

### Step 5: Connect VPN Clients
```bash
# Create pre-auth key on Optiplex
docker exec headscale headscale pre-auth-keys create --reusable --expiration 24h

# On Pi3:
sudo tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>

# On laptop/phone:
tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>
```

### Step 6: Verify Deployment
```bash
# Check all services running
docker ps

# Test VPN-only service (from VPN-connected device)
curl -k https://vault.murphylab.app

# Check Gatus dashboard
# https://gatus.pi3.murphylab.app (VPN-only)
```

---

## Networking Summary

### Domains & Services

| Service | URL | Host | Access | Port |
|---------|-----|------|--------|------|
| **Admin/Control** |
| Traefik Dashboard | `traefik.murphylab.app` | Optiplex | VPN-only | 8080 |
| Headscale VPN | `headscale.murphylab.app` | Optiplex | VPN-only | 8080 |
| Portainer UI | `portainer.murphylab.app` | Optiplex | VPN-only | 9000 |
| **Data/Storage** |
| Vaultwarden | `vault.murphylab.app` | Optiplex | VPN-only | 80 |
| Immich | `photos.murphylab.app` | Optiplex | VPN-only | 3001 |
| Paperless | `paperless.murphylab.app` | Optiplex | VPN-only | 8000 |
| Booklore | `booklore.murphylab.app` | Optiplex | PUBLIC | 3000 |
| OpenBooks | `openbooks.murphylab.app` | Optiplex | VPN-only | 80 |
| **Automation** |
| N8N | `n8n.murphylab.app` | Optiplex | VPN-only | 5678 |
| ActualBudget | `budget.murphylab.app` | Optiplex | VPN-only | 3000 |
| **Monitoring** |
| Beszel | `beszel.murphylab.app` | Optiplex | VPN-only | 8080 |
| Gatus | `gatus.pi3.murphylab.app` | Pi3 | VPN-only | 8080 |
| **Pi3 Edge Services** |
| AdGuard | `adguard.pi3.murphylab.app` | Pi3 | VPN-only | 3000 |

### Networks

| Network | Subnet | Purpose | Hosts |
|---------|--------|---------|-------|
| `web` | Bridge | Public HTTPS routing | Traefik, all services |
| `headscale_net` | 100.64.0.0/10 | VPN overlay | Headscale, clients |
| `pi3_net` | Bridge | Pi3 local only | Portainer agent, AdGuard, Gatus |

---

## Security Model

### VPN-Only Enforcement
1. **Mechanism**: IP whitelist middleware in Traefik
2. **Whitelist Range**: `100.64.0.0/10` (Headscale overlay)
3. **Exceptions**: `127.0.0.1/32` (localhost for testing)
4. **Behavior**: Non-VPN IPs receive HTTP 403 Forbidden

### Service Exposure
- **Public**: Booklore (with optional basic auth)
- **VPN-Only**: All admin/control, data, and sensitive services
- **Local-Only (Pi3)**: Portainer agent, docker socket

### TLS/HTTPS
- **Certificates**: Let's Encrypt wildcard (?), per-hostname
- **Challenge**: HTTP (port 80 required, simpler)
- **Auto-renewal**: ACME, built into Traefik
- **Storage**: `traefik/acme.json` (backed up regularly)

---

## Storage Layout

### Optiplex (/mnt/2tb/)
```
/mnt/2tb/
├── docker/
│   ├── portainer/
│   ├── vaultwarden/
│   ├── immich/ (symlink to ../immich-photos/)
│   ├── immich-db/
│   ├── actualbudget/
│   ├── booklore/
│   ├── openbooks/
│   ├── n8n/
│   ├── beszel/
│   ├── headscale/
│   └── paperless/
├── bookdata/  # shared host path mounted into OpenBooks and Booklore
│   ├── books/     # persisted book files
│   └── bookdrop/  # BookDrop watched folder
├── immich-photos/ (large, separate mount)
└── backups/
```

### Raspberry Pi 3
```
/home/pi/
├── docker/
│   ├── portainer-agent/
│   └── (Pi3 service volumes; Paperless is hosted on the Optiplex host)
/mnt/usb/ (128GB USB)
├── media/ (used by Pi3 services; Paperless media is stored on Optiplex)
└── backups/
```

---

## Performance & Resource Allocation

### Optiplex Allocation
- **Total**: 16GB RAM, 2x CPUs reserved for Docker
- **Traefik**: 1 CPU, 1GB RAM (critical)
- **Immich**: 2 CPU, 2GB RAM (photo processing)
- **Paperless**: 1 CPU, 1GB RAM (OCR)
- **Others**: 0.5 CPU, 256-512MB each

### Pi3 Allocation
- **Total**: ~512MB available (1GB - OS)
- **Portainer Agent**: 0.3 CPU, 128MB
- **AdGuard**: 0.4 CPU, 256MB
- **Gatus**: 0.3 CPU, 128MB
- **Paperless** (optional): 0.8 CPU, 512MB (lightweight)

---

## Maintenance Tasks

### Weekly
- [ ] Check Gatus dashboard for service health
- [ ] Review Traefik access logs for errors
- [ ] Monitor disk usage: `df -h /mnt/2tb /mnt/usb`

### Monthly
- [ ] Update Docker images: `docker-compose pull && docker-compose up -d`
- [ ] Check TLS certificate expiration: `openssl s_client -connect murphylab.app:443`
- [ ] Backup important volumes (portainer, vaultwarden, immich-db)

### Quarterly
- [ ] Rotate secrets (passwords, API keys)
- [ ] Update Headscale ACL policy if topology changes
- [ ] Review VPN clients and remove inactive machines

### Annually
- [ ] Full system backup (all volumes)
- [ ] Test disaster recovery procedure
- [ ] Review and update documentation

---

## Rollback Procedure

### If Deployment Fails
```bash
# Stop stack without removing volumes (preserve data)
docker-compose -f docker-compose.optiplex.yml down

# Restore from previous image version:
sed -i '' 's/traefik:v3.6/traefik:v3.5/' docker-compose.optiplex.yml

# Bring up with old version
docker-compose -f docker-compose.optiplex.yml up -d

# Check logs for issues
docker logs traefik -f
```

### If Need to Remove Everything
```bash
# WARNING: This deletes all data!
docker-compose -f docker-compose.optiplex.yml down -v
docker network prune
docker system prune -a --volumes
```

---

## Support & References

- **Traefik v3 Docs**: https://doc.traefik.io/traefik/
- **Headscale Docs**: https://github.com/juanfont/headscale/wiki
- **Docker Compose**: https://docs.docker.com/compose/compose-file/compose-file-v3-8/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **Tailscale**: https://tailscale.com/

---

## Quick Checklist for Deployment

- [ ] `.env` file created and populated with secrets
- [ ] `docker-compose.optiplex.yml` present and valid
- [ ] `docker-compose.pi3.yml` present and valid
- [ ] `traefik/traefik.yml` configured
- [ ] `traefik/dynamic_pi3.yml` updated with actual Pi3 IP
- [ ] `headscale/config.yaml` and `acl.hujson` in place
- [ ] `gatus/config.yaml` configured for Pi3
- [ ] Docker & Docker Compose installed
- [ ] Ports 80, 443, 3478/UDP open on Optiplex firewall
- [ ] Pi3 reachable on LAN with known static IP
- [ ] Directory `/mnt/2tb` mounted and writable on Optiplex
- [ ] Directory `/mnt/usb` mounted on Pi3 (optional but recommended)
- [ ] DNS domain `murphylab.app` pointing to public IP

---

**Deployment Date**: January 2026
**Stack Version**: Traefik v3.6, Headscale Latest, Docker Compose v3.8
**Homelab Status**: Ready for production use ✅
