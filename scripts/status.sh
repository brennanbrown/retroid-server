#!/bin/sh
# Is sshd up (key auth) and is Caddy serving?
HOST="${RETROID_HOST:-192.168.1.69}"
PORT="${RETROID_PORT:-8022}"

printf "ssh  (%s:%s): " "$HOST" "$PORT"
ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$PORT" "$HOST" 'echo ok' 2>/dev/null || echo FAIL

printf "http (%s:8080): " "$HOST"
curl -so /dev/null -w '%{http_code}\n' -m 5 "http://$HOST:8080/" 2>/dev/null || echo FAIL
