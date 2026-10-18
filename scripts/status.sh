#!/bin/sh
# Is sshd up (key auth) and is Caddy serving?
HOST="${DEVICE_HOST:-${RETROID_HOST:-192.168.1.69}}"
PORT="${DEVICE_SSH_PORT:-${RETROID_PORT:-8022}}"
HTTP_PORT="${DEVICE_HTTP_PORT:-8080}"

printf "ssh  (%s:%s): " "$HOST" "$PORT"
ssh -o BatchMode=yes -o ConnectTimeout=5 -p "$PORT" "$HOST" 'echo ok' 2>/dev/null || echo FAIL

printf "http (%s:%s): " "$HOST" "$HTTP_PORT"
curl -so /dev/null -w '%{http_code}\n' -m 5 "http://$HOST:$HTTP_PORT/" 2>/dev/null || echo FAIL
