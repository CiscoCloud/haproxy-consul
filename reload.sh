#!/bin/bash
if [[ "$(/usr/sbin/haproxy -c -f /haproxy/haproxy.cfg)" ]]; then
    kill -TERM "$(cat /var/run/haproxy.pid)"
    /usr/sbin/haproxy -D -p /var/run/haproxy.pid  -f /haproxy/haproxy.cfg -sf "$(cat /var/run/haproxy.pid)"
    echo "Reloaded config"
else
    echo "Config error!!"
fi
