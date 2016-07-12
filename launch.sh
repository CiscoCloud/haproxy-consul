#!/usr/local/bin/dumb-init /bin/bash

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

function usage {
cat <<USAGE
  launch.sh             Start a consul-backed haproxy instance

Configure using the following environment variables:

  HAPROXY_DOMAIN        The domain to match against
                        (default: example.com for app.example.com)

  HAPROXY_MODE          The mode for template rendering
                        (default "consul" for Consul services, can also be set
                        to "marathon" for Marathon apps through marathon-consul)

Consul-template variables:
  CONSUL_TEMPLATE       Location of consul-template bin
                        (default /usr/local/bin/consul-template)


  CONSUL_CONNECT        The consul connection
                        (default consul.service.consul:8500)

  CONSUL_CONFIG         File/directory for consul-template config
                        (/consul-template/config.d)

  CONSUL_LOGLEVEL       Valid values are "debug", "info", "warn", and "err".
                        (default is "info")

  CONSUL_TOKEN		Consul ACL token to use
			(default is not set)

USAGE
}

function launch_haproxy {
    if [[ "$(ls -A /usr/local/share/ca-certificates)" ]]; then
        cat /usr/local/share/ca-certificates/* >> /etc/ssl/certs/ca-certificates.crt
    fi

    if [[ -n "${CONSUL_TOKEN}" ]]; then
        ctargs="${ctargs} -token ${CONSUL_TOKEN}"
    fi

    vars=( "$@" )

    if [[ ! -f /consul-template/template.d/haproxy.tmpl ]]; then
      ln -s /consul-template/template.d/${HAPROXY_MODE}.tmpl \
            /consul-template/template.d/haproxy.tmpl
    fi

    # Generate self-signed certificate, if required.
    if [[ ( -n "${HAPROXY_USESSL}" ) && ! -f /haproxy/ssl.crt ]]; then
      openssl req -x509 -newkey rsa:2048 -nodes -keyout /haproxy/key.pem -out /haproxy/cert.pem -days 365 -sha256 -subj "/CN=*.${HAPROXY_DOMAIN}"
      cat /haproxy/cert.pem /haproxy/key.pem > /haproxy/ssl.crt
    fi

    # Remove haproxy PID file, in case we're restarting
    [[ -f /var/run/haproxy.pid ]] && rm /var/run/haproxy.pid

    # Force a template regeneration on restart (if this file hasn't changed,
    # consul-template won't run the 'optional command' and thus haproxy won't
    # be started)
    [[ -f /haproxy/haproxy.cfg ]] && rm /haproxy/haproxy.cfg

    exec ${CONSUL_TEMPLATE} -config ${CONSUL_CONFIG} \
                       -log-level ${CONSUL_LOGLEVEL} \
                       -wait ${CONSUL_MINWAIT}:${CONSUL_MAXWAIT} \
                       -consul ${CONSUL_CONNECT} ${ctargs} "${vars[@]}"

}

launch_haproxy "$@"
