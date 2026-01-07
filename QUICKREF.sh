#!/bin/bash
# Homelab Quick Reference & Common Commands
# Save as: QUICKREF.sh (chmod +x)

set -e

cat << 'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                    HOMELAB DOCKER - QUICK REFERENCE GUIDE                    ║
╚══════════════════════════════════════════════════════════════════════════════╝

## INITIAL SETUP

1. Create .env file:
   cp .env.example .env
   nano .env          # Edit with actual passwords and IPs

2. Create directories:
   mkdir -p traefik/dynamic volumes/paperless/{data,media,export}

3. Update Pi3 IP in dynamic config:
   sed -i '' 's/PI3_IP/192.168.1.100/g' traefik/dynamic_pi3.yml

4. Start Optiplex stack:
   source .env
   docker-compose -f docker-compose.optiplex.yml up -d

5. Start Pi3 stack (from Pi3):
   docker-compose -f docker-compose.pi3.yml up -d

═══════════════════════════════════════════════════════════════════════════════

## QUICK COMMANDS

### Compose Management
   # Start all services
   docker-compose -f docker-compose.optiplex.yml up -d

   # View running services
   docker-compose -f docker-compose.optiplex.yml ps

   # View logs (follow)
   docker-compose -f docker-compose.optiplex.yml logs -f [service-name]

   # Restart a service
   docker-compose -f docker-compose.optiplex.yml restart [service-name]

   # Stop all services
   docker-compose -f docker-compose.optiplex.yml down

   # Remove volumes (WARNING: data loss)
   docker-compose -f docker-compose.optiplex.yml down -v

### Image Updates
   # Pull latest images
   docker-compose -f docker-compose.optiplex.yml pull

   # Recreate containers with latest images
   docker-compose -f docker-compose.optiplex.yml up -d

### Traefik
   # View Traefik dashboard (VPN-only):
   https://traefik.murphylab.app

   # Check Traefik logs:
   docker-compose -f docker-compose.optiplex.yml logs -f traefik

   # Check loaded routes:
   curl http://localhost:8080/api/http/routers

   # Test TLS cert:
   openssl s_client -connect murphylab.app:443 -servername murphylab.app

### Headscale / VPN
   # List registered machines:
   docker exec headscale headscale machines list

   # Create pre-auth key:
   docker exec headscale headscale pre-auth-keys create --reusable --expiration 24h

   # View Headscale routes:
   docker exec headscale headscale routes list

   # Rename a machine:
   docker exec headscale headscale machines rename <id> <new-name>

### Portainer
   # UI (VPN-only):
   https://portainer.murphylab.app

   # Register Pi3 agent manually:
   # Environments → Add Environment → Docker Standalone Edge
   # Agent URL: http://192.168.1.100:9001

### Network Debugging
   # Test service connectivity from Optiplex:
   docker exec traefik curl -I http://localhost:80

   # Test Pi3 reachability:
   ping 192.168.1.100

   # Test DNS resolution:
   nslookup vault.murphylab.app

   # Check Docker networks:
   docker network ls
   docker network inspect web

### Service-Specific Commands
   
   ## Immich
   # Rebuild thumbnails:
   docker exec immich immich admin fix-assets
   
   ## Vaultwarden
   # Check admin panel:
   https://vault.murphylab.app/admin (VPN-only)
   
   ## N8N
   # Export workflows:
   docker exec n8n n8n export:workflow --all
   
   ## Paperless
   # Admin panel:
   https://paperless.murphylab.app/admin (VPN-only)

═══════════════════════════════════════════════════════════════════════════════

## TESTING & VERIFICATION

### TLS Certificate Check
   # View certificate details:
   openssl s_client -connect murphylab.app:443 < /dev/null | openssl x509 -noout -text

   # Check expiration:
   echo | openssl s_client -servername vault.murphylab.app -connect murphylab.app:443 2>/dev/null | openssl x509 -noout -dates

### VPN-Only Service Access
   # Without VPN (should return 403):
   curl -k https://vault.murphylab.app
   
   # With VPN (should return 200):
   # First: connect to Tailscale
   tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>
   # Then: curl https://vault.murphylab.app

### Public Service Access
   # Should always work (no VPN needed):
   curl -k https://booklore.murphylab.app

### Service Health
   # Check all service health:
   docker ps --format "table {{.Names}}\t{{.Status}}"

   # Detailed health info:
   docker inspect <container-name> | jq '.[0].State.Health'

═══════════════════════════════════════════════════════════════════════════════

## TROUBLESHOOTING

### Traefik Not Issuing Certificates
   1. Check port 80 is open: curl -I http://murphylab.app
   2. View Traefik logs: docker-compose logs traefik
   3. Verify LETSENCRYPT_EMAIL is set: echo $LETSENCRYPT_EMAIL
   4. Wait 2-3 min, restart: docker restart traefik

### Service Unreachable via Domain
   1. Verify Traefik has loaded route: curl http://localhost:8080/api/http/routers
   2. Check service health: docker ps (should show "Up")
   3. Test service directly: curl http://localhost:3000 (for port 3000)
   4. Check logs: docker logs <container-name>
   5. Restart service: docker restart <container-name>

### VPN Connection Issues
   1. Check Headscale is running: docker ps | grep headscale
   2. View Headscale logs: docker logs headscale
   3. Verify client IP on VPN: tailscale status
   4. Check headscale.murphylab.app is resolvable: nslookup headscale.murphylab.app
   5. Verify pre-auth key is valid: docker exec headscale headscale pre-auth-keys list

### Pi3 Services Not Accessible
   1. Verify Pi3 IP in dynamic_pi3.yml: grep "PI3_IP" traefik/dynamic_pi3.yml
   2. Test direct access: curl http://192.168.1.100:3000
   3. Ping Pi3: ping 192.168.1.100
   4. Check dynamic config loaded: curl http://localhost:8080/api/http/routers | grep pi3
   5. Restart Traefik: docker restart traefik

### High Memory Usage
   1. Check container memory: docker stats
   2. Identify high-memory containers: docker ps --format "{{.Names}}: {{.Size}}"
   3. Increase Optiplex allocation or reduce service limits in compose file
   4. For Pi3: disable resource-intensive services (e.g., Immich, OCR in Paperless)

═══════════════════════════════════════════════════════════════════════════════

## BACKUP & RESTORE

### Backup Volumes (Optiplex)
   mkdir -p /backups
   docker run --rm -v traefik_acme:/data -v /backups:/backup alpine tar czf /backup/traefik-acme.tar.gz /data

### Backup All Services Data
   # From Optiplex:
   docker-compose -f docker-compose.optiplex.yml exec -T portainer tar czf - /data | gzip > /backups/portainer-backup.tar.gz

### Restore from Backup
   # Extract to volume:
   docker run --rm -v portainer_data:/restore -v /backups:/backup alpine tar xzf /backup/portainer-backup.tar.gz -C /restore --strip-components=1

═══════════════════════════════════════════════════════════════════════════════

## SERVICE URLS (VPN-Only)

   https://traefik.murphylab.app       - Traefik dashboard
   https://vault.murphylab.app         - Vaultwarden (passwords)
   https://budget.murphylab.app        - ActualBudget (finance)
   https://photos.murphylab.app        - Immich (photos)
   https://paperless.murphylab.app     - Paperless (docs)
   https://openbooks.murphylab.app     - OpenBooks (books)
   https://n8n.murphylab.app           - N8N (workflows)
   https://beszel.murphylab.app        - Beszel (monitoring)
   https://portainer.murphylab.app     - Portainer (container mgmt)
   https://headscale.murphylab.app     - Headscale (VPN control)

   https://adguard.pi3.murphylab.app   - AdGuard (DNS, Pi3)
   https://gatus.pi3.murphylab.app     - Gatus (uptime, Pi3)
   # Paperless runs on the Optiplex host
   https://paperless.murphylab.app     - Paperless (docs, Optiplex)

## PUBLIC SERVICES

   https://booklore.murphylab.app      - Booklore (public, with app auth)

═══════════════════════════════════════════════════════════════════════════════

## SECURITY NOTES

- Change all default passwords immediately
- Restrict .env file: chmod 600 .env
- Use firewall rules to limit port 80, 443 to trusted sources
- Rotate secrets every 90 days
- Monitor Gatus dashboard for service uptime
- Regularly back up acme.json (TLS certs)
- Keep Docker images updated: docker-compose pull && docker-compose up -d

═══════════════════════════════════════════════════════════════════════════════

For full documentation, see README.md

EOF
