#!/usr/bin/env sh
set -eu

REFRESH_SECONDS="${REFRESH_SECONDS:-21600}"

sh /generate_index.sh

(
  while true; do
    sleep "$REFRESH_SECONDS"
    sh /generate_index.sh
    nginx -s reload
  done
) &

exec nginx -g 'daemon off;'