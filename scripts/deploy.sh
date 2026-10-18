#!/bin/sh
# Push the repo's device/ tree onto the Android device ($HOME in Termux) over SSH.
set -e
HOST="${DEVICE_HOST:-${RETROID_HOST:-192.168.1.69}}"
PORT="${DEVICE_SSH_PORT:-${RETROID_PORT:-8022}}"

cd "$(dirname "$0")/../device"
COPYFILE_DISABLE=1 tar --no-xattrs --exclude='._*' --exclude='.DS_Store' -cf - . 2>/dev/null | ssh -p "$PORT" "$HOST" \
	"cd ~ && tar -xf - && chmod +x .termux/boot/*.sh"
echo "deployed device/ -> $HOST:~/"
