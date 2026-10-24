#!/usr/bin/env bash
# 2 GB swap létrehozása (egyszer kell). Véd a memóriahiány miatti leállás ellen.
set -euo pipefail
if [ -n "$(swapon --show)" ]; then echo "Már van swap, nincs teendő."; exit 0; fi
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-kertesz-swap.conf >/dev/null
sudo sysctl -p /etc/sysctl.d/99-kertesz-swap.conf >/dev/null
echo "Kész: 2 GB swap bekapcsolva."
