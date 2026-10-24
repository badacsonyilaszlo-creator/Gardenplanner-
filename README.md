# Kertészet – automatizálási rendszer

A kertészeti vállalkozás háttérrendszere a VPS-en, a Hungry Doggie mellett, attól teljesen elkülönítve.

| Rész | Mire jó | Memóriakorlát |
|---|---|---|
| n8n | Automatizálás: e-mailek, AI-válaszok, CRM, emlékeztetők | 768 MB |
| PostgreSQL | Adatbázis (saját, nem a Hungry Doggie-é) | 384 MB |
| NocoDB | CRM-felület (csak ha van elég szabad memória) | 384 MB |
| Listmonk | Hírlevél, e-mail-listák | 128 MB |

Minden szolgáltatás csak a szerveren belül érhető el. Kívülről a domain és a HTTPS beállítása után lesznek elérhetők.

---

## Telepítés – lépésről lépésre (Terminusból)

### 1. Kulcs a repóhoz (csak először)
```bash
ssh-keygen -t ed25519 -f ~/.ssh/kertesz_repo -N ""
cat ~/.ssh/kertesz_repo.pub
```
A kiírt sort (`ssh-ed25519 ...`) add hozzá a GitHubon:
repó → **Settings → Deploy keys → Add deploy key** (cím: VPS). **Pipáld be: Allow write access** – ezzel tölti fel a szerver az állapotjelentést (csak ehhez a repóhoz ad jogot).

### 2. Letöltés
```bash
cd ~
GIT_SSH_COMMAND="ssh -i ~/.ssh/kertesz_repo" git clone git@github.com:badacsonyilaszlo-creator/Gardenplanner-.git
cd Gardenplanner-
git config core.sshCommand "ssh -i ~/.ssh/kertesz_repo"
```

### 3. Swap (csak egyszer, ha még nincs)
```bash
bash scripts/swap.sh
```

### 4. Telepítés
```bash
bash setup.sh
```
A végén kiírja az állapotot – ezt másold be Claude-nak.

---

## Frissítés, amikor Claude új verziót tölt fel
```bash
cd ~/Gardenplanner- && git pull && bash setup.sh
```

## Hasznos parancsok
| Mit | Parancs |
|---|---|
| Állapot | `bash scripts/status.sh` |
| Kézi mentés | `bash scripts/backup.sh` |
| Leállítás | `docker compose --profile crm down` (az adatok megmaradnak) |

## Automatikus frissítés
A szerver 10 percenként megnézi a GitHubot; ha új verzió van, telepíti, és ha valami nem indul el, visszaáll az előzőre.
Óránként állapotjelentést tölt fel a `status` ágra (STATUS.md) – jelszót és ügyféladatot nem tartalmaz.
Napló: `backups/autoupdate.log`. Kikapcsolás: `crontab -e`, és töröld az autoupdate sort.

## Biztonság
- A GitHub-fiókod védelme mostantól a szerveré is: kapcsold be a kétlépcsős azonosítást (2FA).
- A jelszavak a `.env` fájlban vannak, csak a szerveren. Ez a fájl soha nem kerül a GitHubra.
- API-kulcsot, jelszót soha ne másolj a chatbe.
- Mentés: minden éjjel 03:30, a `backups/` mappába, 30 napig.
