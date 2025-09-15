#!/bin/bash
# Manage Cloudflare IPs in UFW with a "cloudflare" label
[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)

add_rules() {
  echo "[*] Adding Cloudflare IP ranges to UFW..."
  for ip in $CF_IPV4; do
    sudo ufw allow proto tcp from $ip to any port 80,443 comment "cloudflare"
  done
  for ip in $CF_IPV6; do
    sudo ufw allow proto tcp from $ip to any port 80,443 comment "cloudflare"
  done
  sudo ufw reload
}

delete_rules() {
  echo "[*] Deleting all Cloudflare rules from UFW..."
  # Extract all rule numbers that have "cloudflare" in comment
  RULES=$(sudo ufw status numbered | grep cloudflare | awk -F'[][]' '{print $2}' | sort -nr)
  for r in $RULES; do
    echo "Deleting rule #$r"
    sudo ufw --force delete $r
  done
  sudo ufw reload
}

case "$1" in
  add)
    add_rules
    ;;
  delete)
    delete_rules
    ;;
  *)
    echo "Usage: $0 {add|delete}"
    ;;
esac
