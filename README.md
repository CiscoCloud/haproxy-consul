# haproxy-consul

Dynamic haproxy configuration using consul packed into a Docker container that weighs 24MB.

**Table of Contents**

- [haproxy-consul](#haproxy-consul)
- [Overview](#overview)

  - [How it works](#how-it-works)
  - [Running](#running)

    - [Usage](#usage)
    - [Modes](#modes)

  - [Service registration](#service-registration)

    - [Registrator](#registrator)
    - [Naming services](#naming-services)

  - [Options](#options)

    - [SSL Termination](#ssl-termination)

- [License](#license)

# Overview

This project combines [Alpine Linux](https://www.alpinelinux.org), [consul template](https://github.com/hashicorp/consul-template), and [haproxy](http://haproxy.org) to create a proxy that forwards traffic to apps registered in consul.

## How it works

First, you must set up a wildcard dns (using something like CloudFlare or [xip.io](http://xip.io)). This means that if your domain is `example.com`, any request to a `<name>.example.com` will resolve to the IP of your haproxy container.

Inside the haproxy container, a header match is used to map `<application>.example.com` to the service registered in consul under `application`.

## Running

### Usage

Start the container as follows:

```
docker run --net=host --name=haproxy -d asteris/haproxy-consul
```

alternative way not sharing network stack with host:

```
docker run -d --name haproxy -p 80:80 -p 443:443 -e CONSUL_CONNECT=172.17.0.1:8500 asteris/haproxy-consul
```

Now that it is set up, connect to an app:

```
curl -L http://myapp.mycompany.com
```

Or if you do not have a wildcard DNS:

```
curl -L http://myapp.180.19.20.21.xip.io
```

### Modes

haproxy-consul can run in two different modes: forwarding either consul services (the default) or Marathon apps. This behavior is controlled by the `HAPROXY_MODE` variable, which should be set to `consul` or `marathon`.

#### Reload configuration

It's possible to reload the HA proxy configuration without restarting the container itself. `docker exec -it <container_id> bash reload.sh`

#### consul Configuration

When `HAPROXY_MODE` is set to `consul`, haproxy-consul uses consul service names to set subdomains. No other configuration is required.

#### Marathon Configuration

When `HAPROXY_MODE` is set to `marathon`, haproxy-consul assumes that there will be app information in the `marathon` prefix of the Consul KV store. It was written to work with the information provided by [marathon-consul](https://github.com/CiscoCloud/marathon-consul).

By default, haproxy will forward all Marathon-assigned ports. So if you specify that your application should own port 10000 in the "ports" member of the app JSON, haproxy will open port 10000 to direct traffic to your app. This works with auto-assigned ports (ports set to 0), as well. This is all automatic, you don't need to think about it other than to pull the ports from Marathon.

However, if you want HTTP load balancing using the host header, you need a specify the following labels on your app:

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

In this example (available at [`examples/rails.json`](examples/rails.json)), the hello-rails application is assigned port 10000\. This is different from the service or host port of the app; it is a global value that Marathon tracks. This means that haproxy-consul will forward all TCP traffic to port 10000 to the app workers.

When `HAPROXY_HTTP` is set to true and `HTTP_PORT_IDX_0_NAME` is set to a DNS-valid name Haproxy will forward all HTTP traffic with the host header (the name specified plus [`HAPROXY_DOMAIN`](#options)) to the app workers. This extends to as many ports as you'd care to give it in the form `HTTP_PORT_IDX_{port_number}_NAME`.

This particular app results in something like the following haproxy configuration:

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

## Service registration

### Registrator

Run a registrator to automatically add and remove services. The best option so far is to run [gliderlabs/registrator](https://github.com/gliderlabs/registrator) container through the following command.

```
docker run -d --net host --name registrator -v /var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://127.0.0.1:8500
```

An other way to run it, without net host is:

```
docker run -d --name registrator -v /var/run/docker.sock:/tmp/docker.sock gliderlabs/registrator consul://172.17.0.1:8500
```

### Naming services

The service can be declared through the environment variables `SERVICE_NAME` and `SERVICE_TAGS`.

The `SERVICE_NAME` or `SERVICE_<port>_NAME` is the actual name you want to give to the service. It will be the subdomain of your requests: `<SERVICE_NAME>.domain.tld`.

The domain can be specified using `SERVICE_TAGS` using the followind syntax: `<domain>_<tld>`. Note the `_` (underscore) instead of a `.` (dot), this approach was used because consul forbids the presence of dots in a service name or tag. If no `SERVICE_TAGS` is specified, the service will be available on **all** domains.

Here is an complete example:

```
docker run -p 80 -e SERVICE_NAME=www -e SERVICE_TAGS=example_com,example_net webserver
```

This will make the webserver's 80 port accessible through request to `www.example.com` or `www.example.net`. Also note that requests to `example.com` or `example.com` will be redirected (302 permanent redirect) to the corresponding `www` subdomain.

## Options

If you want to override the config and template files, mount a volume and set the `CONSUL_CONFIG` environment variable before launch. In docker this can be accomplished with the `-e` option:

```
docker run -v /host/config:/my_config -e CONSUL_CONFIG=/my_config -net=host --name=haproxy -d asteris/haproxy-consul
```

If you need to have a root CA added so you can connect to Consul over SSL, mount a directory containing your root CA at `/usr/local/share/ca-certificates/`.

Configure using the following environment variables:

Variable              | Description                                                       | Default
--------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------------
`HAPROXY_DOMAIN`      | The domain to match against                                       | `haproxy.service.consul` (for `app.haproxy.service.consul`).
`HAPROXY_MODE`        | forward consul service or Marathon apps                           | `consul` (`marathon` also available, as described [above](#modes))
`HAPROXY_USESSL`      | Enable the SSL frontend (see [below](#ssl-termination))           | `false`
`HAPROXY_STATS`       | Enable Statistics UI on port 1936 (see [below](#ssl-termination)) | `false`
`HAPROXY_STATS_TITLE` | Change Statistics Title (see [below](#ssl-termination))           | `false`
`HAPROXY_STATS_URI`   | Change Statistics URI (see [below](#ssl-termination))             | `false`

consul-template variables:

Variable          | Description                                                          | Default
----------------- | -------------------------------------------------------------------- | --------------------------------
`CONSUL_TEMPLATE` | Location of consul-template bin                                      | `/usr/local/bin/consul-template`
`CONSUL_CONNECT`  | The consul connection                                                | `consul.service.consul:8500`
`CONSUL_CONFIG`   | File/directory for consul-template config                            | `/consul-template/config.d`
`CONSUL_LOGLEVEL` | Valid values are "debug", "info", "warn", and "err".                 | `debug`
`CONSUL_TOKEN`    | The [Consul API token](http://www.consul.io/docs/internals/acl.html) |

### SSL Termination

If you wish to configure HAproxy to terminate incoming SSL connections, you must set the environment variable `HAPROXY_USESSL=true`, and mount your SSL certificate at `/certs/` - this folder should contain all your certificates, each should contain both the SSL certificate and the private key to use (with no passphrase), in PEM format. You should also include any intermediate certificates in this bundle.

For example:

```
docker run -v /etc/ssl/wildcard.example.com.pem:/certs/ssl.crt:ro --net=host --name=haproxy asteris/haproxy-consul
```

SSL termination is currently only available in 'consul' mode.

# License

Released under an Apache 2.0 License. See LICENSE
