#!/bin/bash

set -euo pipefail

REPO_URL="${REPO_URL:?REPO_URL env var required}"
REPO_REF="${REPO_REF:-main}"

APP_DIR="/opt/app/backend"

echo "Starting backend deployment..."

# Make sure application directory exists
sudo mkdir -p "$APP_DIR"

# Make ec2-user the owner so rsync can write files
sudo chown -R ec2-user:ec2-user "$APP_DIR"

# Create temporary clone directory
TMP_CLONE=$(mktemp -d)

# Always clean up temporary directory
trap 'rm -rf "$TMP_CLONE"' EXIT

echo "Cloning repository..."

git clone \
  --depth 1 \
  --branch "$REPO_REF" \
  "$REPO_URL" \
  "$TMP_CLONE"

echo "Copying backend files..."

rsync -a \
  --delete \
  --exclude '.env' \
  --exclude 'venv' \
  "$TMP_CLONE/app/backend/" \
  "$APP_DIR/"

# Make deployment script executable
chmod +x "$APP_DIR/deploy.sh"

echo "Installing Python dependencies..."

python3 -m venv "$APP_DIR/venv" --clear

"$APP_DIR/venv/bin/pip" install --upgrade pip

"$APP_DIR/venv/bin/pip" install \
  -r "$APP_DIR/requirements.txt"

echo "Installing systemd service..."

sudo cp \
  "$APP_DIR/backend.service" \
  /etc/systemd/system/backend.service

sudo systemctl daemon-reload

sudo systemctl enable backend

sudo systemctl restart backend

echo "Backend deployed and restarted successfully."