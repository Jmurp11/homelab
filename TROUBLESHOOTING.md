# Homelab Docker Stack - Troubleshooting & Debugging Guide

## Symptom: TLS Certificates Not Issuing

### Problem: "self-signed certificate in certificate chain"

**Causes:**
- Port 80 not open to internet for HTTP challenge
- DNS not resolving to Optiplex public IP
- LETSENCRYPT_EMAIL not set or invalid
- ACME challenge timeout (30+ seconds)

**Diagnosis:**
```bash
# Check if port 80 is accessible from internet
nmap -p 80 murphylab.app  # From external IP, should show "open"

# Check DNS resolution
dig murphylab.app +short  # Should return your public IP

# View Traefik logs for ACME errors
docker-compose -f docker-compose.optiplex.yml logs traefik | grep -i acme

# Check acme.json exists and has data
ls -la traefik/acme.json
wc -l traefik/acme.json  # Should be > 1000 bytes

# Check LETSENCRYPT_EMAIL
echo $LETSENCRYPT_EMAIL
```

**Solutions:**
1. **Open port 80:**
   - Check firewall rules: `sudo ufw status` (UFW) or `sudo iptables -L` (iptables)
   - Port forward 80→80 on your router to Optiplex LAN IP
   - Restart Traefik after port is open: `docker restart traefik`

2. **Update DNS:**
   - Point domain `murphylab.app` to your public IP via your DNS registrar
   - Wait 5-15 minutes for DNS propagation
   - Verify: `nslookup murphylab.app`

3. **Force cert renewal:**
   - Delete acme.json: `rm traefik/acme.json`
   - Restart Traefik: `docker restart traefik`
   - Wait 3-5 minutes for new cert issuance

4. **Switch to DNS challenge (optional):**
   - Edit `traefik/traefik.yml`
   - Comment out `httpChallenge`
   - Uncomment `dnsChallenge` with your provider
   - Set DNS provider API key: `export CLOUDFLARE_API_KEY=...`
   - Restart: `docker restart traefik`

---

## Symptom: "Connection refused" or "Failed to connect"

### Problem: Service not responding to requests

**Causes:**
- Container crashed or not started
- Port mismatch in Traefik labels
- Service not listening on expected port
- Network connectivity issue

**Diagnosis:**
```bash
# Check if container is running
docker ps | grep <service-name>

# Check container status and reason for failure
docker inspect <container-name> | jq '.[0].State'

# View container logs
docker logs <container-name> --tail 50

# Test direct connection to service port
docker exec traefik curl -I http://<service-name>:3000

# Check service is listening on port
docker exec <service-name> netstat -tuln | grep LISTEN
```

**Solutions:**
1. **Restart the service:**
   ```bash
   docker-compose -f docker-compose.optiplex.yml restart <service-name>
   ```

2. **Check container logs for errors:**
   ```bash
   docker-compose -f docker-compose.optiplex.yml logs <service-name> --tail 100
   ```

3. **Verify port in labels matches service:**
   - If service listens on port 3000, label should be: `traefik.http.services.<name>.loadbalancer.server.port=3000`

4. **Check resource limits not exceeded:**
   ```bash
   docker stats <service-name>
   ```
   If using 100% memory or CPU, increase limits in compose file.

5. **Recreate container:**
   ```bash
   docker-compose -f docker-compose.optiplex.yml up -d --force-recreate <service-name>
   ```

---

## Symptom: "403 Forbidden" when accessing VPN-only service

### Problem: Service returns 403 instead of connecting

**Causes:**
- Client IP not in Headscale subnet (100.64.0.0/10)
- VPN not connected or client IP wrong
- Middleware not loaded by Traefik
- IP whitelist syntax error in dynamic config

**Diagnosis:**
```bash
# Check your VPN IP
tailscale status | grep "100.64"

# Verify middleware is loaded in Traefik
curl http://localhost:8080/api/http/middlewares | grep -i vpn

# Check the actual client IP in Traefik logs
docker logs traefik | grep -i "403\|vpn-only" | tail -20

# Verify dynamic config syntax is valid
docker exec traefik cat /dynamic/dynamic_pi3.yml  # Check for YAML errors
```

**Solutions:**
1. **Ensure VPN is connected:**
   ```bash
   tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>
   tailscale status  # Should show "Active" and IP in 100.64.x.x range
   ```

2. **Reload Traefik middleware:**
   ```bash
   # Verify dynamic config files exist and are readable
   ls -la traefik/dynamic/
   
   # Restart Traefik to reload all dynamic configs
   docker restart traefik
   
   # Wait 10 seconds and try again
   sleep 10
   curl -k https://vault.murphylab.app
   ```

3. **Check IP whitelist in dynamic config:**
   ```bash
   grep -A5 "vpn-only:" traefik/dynamic_pi3.yml
   # Should show: sourceRange: ["100.64.0.0/10", "127.0.0.1/32"]
   ```

4. **Test with localhost (bypass whitelist):**
   - SSH to Optiplex: `ssh user@optiplex-ip`
   - Curl with localhost: `curl -k https://vault.murphylab.app` (from Optiplex itself should work)

---

## Symptom: Pi3 Services Return "Connection Refused" or "502 Bad Gateway"

### Problem: Services on Pi3 not accessible via Traefik on Optiplex

**Causes:**
- PI3_IP placeholder not replaced with actual IP
- Pi3 not reachable on LAN (network issue)
- Pi3 service port changed or service not running
- Traefik can't resolve hostname (if using hostname in dynamic config)

**Diagnosis:**
```bash
# Check if PI3_IP was replaced in dynamic config
grep "PI3_IP" traefik/dynamic_pi3.yml  # Should return nothing (or only commented lines)

# Verify the IP is correct
grep "http://" traefik/dynamic_pi3.yml

# Test connectivity to Pi3 from Optiplex
ping 192.168.1.100

# Test service directly
curl -I http://192.168.1.100:3000  # For AdGuard

# Check if Traefik can resolve the backend
docker exec traefik curl -I http://192.168.1.100:3000

# View Traefik error logs for Pi3 routes
docker logs traefik | grep -i "pi3\|192.168"
```

**Solutions:**
1. **Replace PI3_IP with actual IP:**
   ```bash
   # View current config
   grep "http://" traefik/dynamic_pi3.yml
   
   # Replace (macOS example; use sed -i for Linux)
   sed -i '' 's/192.168.1.100/192.168.1.YOUR_ACTUAL_IP/g' traefik/dynamic_pi3.yml
   
   # Restart Traefik to reload
   docker restart traefik
   ```

2. **Ensure Pi3 is reachable:**
   ```bash
   # Ping from Optiplex
   ping 192.168.1.100
   
   # SSH to verify Pi3 is up
   ssh pi@192.168.1.100
   
   # Check Docker is running on Pi3
   docker ps
   ```

3. **Verify Pi3 service is running:**
   ```bash
   # On Pi3:
   docker-compose -f docker-compose.pi3.yml ps
   
   # Check specific service port
   docker ps | grep adguard
   netstat -tuln | grep 3000  # For AdGuard
   ```

4. **Test direct curl from Optiplex:**
   ```bash
   # From Optiplex, directly test Pi3 service
   curl -I http://192.168.1.100:3000
   
   # If this fails, Pi3 service is down
   # If this works, check Traefik routing config
   ```

---

## Symptom: Headscale Clients Can't Register or Connect

### Problem: Tailscale clients show "connecting" or "offline"

**Causes:**
- Headscale not accessible via HTTPS domain
- Pre-auth key expired or invalid
- Client DNS can't resolve headscale.murphylab.app
- Network firewall blocking VPN ports (3478/UDP, etc.)

**Diagnosis:**
```bash
# Check Headscale is running
docker ps | grep headscale

# View Headscale logs for auth errors
docker logs headscale | grep -i "error\|register\|auth" | tail -20

# List registered machines
docker exec headscale headscale machines list

# Check pre-auth key validity
docker exec headscale headscale pre-auth-keys list

# Test HTTPS connectivity
curl -k https://headscale.murphylab.app/api/v1/health

# Check if port 3478/UDP is open (if using Headscale's own DERP)
netstat -uln | grep 3478
```

**Solutions:**
1. **Create fresh pre-auth key:**
   ```bash
   docker exec headscale headscale pre-auth-keys create --user admin --reusable --expiration 24h
   
   # Copy the key and use it in tailscale up
   ```

2. **Verify domain accessibility:**
   ```bash
   # From client device
   nslookup headscale.murphylab.app
   curl -k https://headscale.murphylab.app
   
   # Should return 200 or JSON response, not timeout
   ```

3. **Register client with correct parameters:**
   ```bash
   tailscale up \
     --login-server=https://headscale.murphylab.app \
     --authkey=<key-from-above> \
     --force-reauth
   ```

4. **Restart client connection:**
   ```bash
   # On client device
   tailscale down
   sleep 5
   tailscale up --login-server=https://headscale.murphylab.app --authkey=<key>
   ```

5. **Check firewall allows VPN:**
   - Verify port 3478/UDP is open (if using local DERP)
   - Check if ISP blocks UDP (less common now)
   - Try alternative VPN client (Wireguard directly)

---

## Symptom: High Memory Usage or Container Crashes

### Problem: Services consuming too much RAM or getting OOM-killed

**Causes:**
- Image caching in Immich, Paperless
- Database growth (PostgreSQL, Headscale)
- Pi3 limited to ~512MB available RAM
- Resource limits set too low

**Diagnosis:**
```bash
# Real-time memory usage
docker stats

# Find which container uses most memory
docker ps --format "{{.Names}}" | xargs -I {} sh -c 'echo -n "{}: "; docker inspect {} | jq ".[0].HostConfig.Memory"'

# Check if container was OOM-killed
docker inspect <container> | jq '.[0].State.OOMKilled'

# View container logs for out-of-memory errors
docker logs <container> | grep -i "oom\|memory\|killed"

# Check available system memory
free -h

# On Pi3, check CPU temp (may thermal throttle)
vcgencmd measure_temp
```

**Solutions:**
1. **Increase resource limits in compose:**
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '2'
         memory: 2G    # Increase from 1G to 2G
   ```
   Then: `docker-compose -f docker-compose.optiplex.yml up -d`

2. **Clean up unused images/volumes:**
   ```bash
   docker image prune -a
   docker volume prune
   docker system prune -a --volumes
   ```

3. **For Pi3 specifically:**
   - Disable heavy services: remove Immich, Paperless OCR
   - Increase swap (but use SSD, not microSD): `sudo dphys-swapfile swapoff; sed -i 's/CONF_SWAPSIZE=100/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile; sudo dphys-swapfile swapon`
   - Mount USB at `/mnt/usb` for heavy workloads

4. **For PostgreSQL (Immich, Paperless databases):**
   ```bash
   # Optimize PostgreSQL memory
   docker exec immich-db psql -U immich -d immich -c "VACUUM FULL ANALYZE;"
   ```

---

## Symptom: Slow Service Performance or Timeouts

### Problem: Services are slow, requests timing out, or hanging

**Causes:**
- Network latency (especially Pi3 on WiFi)
- Disk I/O bottleneck (especially Pi3 on SD card)
- CPU throttling
- Upstream service overloaded

**Diagnosis:**
```bash
# Measure network latency
ping -c 10 192.168.1.100  # Pi3 latency

# Check disk I/O on Optiplex
iostat -x 1 5

# Check disk I/O on Pi3
iotop  # May need to install: sudo apt-get install iotop

# Check CPU usage
top -b -n 1 | head -20

# Check if service threads are blocked
docker exec <service> ps aux | grep -v grep

# Measure request time
time curl -k https://vault.murphylab.app
```

**Solutions:**
1. **For Pi3 network issues:**
   - Switch from WiFi to Ethernet (USB adapter) for lower latency
   - Move closer to WiFi router
   - Check WiFi interference: `sudo iwconfig`

2. **For Pi3 disk I/O:**
   - Mount `/mnt/usb` (USB is faster than microSD)
   - Use USB SSD instead of USB HDD
   - Reduce background processes: `systemctl disable <service>`

3. **For database queries:**
   ```bash
   # Immich: optimize media library
   docker exec immich immich admin fix-assets --infra
   
   # Paperless: rebuild search index
   docker exec paperless python manage.py document_index reindex
   ```

4. **Increase timeouts in Traefik:**
   ```yaml
   # traefik/traefik.yml
   entryPoints:
     websecure:
       address: ":443"
       http:
         idleTimeout: 180s  # Default 180s
   ```

---

## Symptom: "Address already in use" when starting stack

### Problem: Port conflicts, services can't bind to ports

**Causes:**
- Port 80, 443 already in use (nginx, Apache, other Traefik)
- Service port defined twice in compose
- Previously crashed container still holding port

**Diagnosis:**
```bash
# Find what's using port 80
sudo lsof -i :80
sudo netstat -tlnp | grep :80

# Check if Docker container still exists
docker ps -a | grep <service>

# Verify compose port definitions
grep -n "ports:" docker-compose.optiplex.yml -A 2
```

**Solutions:**
1. **Stop conflicting process:**
   ```bash
   # Stop other web server
   sudo systemctl stop nginx
   sudo systemctl stop apache2
   
   # Or, change Traefik port in compose:
   # ports: ["8080:80", "8443:443"]  # Use non-standard ports
   ```

2. **Remove lingering containers:**
   ```bash
   docker ps -a | grep exited
   docker rm <container-id>
   ```

3. **Check for duplicate port definitions:**
   ```bash
   grep "8080:" docker-compose.optiplex.yml
   # Should only appear once per service
   ```

---

## Symptom: Traefik Dashboard Shows No Routes or Services

### Problem: Routers/services don't appear in Traefik dashboard

**Causes:**
- Service labels not set correctly
- Dynamic config files not loading
- Service not reachable by Traefik
- Syntax error in labels or dynamic config

**Diagnosis:**
```bash
# Check if labels are being read
docker inspect traefik | jq '.[0].Config.Labels'

# Check if dynamic files are being loaded
docker logs traefik | grep -i "dynamic\|providers"

# Validate dynamic config YAML
docker exec traefik cat /dynamic/dynamic_pi3.yml | yq . > /dev/null

# Check Traefik API for routes
curl http://localhost:8080/api/http/routers
curl http://localhost:8080/api/http/services

# Check specific service
curl http://localhost:8080/api/http/routers | jq '.[] | select(.name=="portainer")'
```

**Solutions:**
1. **Verify service labels in compose:**
   ```yaml
   labels:
     - "traefik.enable=true"  # CRITICAL: must be true
     - "traefik.http.routers.myservice.rule=Host(`myservice.murphylab.app`)"
     - "traefik.http.routers.myservice.entrypoints=websecure"
   - "traefik.http.routers.myservice.tls.certResolver=letsencrypt"
     - "traefik.http.services.myservice.loadbalancer.server.port=3000"
   ```

2. **Reload Traefik configuration:**
   ```bash
   docker restart traefik
   sleep 10
   curl http://localhost:8080/api/http/routers
   ```

3. **Validate dynamic config syntax:**
   ```bash
   # Install yamllint
   pip install yamllint
   yamllint traefik/dynamic_pi3.yml
   ```

4. **Check service is running and healthy:**
   ```bash
   docker ps | grep portainer
   docker inspect portainer | jq '.[0].State'
   ```

---

## General Debugging Tips

### Enable Debug Logging
```yaml
# traefik/traefik.yml
log:
  level: DEBUG  # Shows detailed routing decisions
```

### Monitor All Requests
```bash
# Follow Traefik access logs
docker logs traefik -f | grep "GET\|POST"
```

### Network Diagnostics from Container
```bash
# Open shell in Traefik container
docker exec -it traefik sh

# Inside container:
nslookup vault.murphylab.app
curl http://vaultwarden:80/alive
netstat -tuln
```

### Check Docker Networks
```bash
# List networks and their subnets
docker network inspect web
docker network inspect headscale_net

# Check which containers are on which networks
docker network inspect web | jq '.Containers'
```

### View All Traefik Configuration
```bash
# Dump entire Traefik config
curl http://localhost:8080/api/config | jq . | less
```

---

## Quick Recovery Steps

```bash
#!/bin/bash
# If everything is broken, run this:

echo "Stopping all services..."
docker-compose -f docker-compose.optiplex.yml down

echo "Removing bad volumes (optional)..."
# docker-compose -f docker-compose.optiplex.yml down -v

echo "Pulling latest images..."
docker-compose -f docker-compose.optiplex.yml pull

echo "Restarting services..."
docker-compose -f docker-compose.optiplex.yml up -d

echo "Waiting for services..."
sleep 10

echo "Checking health..."
docker-compose -f docker-compose.optiplex.yml ps

echo "View logs for errors:"
docker-compose -f docker-compose.optiplex.yml logs traefik | tail -50
```

---

For additional help:
- Traefik Docs: https://doc.traefik.io/traefik/
- Docker Logs: `docker logs <container> --help`
- Headscale Docs: https://github.com/juanfont/headscale/blob/main/docs/
