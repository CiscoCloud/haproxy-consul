FROM alpine:3.4

MAINTAINER Steven Borrelli <steve@aster.is>


ENV CONSUL_TEMPLATE_VERSION=0.14.0

RUN apk update && \
    apk add libnl3 bash haproxy ca-certificates && \
    apk add wget zip && \
    wget -O /consul-template.zip "https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip" && \
    unzip /consul-template.zip  && \
    mv /consul-template /usr/local/bin/consul-template && \
    rm -rf /consul-template.zip && \
    apk del wget zip && \
    rm -rf /var/cache/apk/*

RUN mkdir -p /haproxy /consul-template/config.d /consul-template/template.d
ADD config/ /consul-template/config.d/
ADD template/ /consul-template/template.d/

ADD reload.sh /reload.sh
ADD launch.sh /launch.sh

CMD ["/launch.sh"]
