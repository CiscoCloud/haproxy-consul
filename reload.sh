#!/bin/bash
set -e
#set the DEBUG env variable to turn on debugging
[[ -n "$DEBUG" ]] && set -x

# Required vars
HAPROXY_MODE=${HAPROXY_MODE:-consul}
HAPROXY_DOMAIN=${HAPROXY_DOMAIN:-haproxy.service.consul}
CONSUL_TEMPLATE=${CONSUL_TEMPLATE:-/usr/local/bin/consul-template}
CONSUL_CONFIG=${CONSUL_CONFIG:-/consul-template/config.d}
CONSUL_CONNECT=${CONSUL_CONNECT:-consul.service.consul:8500}
CONSUL_MINWAIT=${CONSUL_MINWAIT:-2s}
CONSUL_MAXWAIT=${CONSUL_MAXWAIT:-10s}
CONSUL_LOGLEVEL=${CONSUL_LOGLEVEL:-info}



function update_configuration {
    if [[ -n "${CONSUL_TOKEN}" ]]; then
        ctargs="${ctargs} -token ${CONSUL_TOKEN}"
    fi


    if [[ ! -f /consul-template/template.d/haproxy.tmpl ]]; then
      ln -s /consul-template/template.d/${HAPROXY_MODE}.tmpl \
            /consul-template/template.d/haproxy.tmpl
    fi

    # Force a template regeneration on restart (if this file hasn't changed,
    # consul-template won't run the 'optional command' and thus haproxy won't
    # be started)
    [[ -f /tmp/haproxy.cfg ]] && rm /tmp/haproxy.cfg

    ${CONSUL_TEMPLATE}  \
                        -config /consul-template/config.d/haproxy.cfg \
                        -log-level ${CONSUL_LOGLEVEL} \
                        -wait ${CONSUL_MINWAIT}:${CONSUL_MAXWAIT} \
                        -consul ${CONSUL_CONNECT} ${ctargs} \
                        -once \
                        -dry | awk '{if(NR>1)print}' | tee /tmp/haproxy.cfg

    echo "Dumped HA Proxy config to temporary location."
}
function reload_configuration {
    if [[ "$(/usr/sbin/haproxy -c -f /tmp/haproxy.cfg)" ]]; then
        echo "Configuration valid. Going to reload HA Proxy."
        mv /tmp/haproxy.cfg /haproxy/haproxy.cfg
        nl-qdisc-add --dev=lo --parent=1:4 --id=40: --update plug --buffer &> /dev/null
        /usr/sbin/haproxy -f /haproxy/haproxy.cfg -D -p "/var/run/haproxy.pid" -sf "${PID}"  || return 1
        nl-qdisc-add --dev=lo --parent=1:4 --id=40: --update plug--release-indefinite &> /dev/null
        return 0
    else
        return 1
    fi

}
PID="$(cat /var/run/haproxy.pid)"
[[ -f /haproxy/haproxy.cfg ]] && mv /haproxy/haproxy.cfg /haproxy/haproxy.cfg.bak
update_configuration
if reload_configuration; then
    echo "Reloaded HA Proxy with new configuration"
else
    mv /haproxy/haproxy.cfg.bak /haproxy/haproxy.cfg
    echo "Something went wrong. No reload done!"
fi
