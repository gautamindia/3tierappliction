#!/bin/bash
# Run on the backend EC2 instance (via SSM Run Command) to deploy the latest
# backend code. Assumes bootstrap.sh has already run once (git, python3, venv,
# systemd unit, and /opt/app/backend/.env already in place).
set -euo pipefail

REPO_URL="${REPO_URL:?REPO_URL env var required}"
REPO_REF="${REPO_REF:-main}"
APP_DIR=/opt/app/backend

if [ ! -d "$APP_DIR/.git" ]; then
  sudo mkdir -p "$APP_DIR"
  sudo chown ec2-user:ec2-user "$APP_DIR"
  git clone "$REPO_URL" /tmp/repo-backend
  cp -r /tmp/repo-backend/app/backend/. "$APP_DIR"
  rm -rf /tmp/repo-backend
  cd "$APP_DIR"
  git init -q
fi

cd "$APP_DIR"
TMP_CLONE=$(mktemp -d)
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_CLONE"
rsync -a --delete --exclude '.env' --exclude 'venv' "$TMP_CLONE/app/backend/" "$APP_DIR/"
rm -rf "$TMP_CLONE"

python3 -m venv "$APP_DIR/venv" --clear
"$APP_DIR/venv/bin/pip" install --upgrade pip
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt"

sudo cp "$APP_DIR/backend.service" /etc/systemd/system/backend.service
sudo systemctl daemon-reload
sudo systemctl enable backend
sudo systemctl restart backend

echo "Backend deployed and restarted."
