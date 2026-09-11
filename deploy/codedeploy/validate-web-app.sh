#!/usr/bin/env bash
set -euo pipefail

test -f /var/www/html/index.html
curl --fail --silent --show-error --max-time 15 http://127.0.0.1/ > /dev/null