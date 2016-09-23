#!/usr/bin/env sh
set -ex
cd /tmp
apk update

HAPROXY_VERSION=${HAPROXY_VERSION:-1.6.6}
HAPROXY_MAJOR_VERSION=${HAPROXY_VERSION:0:3}
LIBSLZ_VERSION=v1.0.0
BUILD_DEPS="curl make gcc g++ linux-headers python pcre-dev openssl-dev lua5.3-dev"
RUN_DEPS="pcre libssl1.0 musl libcrypto1.0 busybox lua5.3-libs"

# install build dependencies
apk add --virtual build-dependencies ${BUILD_DEPS}

# Compile libslz
curl -OJ "http://git.1wt.eu/web?p=libslz.git;a=snapshot;h=v1.0.0;sf=tgz"
tar zxvf libslz-${LIBSLZ_VERSION}.tar.gz
make -C libslz static

# fetch haproxy
wget http://www.haproxy.org/download/${HAPROXY_MAJOR_VERSION}/src/haproxy-${HAPROXY_VERSION}.tar.gz
tar -xzf haproxy-*.tar.gz
cd haproxy-*

# build haproxy
make PREFIX=/usr TARGET=linux2628 USE_PCRE=1 USE_PCRE_JIT=1 USE_OPENSSL=1 \
    USE_SLZ=1 SLZ_INC=../libslz/src SLZ_LIB=../libslz \
	USE_LUA=1 LUA_LIB=/usr/lib/lua5.3/ LUA_INC=/usr/include/lua5.3 \
    DEBUG=-g

# install
make PREFIX=/usr install-bin

# remove build dependencies
apk del build-dependencies

# install run dependencies
apk add ${RUN_DEPS}

# clean
cd -
rm -rf /tmp/*
rm -rf /var/cache/apk/*
