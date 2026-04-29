#!/usr/bin/env bash
# =====================================================================
# Phantom Note — Deploy to Raspberry Pi
# =====================================================================
# Run this script FROM your Mac to deploy the latest code to the Pi.
# It uses rsync to sync files and pm2 to restart the server.
#
# Usage:
#   bash scripts/deploy.sh                    # uses PI_HOST from .env
#   bash scripts/deploy.sh 192.168.1.100      # override host
#   bash scripts/deploy.sh raspberrypi.local   # use hostname
# =====================================================================

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# -----------------------------------------------------------------
# Load config from .env if it exists
# -----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -f "$PROJECT_DIR/.env" ]; then
    # Source .env, ignoring comments and empty lines
    set -a
    source <(grep -v '^\s*#' "$PROJECT_DIR/.env" | grep -v '^\s*$')
    set +a
fi

# -----------------------------------------------------------------
# Resolve Pi connection details
# -----------------------------------------------------------------
# Command-line argument takes priority over .env
PI_HOST="${1:-${PI_HOST:-}}"
PI_USER="${PI_USER:-pi}"
PI_APP_DIR="${PI_APP_DIR:-~/phantom-note}"

if [ -z "$PI_HOST" ]; then
    fail "No Pi host specified. Either:\n  - Pass it as an argument: bash scripts/deploy.sh 192.168.1.100\n  - Set PI_HOST in .env"
fi

PI_REMOTE="${PI_USER}@${PI_HOST}"

info "Deploying Phantom Note to ${PI_REMOTE}:${PI_APP_DIR}"
echo ""

# -----------------------------------------------------------------
# 1. Check connectivity
# -----------------------------------------------------------------
info "Checking connection to ${PI_HOST}..."
if ! ssh -o ConnectTimeout=5 "$PI_REMOTE" "echo 'connected'" &> /dev/null; then
    fail "Cannot connect to ${PI_REMOTE}. Check that:\n  - The Pi is on and connected to the network\n  - SSH is enabled on the Pi\n  - The hostname/IP is correct"
fi
info "Connection OK."

# -----------------------------------------------------------------
# 2. Sync files with rsync
# -----------------------------------------------------------------
info "Syncing project files..."
rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.git' \
    --exclude '.env' \
    --exclude '.DS_Store' \
    --exclude 'logs' \
    --exclude '*.wav' \
    --exclude '*.mp3' \
    --exclude '.claude' \
    "$PROJECT_DIR/" \
    "${PI_REMOTE}:${PI_APP_DIR}/"

info "Files synced."

# -----------------------------------------------------------------
# 3. Install dependencies and restart server
# -----------------------------------------------------------------
info "Installing dependencies and restarting server..."
ssh "$PI_REMOTE" bash <<REMOTE_SCRIPT
    # Load nvm so we have access to node/npm
    export NVM_DIR="\$HOME/.nvm"
    [ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"

    cd ${PI_APP_DIR}

    # Create .env from example if it doesn't exist yet
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "Created .env from .env.example — edit it if needed."
    fi

    # Install production dependencies only
    npm install --production

    # Start or restart the pm2 process
    if pm2 describe phantom-note > /dev/null 2>&1; then
        pm2 restart phantom-note
        echo "pm2 process restarted."
    else
        pm2 start server/server.js --name phantom-note
        pm2 save
        echo "pm2 process started and saved."
    fi
REMOTE_SCRIPT

# -----------------------------------------------------------------
# Done!
# -----------------------------------------------------------------
echo ""
info "Deploy complete!"
echo ""
echo "  Site is live at:  http://${PI_HOST}"
echo "  Health check:     http://${PI_HOST}/health"
echo ""
echo "  To check server logs on the Pi:"
echo "    ssh ${PI_REMOTE} 'pm2 logs phantom-note'"
echo ""
