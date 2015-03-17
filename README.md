# haproxy-consul
Dynamic haproxy configuration using consul packed into a Docker container that weighs 18MB. 

# Overview 
This project combines [Alpine Linux](https://www.alpinelinux.org), [consul template](https://github.com/hashicorp/consul-template), and [haproxy](http://haproxy.org) 
to create a proxy that forwards traffic to services registered in consul.


## How it works

First, you must set up a wildcard dns (using something like CloudFlare or [xip.io](http://xip.io)). This means that if your domain is `example.com`, any request to  a `<name>.example.com` will resolve to the IP of your haproxy container. 

Inside the haproxy container, a header match is used to map `<application>.example.com` to the service registered in consul under `aplication`.

## Building

```
  docker build -t haproxy . 
```


## Running 
If you don't want to configure wildcard dns, you can use xip.io. In this example, we are going to assume that the IP of your server is `180.19.20.21`, then all domains in `180.19.20.21.xip.io` will forward to your host. 

Start the container as follows:

```
docker run --net=host --name=haproxy -d -e HAPROXY_DOMAIN=180.19.20.21.xip.io asteris/haproxy-consul

```

If you have wildcard DNS set up for your company (say at `*.mycompany.com`) use the following:

```
docker run --net=host --name=haproxy -d -e HAPROXY_DOMAIN=mycompany.com asteris/haproxy-consul  
```

Now that it is set up, connect to an app registered via consul. 

```
curl -L http://myapp.mycompany.com
```

# License
Released under an Apache 2.0 License. See LICENSE



