# haproxy-consul

Dynamic haproxy configuration using consul packed into a Docker container that weighs 18MB.

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc/generate-toc again -->
**Table of Contents**

- [haproxy-consul](#haproxy-consul)
- [Overview](#overview)
    - [How it works](#how-it-works)
    - [Service registration](#service-registration)
        - [Registrator](#registrator)
        - [Naming services](#naming-services)
    - [Building](#building)
    - [Running](#running)
        - [Usage](#usage)
    - [Options](#options)
        - [SSL Termination](#ssl-termination)
- [License](#license)

<!-- markdown-toc end -->

# Overview

This project combines [Alpine Linux](https://www.alpinelinux.org), [consul template](https://github.com/hashicorp/consul-template), and [haproxy](http://haproxy.org)
to create a proxy that forwards traffic to apps registered in consul.

## How it works
First, you must set up a wildcard dns (using something like CloudFlare or [xip.io](http://xip.io)). This means that if your domain is `example.com`, any request to  a `<name>.example.com` will resolve to the IP of your haproxy container.

Inside the haproxy container, a header match is used to map `<application>.example.com` to the service registered in consul under `application`.

## Building

```
docker build -t haproxy .
```

## Service registration
### Registrator 
Run a registrator to automatically add and remove services.
The best option so far is to run [gliderlabs/registrator](https://github.com/gliderlabs/registrator) container through the following command.
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

## Running
### Usage
Start the container as follows:
```
docker run --net=host --name=haproxy -d asteris/haproxy-consul
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
docker run -v /host/config:/my_config -e CONSUL_CONFIG=/my_config -net=host --name=haproxy -d asteris/haproxy-consul
```

If you need to have a root CA added so you can connect to Consul over SSL, mount
a directory containing your root CA at `/usr/local/share/ca-certificates/`.

consul-template variables:

Variable | Description | Default
---------|-------------|---------
`CONSUL_TEMPLATE` | Location of consul-template bin | `/usr/local/bin/consul-template`
`CONSUL_CONNECT`  | The consul connection | `consul.service.consul:8500`
`CONSUL_CONFIG`   | File/directory for consul-template config | `/consul-template/config.d`
`CONSUL_LOGLEVEL` | Valid values are "debug", "info", "warn", and "err". | `debug`
`CONSUL_TOKEN`    | The [Consul API token](http://www.consul.io/docs/internals/acl.html) | 

### SSL Termination

If you wish to configure HAproxy to terminate incoming SSL connections, you must set the environment variable `HAPROXY_USESSL=true`, and mount your SSL certificate at `/certs/` - this folder should contain all your certificates, each should contain both the SSL certificate and the private key to use (with no passphrase), in PEM format. You should also include any intermediate certificates in this bundle.

For example:
```
docker run -v /etc/ssl/wildcard.example.com.pem:/certs/ssl.crt:ro --net=host --name=haproxy haproxy-consul
```
SSL termination is currently only available in 'consul' mode.

# License

Released under an Apache 2.0 License. See LICENSE
