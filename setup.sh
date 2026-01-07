#!/bin/bash
# Homelab Docker Setup & Verification Script
# This script helps you set up and verify your multi-host Docker stack

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose not found. Please install Docker Compose."
        exit 1
    fi
    
    log_success "Docker and Docker Compose found"
}

# Check environment variables
check_env() {
    log_info "Checking environment variables..."
    
    local missing_vars=()
    
    for var in LETSENCRYPT_EMAIL DNS_PROVIDER_API_KEY VAULTWARDEN_ADMIN_TOKEN \
               IMMICH_DB_PASSWORD IMMICH_ADMIN_PASSWORD ACTUALBUDGET_ADMIN_PASSWORD \
               N8N_BASIC_AUTH_PASSWORD BESZEL_ADMIN_PASSWORD HEADSCALE_ADMIN_PASSWORD; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_warn "Missing environment variables: ${missing_vars[*]}"
        echo "Please set them in .env file or export them:"
        for var in "${missing_vars[@]}"; do
            echo "  export $var=<value>"
        done
        return 1
    fi
    
    log_success "All required environment variables set"
    return 0
}

# Bring up Optiplex stack
bring_up_optiplex() {
    log_info "Bringing up Optiplex stack..."
    docker-compose -f docker-compose.optiplex.yml up -d
    log_success "Optiplex stack is up"
}

# Bring up Pi3 stack
bring_up_pi3() {
    local pi3_ip="${1:-}"
    
    if [ -z "$pi3_ip" ]; then
        log_error "Pi3 IP address required. Usage: setup_pi3 <PI3_IP>"
        return 1
    fi
    
    log_info "Preparing Pi3 stack for IP $pi3_ip..."
    
    # Create .env.pi3 with PI3_IP
    cat > .env.pi3 << EOF
PI3_IP=$pi3_ip
OPTIPLEX_IP=$(hostname -I | awk '{print $1}')
PORTAINER_AGENT_SECRET=${PORTAINER_AGENT_SECRET:-change-me-secure-secret}
ADGUARD_ADMIN_PASSWORD=${ADGUARD_ADMIN_PASSWORD:-}
GATUS_ADMIN_PASSWORD=${GATUS_ADMIN_PASSWORD:-}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
DNS_PROVIDER_API_KEY=${DNS_PROVIDER_API_KEY}
IMMICH_DB_PASSWORD=${IMMICH_DB_PASSWORD}
IMMICH_ADMIN_PASSWORD=${IMMICH_ADMIN_PASSWORD}
N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
EOF
    
    log_info "Created .env.pi3"
    
    # Update dynamic_pi3.yml with actual Pi3 IP
    sed -i "" "s/PI3_IP/$pi3_ip/g" traefik/dynamic_pi3.yml
    log_success "Updated traefik/dynamic_pi3.yml with Pi3 IP: $pi3_ip"
}

# Verify Traefik is running and accessible
verify_traefik() {
    log_info "Verifying Traefik..."
    
    if docker ps | grep -q traefik; then
        log_success "Traefik container is running"
    else
        log_error "Traefik container is not running"
        return 1
    fi
    
    # Check Traefik API
    if curl -s http://localhost:8080/ping > /dev/null; then
        log_success "Traefik API is responding"
    else
        log_warn "Traefik API not yet responsive (may be starting)"
    fi
}

# Verify TLS certificates
verify_certs() {
    log_info "Verifying TLS certificates..."
    
    if [ -f "traefik/acme.json" ]; then
        local cert_count=$(grep -o '"domain"' traefik/acme.json | wc -l)
        if [ "$cert_count" -gt 0 ]; then
            log_success "Found $cert_count TLS certificate(s)"
        else
            log_warn "No TLS certificates found yet (may be generating)"
        fi
    else
        log_warn "traefik/acme.json not found (certs will be created on first request)"
    fi
}

# Verify VPN connectivity
verify_vpn() {
    log_info "Verifying Headscale VPN..."
    
    if docker ps | grep -q headscale; then
        log_success "Headscale container is running"
        
        # Try to list machines
        if docker exec headscale headscale machines list > /dev/null 2>&1; then
            log_success "Headscale is responding"
        else
            log_warn "Headscale may still be initializing"
        fi
    else
        log_error "Headscale container is not running"
        return 1
    fi
}

# Test public vs VPN-only access
test_vpn_enforcement() {
    log_info "Testing VPN-only enforcement..."
    
    # Wait for certs to be generated (may take time)
    log_warn "Waiting for TLS certificates (this may take 1-2 minutes)..."
    sleep 30
    
    local hostname="vault.murphylab.app"
    log_info "Testing access to $hostname from public IP..."
    
    # This should fail (403) because request is not from VPN subnet
    if curl -s -k -o /dev/null -w "%{http_code}" "https://$hostname" | grep -q "403"; then
        log_success "VPN-only enforcement working: public access denied (403)"
    else
        log_warn "VPN-only enforcement may not be active yet"
    fi
}

# Show service status
show_status() {
    log_info "Service status:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Networks}}"
}

# Show network status
show_networks() {
    log_info "Docker networks:"
    docker network ls | grep -E "web|headscale|pi3"
}

# Show Traefik routes
show_routes() {
    log_info "Traefik routers and services:"
    
    if curl -s http://localhost:8080/api/http/routers > /dev/null; then
        echo "Check Traefik dashboard at: https://traefik.murphylab.app (VPN-only)"
    else
        log_warn "Traefik API not yet ready"
    fi
}

# Create Headscale pre-auth key for devices
create_preauth_key() {
    log_info "Creating Headscale pre-auth key for new devices..."
    
    if docker exec headscale headscale pre-auth-keys create --reusable --expiration 24h > /dev/null 2>&1; then
        local key=$(docker exec headscale headscale pre-auth-keys list | tail -1 | awk '{print $1}')
        log_success "Pre-auth key created: $key"
        echo "Use this key to register new Tailscale clients"
    else
        log_error "Failed to create pre-auth key"
        return 1
    fi
}

# Cleanup and rollback
cleanup() {
    log_warn "Rolling back stack..."
    docker-compose -f docker-compose.optiplex.yml down -v
    log_info "Optiplex stack removed"
}

# Main menu
show_menu() {
    echo ""
    echo -e "${BLUE}=== Homelab Docker Setup Menu ===${NC}"
    echo "1. Check prerequisites"
    echo "2. Verify environment variables"
    echo "3. Bring up Optiplex stack"
    echo "4. Setup Pi3 stack (requires Pi3 IP)"
    echo "5. Verify Traefik"
    echo "6. Verify TLS certificates"
    echo "7. Verify Headscale VPN"
    echo "8. Test VPN-only enforcement"
    echo "9. Show service status"
    echo "10. Show networks"
    echo "11. Create Headscale pre-auth key"
    echo "12. Full verification (all checks)"
    echo "13. Cleanup and rollback"
    echo "0. Exit"
    echo ""
}

# Run all verification checks
full_verification() {
    log_info "Running full verification suite..."
    check_prerequisites
    check_env || true
    verify_traefik || true
    verify_certs || true
    verify_vpn || true
    show_status
    show_networks
    log_success "Verification complete"
}

# Main loop
main() {
    if [ "$#" -eq 0 ]; then
        # Interactive mode
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1) check_prerequisites ;;
                2) check_env || true ;;
                3) bring_up_optiplex ;;
                4) read -p "Enter Pi3 IP: " pi3_ip; bring_up_pi3 "$pi3_ip" ;;
                5) verify_traefik ;;
                6) verify_certs ;;
                7) verify_vpn ;;
                8) test_vpn_enforcement ;;
                9) show_status ;;
                10) show_networks ;;
                11) create_preauth_key ;;
                12) full_verification ;;
                13) cleanup ;;
                0) log_info "Exiting"; exit 0 ;;
                *) log_error "Invalid option" ;;
            esac
            
            read -p "Press Enter to continue..."
        done
    else
        # Command-line mode
        case "$1" in
            check) check_prerequisites ;;
            env) check_env ;;
            up) bring_up_optiplex ;;
            verify) full_verification ;;
            status) show_status ;;
            cleanup) cleanup ;;
            *) log_error "Unknown command: $1"; exit 1 ;;
        esac
    fi
}

main "$@"
