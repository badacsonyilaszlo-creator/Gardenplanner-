#!/usr/bin/env bash
# Kertészet – rendszer telepítése / frissítése a VPS-en.
# Használat (a repó mappájából):  bash setup.sh
# Biztonságosan többször is lefuttatható: a meglévő jelszavakat és adatokat nem írja felül.
set -euo pipefail
cd "$(dirname "$0")"

zold() { printf '\033[32m%s\033[0m\n' "$*"; }
sarga() { printf '\033[33m%s\033[0m\n' "$*"; }
piros() { printf '\033[31m%s\033[0m\n' "$*"; }

# --- 1. Docker ellenőrzése ---
if ! command -v docker >/dev/null 2>&1; then
  piros "A Docker nincs telepítve. Állj meg, és szólj Claude-nak."; exit 1
fi
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  DOCKER="sudo docker"
  sarga "A Dockerhez sudo kell (ha jelszót kér, a szerver jelszavát add meg)."
  sarga "Hozzáadlak a docker csoporthoz, hogy az éjszakai mentés jelszó nélkül fusson."
  sudo usermod -aG docker "$USER"
  sarga "Ez a következő belépéstől él. Most folytatom sudo-val."
fi
mkdir -p backups
if ! $DOCKER compose version >/dev/null 2>&1; then
  piros "Hiányzik a 'docker compose' bővítmény. Szólj Claude-nak."; exit 1
fi

# --- 2. .env létrehozása véletlen jelszavakkal (csak első alkalommal) ---
if [ ! -f .env ]; then
  cp .env.example .env
  while grep -q '__GENERALT__' .env; do
    sed -i "0,/__GENERALT__/s//$(openssl rand -hex 24)/" .env
  done
  chmod 600 .env
  zold "✓ .env létrehozva, erős véletlen jelszavakkal (csak ezen a szerveren van meg)."
else
  zold "✓ .env már létezik, nem nyúlok hozzá."
fi

# --- 3. Memória ellenőrzése: belefér-e a CRM is? ---
SZABAD_MB=$(free -m | awk '/^Mem:/{print $7}')
PROFIL=""
if [ "$SZABAD_MB" -ge 1600 ]; then
  PROFIL="--profile crm"
  zold "✓ Szabad memória: ${SZABAD_MB} MB – a CRM (NocoDB) is elindul."
else
  sarga "! Szabad memória: ${SZABAD_MB} MB – a CRM-et most kihagyom, hogy a Hungry Doggie biztonságban legyen."
  sarga "  (Ha leállítod az Expo fejlesztői szervert, és újra futtatod a setup.sh-t, a CRM is elindul.)"
fi

# --- 4. Swap ellenőrzése ---
if [ -z "$(swapon --show 2>/dev/null)" ]; then
  sarga "! Nincs swap a szerveren. Ajánlott: 'bash scripts/swap.sh' (egyszer, 2 GB)."
fi

# --- 5. Indítás ---
zold "→ Konténerek letöltése és indítása (első alkalommal pár perc)..."
$DOCKER compose $PROFIL pull -q
$DOCKER compose $PROFIL up -d

# --- 6. Napi mentés beállítása (03:30) ---
MAPPA="$(pwd)"
if ! crontab -l 2>/dev/null | grep -q "kertesz-rendszer/scripts/backup.sh\|$MAPPA/scripts/backup.sh"; then
  ( crontab -l 2>/dev/null; echo "30 3 * * * bash $MAPPA/scripts/backup.sh >> $MAPPA/backups/backup.log 2>&1" ) | crontab -
  zold "✓ Napi mentés beállítva (minden éjjel 03:30, 30 napig megőrizve)."
fi
mkdir -p backups

# --- 7. Állapot ---
sleep 8
echo
zold "=== Állapot ==="
$DOCKER compose $PROFIL ps --format 'table {{.Service}}\t{{.Status}}'
echo
$DOCKER stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' $($DOCKER compose $PROFIL ps -q) 2>/dev/null || true
echo
zold "Kész. Másold be Claude-nak a fenti 'Állapot' részt."
