# haproxy-consul

Dynamic haproxy configuration using consul packed into a Docker container that weighs 18MB.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc/generate-toc again -->
**Table of Contents**

- [haproxy-consul](#haproxy-consul)
- [Overview](#overview)
    - [How it works](#how-it-works)
    - [Building](#building)
    - [Running](#running)
    - [Options](#options)
- [License](#license)

<!-- markdown-toc end -->

# Overview

This project combines [Alpine Linux](https://www.alpinelinux.org), [consul template](https://github.com/hashicorp/consul-template), and [haproxy](http://haproxy.org)
to create a proxy that forwards traffic to apps registered in Marathon and forwarded with [marathon-consul](https://github.com/CiscoCloud/marathon-consul).

## How it works

First, you must set up a wildcard dns (using something like CloudFlare or [xip.io](http://xip.io)). This means that if your domain is `example.com`, any request to  a `<name>.example.com` will resolve to the IP of your haproxy container.

Inside the haproxy container, a header match is used to map `<application>.example.com` to the service registered in consul under `aplication`.

## Building

```
docker build -t haproxy .
```

## Running

### Marathon Apps

By default, haproxy will forward all Marathon-assigned ports. So if you specify
that your application should forward on port 10001, haproxy will open port 10001
and direct traffic to that port. This works with auto-assigned ports, as well.
If you want HTTP load balancing using the host header, just specify some labels on your app:

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
and `stub.haproxy.service.consul`, respectively.

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

Now that it is set up, connect to an app registered in Marathon.

```
curl -L http://myapp.mycompany.com
```

Or if you do not have a wildcard DNS

```
curl -L http://myapp.180.19.20.21.xip.io
```

## Options

If you wish to override the config and template files, mount a volume and change the `CONSUL_CONFIG` environment variable upon launch. In docker this is via the `-e` option:

```
docker run -v /host/config:/my_config -e CONSUL_CONFIG=/my_config -net=host --name=haproxy -d -e HAPROXY_DOMAIN=mycompany.com asteris/haproxy-consul
```

Configure using the following environment variables:

Variable | Description | Default
---------|-------------|---------
`HAPROXY_DOMAIN` | The domain to match against | `example.com` (for `app.example.com`). Defaults to `haproxy.service.consul`

Consul-template variables:

Variable | Description | Default
---------|-------------|---------
`CONSUL_TEMPLATE` | Location of consul-template bin | `/usr/local/bin/consul-template`
`CONSUL_CONNECT`  | The consul connection | `consul.service.consul:8500`
`CONSUL_CONFIG`   | File/directory for consul-template config | `/consul-template/config.d`
`CONSUL_LOGLEVEL` | Valid values are "debug", "info", "warn", and "err". | `debug`

Consul KV variables:

Variable | Description | Default
---------|-------------|---------
`service/haproxy/maxconn` | maximum connections | 256
`service/haproxy/timeouts/connect` | connect timeout | 5000ms
`service/haproxy/timeouts/client` | client timeout | 50000ms
`service/haproxy/timeouts/server` | server timeout | 50000ms

# License

Released under an Apache 2.0 License. See LICENSE
