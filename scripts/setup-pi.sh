#!/usr/bin/env bash
# =====================================================================
# Phantom Note — Raspberry Pi First-Time Setup
# =====================================================================
# Run this script ON the Raspberry Pi (via SSH or directly).
# It installs Node.js, pm2, nginx, and configures everything needed
# to serve Phantom Note on ports 80/443.
#
# Usage:
#   chmod +x scripts/setup-pi.sh
#   ./scripts/setup-pi.sh
# =====================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }

APP_DIR="$HOME/phantom-note"
NODE_VERSION="20"  # LTS version

echo ""
echo "============================================="
echo "  Phantom Note — Raspberry Pi Setup"
echo "============================================="
echo ""

# -----------------------------------------------------------------
# 1. System updates
# -----------------------------------------------------------------
info "Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# -----------------------------------------------------------------
# 2. Install Node.js via nvm
# -----------------------------------------------------------------
if command -v node &> /dev/null; then
    info "Node.js already installed: $(node --version)"
else
    info "Installing nvm and Node.js ${NODE_VERSION}..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    # Load nvm into this shell session
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    nvm install "$NODE_VERSION"
    nvm use "$NODE_VERSION"
    nvm alias default "$NODE_VERSION"
    info "Node.js installed: $(node --version)"
fi

# Make sure nvm is loaded (in case it was already installed)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# -----------------------------------------------------------------
# 3. Install pm2 globally
# -----------------------------------------------------------------
if command -v pm2 &> /dev/null; then
    info "pm2 already installed: $(pm2 --version)"
else
    info "Installing pm2..."
    npm install -g pm2
    info "pm2 installed: $(pm2 --version)"
fi

# -----------------------------------------------------------------
# 4. Create app directory
# -----------------------------------------------------------------
info "Setting up app directory at ${APP_DIR}..."
mkdir -p "$APP_DIR"

# -----------------------------------------------------------------
# 5. Configure pm2 to start on boot
# -----------------------------------------------------------------
info "Configuring pm2 startup..."
# pm2 startup generates a command that needs to be run with sudo.
# We capture and execute it automatically.
PM2_STARTUP_CMD=$(pm2 startup systemd -u "$USER" --hp "$HOME" | grep "sudo" | head -1)
if [ -n "$PM2_STARTUP_CMD" ]; then
    eval "$PM2_STARTUP_CMD"
    info "pm2 configured to start on boot."
else
    warn "pm2 startup may already be configured."
fi

# -----------------------------------------------------------------
# 6. Install and configure nginx
# -----------------------------------------------------------------
info "Installing nginx..."
sudo apt-get install -y nginx

info "Writing nginx configuration..."
sudo tee /etc/nginx/sites-available/phantom-note > /dev/null <<'NGINX_CONF'
# =====================================================================
# Phantom Note — nginx reverse proxy configuration
# =====================================================================
# Proxies incoming HTTP requests to the Node.js server on port 3000.

server {
    listen 80;
    listen [::]:80;

    # Replace with your domain name when you have one.
    # The underscore (_) is a catch-all that matches any hostname.
    server_name _;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript;
    gzip_min_length 256;

    # Proxy all requests to the Node.js server
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Serve ads.txt directly (Google needs fast access to this)
    location = /ads.txt {
        proxy_pass http://127.0.0.1:3000/ads.txt;
    }
}

# =====================================================================
# HTTPS / SSL Configuration (uncomment after setting up Let's Encrypt)
# =====================================================================
# To enable HTTPS:
#   1. Install certbot:
#        sudo apt-get install certbot python3-certbot-nginx
#   2. Get a certificate (replace yourdomain.com):
#        sudo certbot --nginx -d yourdomain.com
#   3. Certbot will automatically modify this config to add SSL.
#   4. Auto-renewal is set up by certbot. Test with:
#        sudo certbot renew --dry-run
#
# If you want to configure SSL manually instead:
#
# server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#     server_name yourdomain.com;
#
#     ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers HIGH:!aNULL:!MD5;
#
#     location / {
#         proxy_pass http://127.0.0.1:3000;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade $http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host $host;
#         proxy_set_header X-Real-IP $remote_addr;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_set_header X-Forwarded-Proto $scheme;
#         proxy_cache_bypass $http_upgrade;
#     }
# }
#
# # Redirect HTTP to HTTPS
# server {
#     listen 80;
#     listen [::]:80;
#     server_name yourdomain.com;
#     return 301 https://$host$request_uri;
# }
NGINX_CONF

# Enable the site (remove default if it exists)
sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/phantom-note /etc/nginx/sites-enabled/phantom-note

# Test and reload nginx
sudo nginx -t && sudo systemctl reload nginx
info "nginx configured and running."

# -----------------------------------------------------------------
# 7. Configure firewall
# -----------------------------------------------------------------
info "Configuring firewall (ufw)..."
sudo apt-get install -y ufw
sudo ufw allow 22/tcp    # SSH — don't lock yourself out!
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS (for later)
sudo ufw --force enable
info "Firewall enabled (ports 22, 80, 443 open)."

# -----------------------------------------------------------------
# Done!
# -----------------------------------------------------------------
echo ""
echo "============================================="
echo "  Setup Complete!"
echo "============================================="
echo ""
info "What was installed/configured:"
echo "  - Node.js $(node --version)"
echo "  - pm2 $(pm2 --version)"
echo "  - nginx (reverse proxy on port 80 → localhost:3000)"
echo "  - ufw firewall (ports 22, 80, 443)"
echo ""
info "Next steps:"
echo "  1. From your Mac, run:  npm run deploy"
echo "     (or: bash scripts/deploy.sh)"
echo "  2. The deploy script will sync files, install deps, and start pm2."
echo "  3. Access the site at:  http://$(hostname -I | awk '{print $1}')"
echo ""
info "Later, for HTTPS:"
echo "  1. Point a domain name to this Pi's public IP"
echo "  2. Run:  sudo apt-get install certbot python3-certbot-nginx"
echo "  3. Run:  sudo certbot --nginx -d yourdomain.com"
echo ""
