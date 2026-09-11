#!/usr/bin/env bash
set -euo pipefail

web_root=/var/www/chirag

test -f "$web_root/index.html"
chown -R root:root "$web_root"
find "$web_root" -type d -exec chmod 0755 {} +
find "$web_root" -type f -exec chmod 0644 {} +

systemctl reload nginx
curl --fail --silent --show-error --max-time 15 http://127.0.0.1/ > /dev/null