#!/bin/bash
# Run on the backend EC2 instance (via SSM Run Command) to deploy the latest
# backend code. Assumes bootstrap.sh has already run once (git, python3, venv,
# systemd unit, and /opt/app/backend/.env already in place).
set -euo pipefail

REPO_URL="${REPO_URL:?REPO_URL env var required}"
REPO_REF="${REPO_REF:-main}"
APP_DIR=/opt/app/backend

sudo mkdir -p "$APP_DIR"
sudo chown ec2-user:ec2-user "$APP_DIR"

TMP_CLONE=$(mktemp -d)
trap 'rm -rf "$TMP_CLONE"' EXIT   # cleans up even if the script fails partway

git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_CLONE"
rsync -a --delete --exclude '.env' --exclude 'venv' "$TMP_CLONE/app/backend/" "$APP_DIR/"

python3 -m venv "$APP_DIR/venv" --clear
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

sudo cp "$APP_DIR/backend.service" /etc/systemd/system/backend.service
sudo systemctl daemon-reload
sudo systemctl enable backend
sudo systemctl restart backend

echo "Backend deployed and restarted."