#!/bin/sh
# One-time setup on a fresh Debian 12 VM: install Docker, clone, start.
# usage (on the VM): sh vm-setup.sh <git-ssh-url>
set -e

REPO=${1:?git ssh url required}
APP_DIR=/opt/legacy-order-matching-engine

if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sudo sh
fi

if [ ! -d "$APP_DIR/.git" ]; then
    sudo mkdir -p "$APP_DIR"
    sudo chown "$(id -u):$(id -g)" "$APP_DIR"
    git clone "$REPO" "$APP_DIR"
fi

cd "$APP_DIR"
git pull --ff-only
sudo docker compose up -d --build

# nightly batch at 22:00 server time, like the original MATCHJOB schedule
CRON="0 22 * * * cd $APP_DIR && docker compose exec -T -u www-data matcheng flock -n /tmp/matchjob.lock /opt/matcheng/run/NEWDAY.sh >/dev/null 2>&1"
( sudo crontab -l 2>/dev/null | grep -v NEWDAY.sh; echo "$CRON" ) | sudo crontab -

sudo docker compose ps
