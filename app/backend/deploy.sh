#!/bin/bash
# Configure (or re-deploy) the backend on this EC2 instance.
# Safe to run multiple times -- every step either creates something fresh
# or overwrites the previous version cleanly, so there's nothing left over
# to break the next run.
#
# Required environment variables before running:
#   REPO_URL, DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD
# Optional:
#   REPO_REF (default: main)
#
# Example:
#   REPO_URL="https://github.com/you/yourrepo.git" \
#   DB_HOST="mydb.xxxx.rds.amazonaws.com" DB_PORT=5432 \
#   DB_NAME="appdb" DB_USER="appuser" DB_PASSWORD="secret" \
#   sudo -E bash configure-backend.sh

set -euo pipefail

: "${REPO_URL:?REPO_URL is required}"
: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:?DB_PORT is required}"
: "${DB_NAME:?DB_NAME is required}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
REPO_REF="${REPO_REF:-main}"

APP_DIR=/opt/app/backend

echo "== Installing packages =="
dnf install -y git python3 python3-pip rsync

echo "== Setting up app directory =="
mkdir -p "$APP_DIR"
chown ec2-user:ec2-user "$APP_DIR"

echo "== Writing .env (kept separatess froddm the code, never overwritten by deploys) =="
cat > "$APP_DIR/.env" << ENVEOF
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
ENVEOF
chmod 600 "$APP_DIR/.env"
chown ec2-user:ec2-user "$APP_DIR/.env"

echo "== Fetching latest code (fresh temp clone, always cleaned up) =="
TMP_CLONE=$(mktemp -d)
trap 'rm -rf "$TMP_CLONE"' EXIT
git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TMP_CLONE"
rsync -a --delete --exclude '.env' --exclude 'venv' "$TMP_CLONE/app/backend/" "$APP_DIR/"

echo "== Installing Python dependencies =="
python3 -m venv "$APP_DIR/venv" --clear
"$APP_DIR/venv/bin/pip" install --upgrade pip -q
"$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt" -q

echo "== Setting up the systemd service =="
cp "$APP_DIR/backend.service" /etc/systemd/system/backend.service
systemctl daemon-reload
systemctl enable backend
systemctl restart backend

echo "== Done =="
sleep 2
systemctl status backend --no-pager -l | head -10