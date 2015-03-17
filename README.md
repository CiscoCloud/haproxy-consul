# haproxy-consul
Dynamic haproxy configuration using consul. 

# Overview 
This project combines [Alpine Linux](https://www.alpinelinux.org), [consul template](https://github.com/hashicorp/consul-template), and [haproxy](http://haproxy.org) 
to create a proxy that forwards all services 

## Building

```
  docker build -t haproxy . 
```


## Running 


```
  doker run -d --net=host -e HAPROXY_DOMAIN=example.com asteris/haproxy-consul 
  
```


