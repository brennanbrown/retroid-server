#!/bin/sh
# Push the repo's device/ tree onto the RP2S ($HOME in Termux) over SSH.
set -e
HOST="${RETROID_HOST:-192.168.1.69}"
PORT="${RETROID_PORT:-8022}"

cd "$(dirname "$0")/../device"
tar --no-xattrs -cf - . 2>/dev/null | ssh -p "$PORT" "$HOST" \
	"cd ~ && tar -xf - && chmod +x .termux/boot/*.sh"
echo "deployed device/ -> $HOST:~/"
