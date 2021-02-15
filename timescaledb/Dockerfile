ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:9.1.2
ARG BUILD_ARCH=aarch64

###########################################
# Build TimeScaleDB tools binaries in separate image
###########################################
ARG GO_VERSION=1.14.0
FROM --platform=${BUILD_ARCH} golang:${GO_VERSION}-alpine AS tools

ENV TOOLS_VERSION 0.8.1

RUN apk update && apk add --no-cache git \
    && mkdir -p ${GOPATH}/src/github.com/timescale/ \
    && cd ${GOPATH}/src/github.com/timescale/ \
    && git clone https://github.com/timescale/timescaledb-tune.git \
    && git clone https://github.com/timescale/timescaledb-parallel-copy.git \
	# Fixup build arch to be compatible with GO cross compile
	&& REAL_ARCH="$BUILD_ARCH" \
	&& if [[ ${REAL_ARCH} == "aarch64" ]]; then export REAL_ARCH="arm64"; fi \
	&& if [[ ${REAL_ARCH} == "armv7" ]]; then export REAL_ARCH="arm"; fi \
    # Build timescaledb-tune
    && cd timescaledb-tune/cmd/timescaledb-tune \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && GOOS="linux" GOARCH="${REAL_ARCH}" go build -o /go/bin/timescaledb-tune \
    # Build timescaledb-parallel-copy
    && cd ${GOPATH}/src/github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && GOOS="linux" GOARCH="${REAL_ARCH}" go build -o /go/bin/timescaledb-parallel-copy


####################################
# Now build image and copy in tools
####################################
FROM $BUILD_FROM

# --------------------------------------
# Add PostgreSql 12.5
# --------------------------------------
ENV POSTGRES_VERSION=12.5-r0
RUN apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/v3.12/main/ \
    postgresql=${POSTGRES_VERSION} \
    postgresql-dev=${POSTGRES_VERSION}

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# Copy over the tools
COPY --from=tools /go/bin/* /usr/local/bin/

# --------------------------------------
# Build TimescaleDB 2.0.1
# --------------------------------------
# Fix versions
ENV TIMESCALEDB_VERSION 2.0.1
# Enable this if you only want the OSS parts
#ENV OSS_ONLY -DAPACHE_ONLY=1
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
    && mkdir -p /build/ \
    && git clone https://github.com/timescale/timescaledb /build/timescaledb \
    \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                dpkg-dev dpkg \
                gcc \
                libc-dev \
                make \
                cmake \
                util-linux-dev \
    \
    # Build current version
    && cd /build/timescaledb && rm -fr build \
    && git checkout ${TIMESCALEDB_VERSION} \
    && ./bootstrap -DREGRESS_CHECKS=OFF -DWARNINGS_AS_ERRORS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    && cd build && make install \
    && cd ~ \
    \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 

# --------------------------------------
# Build pgAgent
# --------------------------------------
ENV PGAGENT_VERSION REL-4_0_0
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
    && mkdir -p /build/ \
    && git clone https://github.com/postgres/pgagent /build/pgagent \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                gcc \
                make \
                cmake \
				build-base \
				boost-dev \
				openldap-dev \
    && cd /build/pgagent \
    && git checkout ${PGAGENT_VERSION} \
    && cmake . \
    && make && make install \
    && cd ~ \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build \
	&& apk add --no-cache \
				boost-libs

# --------------------------------------
# Add Postgis
# --------------------------------------
# 3.1.1-r1
RUN set -ex \
    && apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
	postgis openexr 
RUN set -ex \
    && apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    json-c poppler

# --------------------------------------
# Finish image
# --------------------------------------

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=18000

# Copy data
COPY rootfs /

WORKDIR /
