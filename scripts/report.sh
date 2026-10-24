#!/usr/bin/env bash
# Állapotjelentés feltöltése a GitHub 'status' ágára (STATUS.md).
# Jelszót, kulcsot, ügyféladatot NEM tartalmaz: csak memória, szolgáltatások, mentések, hibasorok.
set -uo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SD="$HOME/.kertesz-status"
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo -n docker"
FRISSITES="${1:-}"

if [ ! -d "$SD/.git" ]; then
  mkdir -p "$SD" && cd "$SD"
  git init -q
  git remote add origin "$(git -C "$REPO" remote get-url origin)"
  git config core.sshCommand "$(git -C "$REPO" config core.sshCommand || echo ssh)"
  git config user.name "VPS"
  git config user.email "vps@localhost"
fi
cd "$SD"

{
  echo "# Szerverállapot"
  echo
  echo "Frissítve: $(date '+%F %T %Z') · Verzió: \`$(git -C "$REPO" rev-parse --short HEAD)\`"
  [ -n "$FRISSITES" ] && { echo; echo "**Utolsó frissítés:** $FRISSITES"; }
  echo
  echo "## Memória (MB)"; echo '```'; free -m | awk 'NR<=3'; echo '```'
  echo "## Lemez"; echo '```'; df -h / | tail -1; echo '```'
  echo "## Terhelés"; echo '```'; uptime; echo '```'
  echo "## Kertészet szolgáltatások"; echo '```'
  (cd "$REPO" && $DOCKER compose --profile crm ps -a --format 'table {{.Service}}\t{{.State}}\t{{.Status}}')
  echo; $DOCKER stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}' $(cd "$REPO" && $DOCKER compose --profile crm ps -q) 2>/dev/null
  echo '```'
  echo "## Legnagyobb memóriafogyasztók a szerveren"; echo '```'
  ps -eo pmem,rss,comm --sort=-rss | head -8 | awk 'NR==1{print "%MEM  MB  PROGRAM"; next}{printf "%s  %d  %s\n",$1,$2/1024,$3}'
  echo '```'
  echo "## Mentések"; echo '```'
  ls -lt "$REPO"/backups/*.sql.gz 2>/dev/null | head -3 | awk '{print $6, $7, $8, $5, $9}' || echo "még nincs mentés"
  echo '```'
  echo "## Hibák az elmúlt órában (n8n, listmonk, nocodb, postgres)"; echo '```'
  (cd "$REPO" && $DOCKER compose --profile crm logs --since 1h --no-color 2>/dev/null \
    | grep -iE 'error|fatal|exception|panic' | grep -viE 'password|secret|token|key=' | tail -20) || true
  echo '```'
  echo "## Frissítési napló (utolsó 15 sor)"; echo '```'
  tail -n 15 "$REPO/backups/autoupdate.log" 2>/dev/null | grep -viE 'password|secret|token' || true
  echo '```'
} > STATUS.md

git checkout -q --orphan uj 2>/dev/null || git checkout -q -B uj
git add STATUS.md
git commit -q -m "Állapot $(date '+%F %T')"
git branch -q -M status
git push -q -f origin status 2>&1 || echo "Állapot feltöltése sikertelen (a deploy keynek kell írási jog)."
