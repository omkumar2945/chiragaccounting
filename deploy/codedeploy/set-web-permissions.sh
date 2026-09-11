#!/usr/bin/env bash
set -euo pipefail

chown -R root:root /var/www/html
find /var/www/html -type d -exec chmod 0755 {} +
find /var/www/html -type f -exec chmod 0644 {} +