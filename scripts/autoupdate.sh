#!/usr/bin/env bash
# Automatikus frissítés + állapotjelentés. A cron futtatja 10 percenként.
#  - Ha a GitHubon (main ág) új verzió van: letölti, telepíti (setup.sh), ellenőrzi.
#    Ha az új verzió után valamelyik szolgáltatás nem fut, visszaáll az előző verzióra.
#  - Óránként és minden frissítés után állapotjelentést tölt fel a 'status' ágra,
#    hogy Claude SSH nélkül is lássa, mi történik a szerveren.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$REPO/backups/autoupdate.log"
mkdir -p "$REPO/backups"
exec 9>/tmp/kertesz-autoupdate.lock
flock -n 9 || exit 0

naplo() { echo "$(date '+%F %T') $*" >> "$LOG"; }
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo -n docker"

egeszseges() {
  # Minden elindított szolgáltatás 'running' állapotú?
  local rossz
  rossz=$(cd "$REPO" && $DOCKER compose --profile crm ps -a --format '{{.Service}} {{.State}}' | grep -v ' running$' || true)
  [ -z "$rossz" ]
}

FRISSITES=""
cd "$REPO"
git fetch -q origin main 2>>"$LOG" || naplo "git fetch hiba"
REGI=$(git rev-parse HEAD)
UJ=$(git rev-parse origin/main 2>/dev/null || echo "$REGI")

if [ "$REGI" != "$UJ" ]; then
  naplo "Új verzió: ${REGI:0:7} -> ${UJ:0:7}"
  git reset -q --hard "$UJ"
  if bash setup.sh >> "$LOG" 2>&1 && sleep 30 && egeszseges; then
    FRISSITES="OK: ${UJ:0:7} telepítve"
  else
    FRISSITES="HIBA: ${UJ:0:7} nem indult el rendesen, visszaállás erre: ${REGI:0:7}"
    naplo "$FRISSITES"
    git reset -q --hard "$REGI"
    bash setup.sh >> "$LOG" 2>&1
  fi
  naplo "$FRISSITES"
fi

# Állapotjelentés: frissítés után, és óránként egyszer (az óra első futásakor)
PERC=$(date +%M)
if [ -n "$FRISSITES" ] || [ "$PERC" -lt 10 ]; then
  bash "$REPO/scripts/report.sh" "$FRISSITES" >> "$LOG" 2>&1 || naplo "állapotjelentés hiba"
fi

# Napló méretének korlátozása
tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
