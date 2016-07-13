FROM alpine:3.4

MAINTAINER Steven Borrelli <steve@aster.is>

ENV CONSUL_TEMPLATE_VERSION=0.15.0
ENV HAPROXY_VERSION=1.6.6

ADD install-haproxy.sh /tmp/install-haproxy.sh

RUN apk add --update wget zip && \
    # install deployed packages
    apk add libnl3 bash ca-certificates && \
    # install dumb-init
    wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.1.1/dumb-init_1.1.1_amd64 && \
    chmod +x /usr/local/bin/dumb-init && \
    # install haproxy
    /tmp/install-haproxy.sh && \
    # install consul-template
    wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
    unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip  && \
    mv consul-template /usr/local/bin/consul-template && \
    rm -rf consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip && \
    # cleanup
    apk del wget zip && \
    rm -rf /var/cache/apk/*

RUN mkdir -p /haproxy /consul-template/config.d /consul-template/template.d
ADD config/ /consul-template/config.d/
ADD template/ /consul-template/template.d/

ADD reload.sh /reload.sh
ADD launch.sh /launch.sh

CMD ["/launch.sh"]

### Udacity Image Metadata
COPY Dockerfile /Dockerfile

ARG udacity_name
ARG udacity_version
ARG udacity_git_url
ARG udacity_git_sha
ARG udacity_build_id
ARG udacity_build_timestamp
ARG udacity_build_origin

LABEL com.udacity.name="$udacity_name" \
      com.udacity.version="$udacity_version" \
      com.udacity.git.url="$udacity_git_url" \
      com.udacity.git.sha="$udacity_git_sha" \
      com.udacity.build.id="$udacity_build_id" \
      com.udacity.build.timestamp="$udacity_build_timestamp" \
      com.udacity.build.origin="$udacity_build_origin" \
      com.udacity.dockerfile="/Dockerfile" \
      com.udacity.api.packages="apk info -vv"
