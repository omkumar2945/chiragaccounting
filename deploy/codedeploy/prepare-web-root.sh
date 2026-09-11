#!/usr/bin/env bash
set -euo pipefail

install -d -m 0755 -o root -g root /var/www/html
find /var/www/html -mindepth 1 -maxdepth 1 -exec rm -rf {} +