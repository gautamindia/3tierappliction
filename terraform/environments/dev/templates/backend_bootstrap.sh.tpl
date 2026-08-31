#!/bin/bash
# First-boot bootstrap for the backend instance. Installs base packages and
# does an initial checkout/deploy. Subsequent deploys are done by the
# app-deploy CI/CD pipeline via SSM Run Command (see app/backend/deploy.sh),
# NOT by re-running this script.
set -euo pipefail

dnf install -y git python3 python3-pip rsync

mkdir -p /opt/app/backend
chown ec2-user:ec2-user /opt/app/backend



sudo -u ec2-user git clone "${repo_url}" /tmp/repo-backend
cp -r /tmp/repo-backend/app/backend/. /opt/app/backend/
rm -rf /tmp/repo-backend

sudo -u ec2-user python3 -m venv /opt/app/backend/venv
sudo -u ec2-user /opt/app/backend/venv/bin/pip install --upgrade pip
sudo -u ec2-user /opt/app/backend/venv/bin/pip install -r /opt/app/backend/requirements.txt

cp /opt/app/backend/backend.service /etc/systemd/system/backend.service
systemctl daemon-reload
systemctl enable backend
systemctl start backend
