#!/usr/bin/env bash
# Gyors állapot: memória, konténerek, utolsó mentés. Csak olvas.
cd "$(dirname "$0")/.."
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"
echo "=== Memória ==="; free -m | awk 'NR<=2'
echo; echo "=== Kertészet konténerek ==="
$DOCKER compose --profile crm ps --format 'table {{.Service}}\t{{.Status}}'
$DOCKER stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' $($DOCKER compose --profile crm ps -q) 2>/dev/null
echo; echo "=== Utolsó mentés ==="; ls -t backups/*.sql.gz 2>/dev/null | head -1 || echo "még nincs"
