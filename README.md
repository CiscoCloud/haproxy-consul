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
that your application should forward on port 10001, haproxy will open port 10001
and direct traffic to that port. This works with auto-assigned ports (ports set
to 0), as well. If you want HTTP load balancing using the host header, you need
a specify the following labels on your app:

```
{
    "id": "files",
    "cmd": "python -m SimpleHTTPServer $PORT",
    "mem": 50,
    "cpus": 0.1,
    "instances": 1,
    "ports": [0, 0],
    "labels": {
        "HAPROXY_HTTP": "true",
        "HTTP_PORT_IDX_0_NAME": "files",
        "HTTP_PORT_IDX_1_NAME": "stub"
    }
}
```

In this example, `HAPROXY_HTTP` is set to true, which is required for HTTP load
balancing. Then each of the port indices gets a name, as in
`HTTP_PORT_IDX_0_NAME`. These will be balanced to `files.haproxy.service.consul`
and `stub.haproxy.service.consul`, respectively. In addition, haproxy will
forward all the ports that have been assigned as "global ports" by Marathon.
This ends up with a configuration like the following:

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
    acl host_files hdr(host) -i files.haproxy.service.consul
    use_backend files_backend if host_files
    acl host_stub hdr(host) -i stub.haproxy.service.consul
    use_backend stub_backend if host_stub

# files backends
backend files_backend
    mode http
    server 1.2.3.4:49165 # TASK_RUNNING

backend stub_backend
    mode http
    server 1.2.3.4:49166 # TASK_RUNNING

# TCP services
listen files_10000
    mode tcp
    bind *:10000
    server task_name 1.2.3.4:41965 # TASK_RUNNING

listen files_10001
    mode tcp
    bind *:10001
    server task_name 1.2.3.4:49166 # TASK_RUNNING
```

In this case, Marathon has assigned ports `10000` and `10001` to the `[0, 0]`
array provided in the app JSON, respective to their position within the array.
The tasks are working on ports 49165 and 49166 (which again are respective to
their position within the array.) This means that the haproxy service is
listening on `10000` and `10001` to forward the ports themselves, and since HTTP
names were given in the config labels, haproxy will also forward traffic to
those ports where the host header is at `{name}.haproxy.service.consul`.

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

consul KV variables:

Variable | Description | Default
---------|-------------|---------
`service/haproxy/maxconn` | maximum connections | 256
`service/haproxy/timeouts/connect` | connect timeout | 5000ms
`service/haproxy/timeouts/client` | client timeout | 50000ms
`service/haproxy/timeouts/server` | server timeout | 50000ms

# License

Released under an Apache 2.0 License. See LICENSE
