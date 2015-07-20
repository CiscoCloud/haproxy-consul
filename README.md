# haproxy-consul

Dynamic haproxy configuration using consul packed into a Docker container that weighs 18MB.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc/generate-toc again -->
**Table of Contents**

- [haproxy-consul](#haproxy-consul)
- [Overview](#overview)
    - [How it works](#how-it-works)
    - [Building](#building)
    - [Running](#running)
        - [Modes](#modes)
            - [consul Configuration](#consul-configuration)
            - [Marathon Configuration](#marathon-configuration)
        - [Usage](#usage)
    - [Options](#options)
- [License](#license)

<!-- markdown-toc end -->

# Overview

This project combines [Alpine Linux](https://www.alpinelinux.org), [consul template](https://github.com/hashicorp/consul-template), and [haproxy](http://haproxy.org)
to create a proxy that forwards traffic to apps registered in Marathon and forwarded with [marathon-consul](https://github.com/CiscoCloud/marathon-consul).

## How it works

First, you must set up a wildcard dns (using something like CloudFlare or [xip.io](http://xip.io)). This means that if your domain is `example.com`, any request to  a `<name>.example.com` will resolve to the IP of your haproxy container.

Inside the haproxy container, a header match is used to map `<application>.example.com` to the service registered in consul under `application`.

## Building

```
docker build -t haproxy .
```

## Running

### Modes

haproxy-consul can run in two different modes: forwarding either consul services
(the default) or Marathon apps. This behavior is controlled by the
`HAPROXY_MODE` variable, which should be set to `consul` or
`marathon`.

#### consul Configuration

When `HAPROXY_MODE` is set to `consul`, haproxy-consul uses consul service names
to set subdomains. No other configuration is required.

#### Marathon Configuration

When `HAPROXY_MODE` is set to `marathon`, haproxy-consul assumes that there will
be app information in the `marathon` prefix of the Consul KV store. It was
written to work with the information provided by
[marathon-consul](https://github.com/CiscoCloud/marathon-consul).

By default, haproxy will forward all Marathon-assigned ports. So if you specify
that your application should own port 10000 in the "ports" member of the app
JSON, haproxy will open port 10000 to direct traffic to your app. This works
with auto-assigned ports (ports set to 0), as well. This is all automatic, you
don't need to think about it other than to pull the ports from Marathon.

However, if you want HTTP load balancing using the host header, you need a
specify the following labels on your app:

```
{
    "id": "hello-rails",
    "cmd": "cd hello && bundle install && bundle exec unicorn -p $PORT",
    "mem": 100,
    "cpus": 1.0,
    "instances": 1,
    "uris": [
        "http://downloads.mesosphere.com/tutorials/RailsHello.tgz"
    ],
    "env": {
        "RAILS_ENV": "production"
    },
    "ports": [10000],
    "labels": {
        "HAPROXY_HTTP": "true",
        "HTTP_PORT_IDX_0_NAME": "hello_rails",
    }
}
```

In this example (available at [`examples/rails.json`](examples/rails.json)), the
hello-rails application is assigned port 10000. This is different from the
service or host port of the app; it is a global value that Marathon tracks. This
means that haproxy-consul will forward all TCP traffic to port 10000 to the app
workers.

When `HAPROXY_HTTP` is set to true and `HTTP_PORT_IDX_0_NAME` is set to a
DNS-valid name Haproxy will forward all HTTP traffic with the host header (the
name specified plus [`HAPROXY_DOMAIN`](#options)) to the app workers. This
extends to as many ports as you'd care to give it in the form
`HTTP_PORT_IDX_{port_number}_NAME`.

This particular app results in something like the following haproxy
configuration:

```
global
    maxconn 256
    debug

defaults
    mode tcp
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms

# HTTP services
frontend www
    mode http
    bind *:80

    # files ACLs
    acl host_hello_rails hdr(host) -i hello_rails.haproxy.service.consul
    use_backend hello_rails_backend if host_hello_rails

# files backends
backend hello_rails_backend
    mode http
    server 1.2.3.4:49165 # TASK_RUNNING

# TCP services
listen hello-rails_10000
    mode tcp
    bind *:10000
    server task_id 1.2.3.4:41965 # TASK_RUNNING
```

### Usage

If you don't want to configure wildcard dns, you can use xip.io. In this example, we are going to assume that the IP of your server is `180.19.20.21`, then all domains in `180.19.20.21.xip.io` will forward to your host.

Start the container as follows:

```
docker run --net=host --name=haproxy -d -e HAPROXY_DOMAIN=180.19.20.21.xip.io asteris/haproxy-consul
```

If you have wildcard DNS set up for your company (say at `*.mycompany.com`) use the following:

```
docker run --net=host --name=haproxy -d -e HAPROXY_DOMAIN=mycompany.com asteris/haproxy-consul
```

Now that it is set up, connect to an app:

```
curl -L http://myapp.mycompany.com
```

Or if you do not have a wildcard DNS:

```
curl -L http://myapp.180.19.20.21.xip.io
```

## Options

If you want to override the config and template files, mount a volume and set the `CONSUL_CONFIG` environment variable before launch. In docker this can be accomplished with the `-e` option:

```
docker run -v /host/config:/my_config -e CONSUL_CONFIG=/my_config -net=host --name=haproxy -d -e HAPROXY_DOMAIN=mycompany.com asteris/haproxy-consul
```

If you need to have a root CA added so you can connect to Consul over SSL, mount
a directory containing your root CA at `/usr/local/share/ca-certificates/`.

Configure using the following environment variables:

Variable | Description | Default
---------|-------------|---------
`HAPROXY_DOMAIN` | The domain to match against | `haproxy.service.consul` (for `app.haproxy.service.consul`).
`HAPROXY_MODE` | forward consul service or Marathon apps | `consul` (`marathon` also available, as described [above](#modes))

consul-template variables:

Variable | Description | Default
---------|-------------|---------
`CONSUL_TEMPLATE` | Location of consul-template bin | `/usr/local/bin/consul-template`
`CONSUL_CONNECT`  | The consul connection | `consul.service.consul:8500`
`CONSUL_CONFIG`   | File/directory for consul-template config | `/consul-template/config.d`
`CONSUL_LOGLEVEL` | Valid values are "debug", "info", "warn", and "err". | `debug`
`CONSUL_TOKEN`    | The [Consul API token](http://www.consul.io/docs/internals/acl.html) | 

consul KV variables:

Variable | Description | Default
---------|-------------|---------
`service/haproxy/maxconn` | maximum connections | 256
`service/haproxy/timeouts/connect` | connect timeout | 5000ms
`service/haproxy/timeouts/client` | client timeout | 50000ms
`service/haproxy/timeouts/server` | server timeout | 50000ms

# License

Released under an Apache 2.0 License. See LICENSE
