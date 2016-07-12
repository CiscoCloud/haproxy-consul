FROM alpine:3.4

MAINTAINER Steven Borrelli <steve@aster.is>

ENV CONSUL_TEMPLATE_VERSION=0.15.0

RUN apk add --update wget && \
    apk add libnl3 bash haproxy ca-certificates zip && \
    wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.1.1/dumb-init_1.1.1_amd64 && \
    chmod +x /usr/local/bin/dumb-init && \
    apk del wget && \
    rm -rf /var/cache/apk/*

ADD https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip /

RUN unzip /consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip  && \
    mv /consul-template /usr/local/bin/consul-template && \
    rm -rf /consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip

RUN mkdir -p /haproxy /consul-template/config.d /consul-template/template.d
ADD config/ /consul-template/config.d/
ADD template/ /consul-template/template.d/

ADD reload.sh /reload.sh
ADD launch.sh /launch.sh

CMD ["/launch.sh"]
