#!/bin/bash
# Run on the frontend EC2 instance (via SSM Run Command) to deploy the latest
# frontend code. Assumes bootstrap.sh has already run once.
set -euo pipefail

REPO_URL="${REPO_URL:?REPO_URL env var required}"
REPO_REF="${REPO_REF:-main}"
APP_DIR=/opt/app/frontend

sudo mkdir -p "$APP_DIR"
sudo chown ec2-user:ec2-user "$APP_DIR"

TMP_CLONE=$(mktemp -d)
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_CLONE"
rsync -a --delete --exclude '.env' --exclude 'venv' "$TMP_CLONE/app/frontend/" "$APP_DIR/"
rm -rf "$TMP_CLONE"

python3 -m venv "$APP_DIR/venv" --clear
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

sudo cp "$APP_DIR/frontend.service" /etc/systemd/system/frontend.service
sudo systemctl daemon-reload
sudo systemctl enable frontend
sudo systemctl restart frontend

echo "Frontend deployed and restarted."
