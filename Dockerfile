FROM gliderlabs/alpine

MAINTAINER Steven Borrelli <steve@aster.is>

ENV CONSUL_TEMPLATE_VERSION=0.11.0

RUN apk-install bash haproxy ca-certificates unzip

ADD https://github.com/hashicorp/consul-template/releases/download/v${CONSUL_TEMPLATE_VERSION}/consul_template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip /

RUN unzip /consul_template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip  && \
    mv /consul-template /usr/local/bin/consul-template && \
    rm -rf /consul_template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip

RUN mkdir -p /haproxy /consul-template/config.d /consul-template/template.d

ADD config/ /consul-template/config.d/
ADD template/ /consul-template/template.d/
ADD launch.sh /launch.sh

CMD ["/launch.sh"]
