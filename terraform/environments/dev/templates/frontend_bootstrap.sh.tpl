#!/bin/bash
# First-boot bootstrap for the frontend instance. Installs base packages and
# does an initial checkout/deploy. Subsequent deploys are done by the
# app-deploy CI/CD pipeline via SSM Run Command (see app/frontend/deploy.sh),
# NOT by re-running this script.
set -euo pipefail

dnf install -y git python3 python3-pip rsync

mkdir -p /opt/app/frontend
chown ec2-user:ec2-user /opt/app/frontend

cat > /opt/app/frontend/.env << ENVEOF
BACKEND_URL=http://${backend_private_ip}:5000
FLASK_SECRET_KEY=${flask_secret_key}
ENVEOF
chown ec2-user:ec2-user /opt/app/frontend/.env
chmod 600 /opt/app/frontend/.env

sudo -u ec2-user git clone "${repo_url}" /tmp/repo-frontend
cp -r /tmp/repo-frontend/app/frontend/. /opt/app/frontend/
rm -rf /tmp/repo-frontend

sudo -u ec2-user python3 -m venv /opt/app/frontend/venv
sudo -u ec2-user /opt/app/frontend/venv/bin/pip install --upgrade pip
sudo -u ec2-user /opt/app/frontend/venv/bin/pip install -r /opt/app/frontend/requirements.txt

cp /opt/app/frontend/frontend.service /etc/systemd/system/frontend.service
systemctl daemon-reload
systemctl enable frontend
systemctl start frontend
