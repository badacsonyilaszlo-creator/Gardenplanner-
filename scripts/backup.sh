#!/usr/bin/env bash
# Napi adatbázis-mentés. A cron futtatja éjjel 03:30-kor; kézzel is indítható: bash scripts/backup.sh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"
FAJL="backups/kertesz-$(date +%Y-%m-%d_%H%M).sql.gz"
$DOCKER compose exec -T postgres pg_dumpall -U kertesz | gzip > "$FAJL"
# 30 napnál régebbi mentések törlése
find backups -name 'kertesz-*.sql.gz' -mtime +30 -delete
echo "$(date '+%F %T') mentés kész: $FAJL ($(du -h "$FAJL" | cut -f1))"
