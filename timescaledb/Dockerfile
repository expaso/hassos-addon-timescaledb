ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:11.1.1
ARG BUILD_ARCH=aarch64
###########################################
# Build TimeScaleDB tools binaries in separate image
###########################################
ARG GO_VERSION=1.14.0

FROM golang:${GO_VERSION}-alpine AS tools

RUN apk update && apk add --no-cache git \
    && go get github.com/timescale/timescaledb-tune/cmd/timescaledb-tune \
    && go get github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && go get github.com/timescale/timescaledb-backup/cmd/ts-dump \
    && go get github.com/timescale/timescaledb-backup/cmd/ts-restore \
    && go build -o /go/bin/timescaledb-tune -v github.com/timescale/timescaledb-tune/cmd/timescaledb-tune \
    && go build -o /go/bin/timescaledb-parallel-copy -v github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && go build -o /go/bin/ts-dump -v github.com/timescale/timescaledb-backup/cmd/ts-dump \
    && go build -o /go/bin/ts-restore -v github.com/timescale/timescaledb-backup/cmd/ts-restore

####################################################
# Build a latest timescaledb against postgres-12
# We use this to upgrade timescaleDB first
####################################################
FROM $BUILD_FROM as timescale-pg12
ENV TIMESCALEDB_VERSION 2.6.0

# Patch the include-path. For some reason, it won't get found by the c-compiler while builing timescale.
ENV C_INCLUDE_PATH /usr/include/postgresql/12/server

ENV POSTGRES_VERSION 12.10-r0
RUN apk add --no-cache \
    postgresql12=${POSTGRES_VERSION} \
    postgresql12-dev=${POSTGRES_VERSION}

# --------------------------------------
# Build TimescaleDB
# --------------------------------------
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
                krb5-dev \
                libc-dev \
                make \
                cmake \
                util-linux-dev \
    \
    # Build current version
    && cd /build/timescaledb && rm -fr build \
    && git checkout ${TIMESCALEDB_VERSION} \
    && ./bootstrap -DREGRESS_CHECKS=OFF -DTAP_CHECKS=OFF -DGENERATE_DOWNGRADE_SCRIPT=ON -DWARNINGS_AS_ERRORS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    && cd build && make install \
    && cd ~ \
    \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 


####################################
# Now build image and copy in tools
####################################
FROM husselhans/hassos-addon-timescaledb-${BUILD_ARCH}:1.1.6 as addon-pg12
FROM $BUILD_FROM

ENV TIMESCALEDB_VERSION 2.6.0

# --------------------------------------
# Add PostgreSql 14
# --------------------------------------
ENV POSTGRES_VERSION 14.2-r0
RUN apk add --no-cache \
    postgresql14-jit=${POSTGRES_VERSION} \
    postgresql14=${POSTGRES_VERSION} \
    postgresql14-dev=${POSTGRES_VERSION}

# --------------------------------------
# Add previous PostgreSql 12 (for pg_upgrade reasons)
# --------------------------------------
RUN apk add --no-cache \
    postgresql12

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# Copy over the tools
COPY --from=tools /go/bin/* /usr/local/bin/

# --------------------------------------
# Build new TimescaleDB
# --------------------------------------
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
                krb5-dev \
                libc-dev \
                make \
                cmake \
                util-linux-dev \
    \
    # Build current version
    && cd /build/timescaledb && rm -fr build \
    && git checkout ${TIMESCALEDB_VERSION} \
    && ./bootstrap -DREGRESS_CHECKS=OFF -DTAP_CHECKS=OFF -DGENERATE_DOWNGRADE_SCRIPT=ON -DWARNINGS_AS_ERRORS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    && cd build && make install \
    && cd ~ \
    \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 

# --------------------------------------
# Build pgAgent
# --------------------------------------
ENV PGAGENT_VERSION REL-4_2_2
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
# Add Postgis and openexr
# --------------------------------------
ENV POSTGIS_VERSION 3.2.1-r1
RUN set -ex \
    && apk add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
    json-c poppler
RUN set -ex \
    && apk -UvX http://dl-cdn.alpinelinux.org/alpine/edge/main \
    add --no-cache \
    --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
	-u postgis=${POSTGIS_VERSION} openexr 

# --------------------------------------------------------------------------------------------
# For upgrade reasons, copy over timescale and postgis extentions from the previous PG12 addon
# --------------------------------------------------------------------------------------------
# Copy old pre-compiled versions of postgresql extentions from the old plugin (never trust old alpine images ;)
COPY --from=addon-pg12 /usr/lib/postgresql/* /usr/lib/postgresql12/
COPY --from=addon-pg12 /usr/lib/libproj* /usr/lib/

# Copy new timescale version build against postgres-12, and copy over to postgresql12 directory on the new addon.
# Yes! I know it looks like we're copying over from the wrong postgresql version (14), but it's just a build-glitch
# using the wrong foldername (postgresql14 instead of 12).. sigh..not my fault.
COPY --from=timescale-pg12 /usr/lib/postgresql14/* /usr/lib/postgresql12/
# Dumb fix for a docker build: https://github.com/moby/moby/issues/37965
RUN true 

COPY --from=timescale-pg12 /usr/share/postgresql14/extension/* /usr/share/postgresql12/extension/
# Dumb fix for a docker build: https://github.com/moby/moby/issues/37965
RUN true

# Fixup a packaging problem with an Alpine Package..
RUN cp /usr/share/postgresql14/extension/postgis--unpackaged--3.2.1.sql /usr/share/postgresql14/extension/postgis--ANY--3.2.1.sql

# --------------------------------------
# Finish image
# --------------------------------------

# Add nano for debugging
RUN set -ex \
    && apk add --no-cache \
    nano

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=18000

# Copy data
COPY rootfs /

WORKDIR /
