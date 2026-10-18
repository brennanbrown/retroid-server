#!/data/data/com.termux/files/usr/bin/sh
# Termux:Boot entrypoint
# Wake lock first. CPU awake with the screen off.
termux-wake-lock
echo "$(date -u +%FT%TZ) boot: starting services" >> $HOME/boot.log
sshd
nohup caddy run --config $HOME/Caddyfile >> $HOME/caddy.log 2>&1 &
