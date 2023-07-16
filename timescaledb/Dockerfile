ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:14.0.2
ARG BUILD_ARCH=aarch64
ARG GO_VERSION=1.19.0

###########################################
# Define base Image
###########################################
FROM $BUILD_FROM as addon-base

RUN sed -i "s/libcrypto3=3.1.1-r1/libcrypto3=3.1.1-r2/g" /etc/apk/world \
    && sed -i "s/libssl3=3.1.1-r1/libssl3=3.1.1-r2/g" /etc/apk/world \
    && apk update \
    && apk upgrade

####################################
# Previous Addon Image
####################################
FROM husselhans/hassos-addon-timescaledb-${BUILD_ARCH}:2.1.1 as previous-addon

###########################################
# Build TimeScaleDB-tools
###########################################
FROM golang:${GO_VERSION}-alpine AS timescaledb-tools

ENV TOOLS_VERSION 0.8.1

RUN apk update && apk add --no-cache git \
    && go install github.com/timescale/timescaledb-tune/cmd/timescaledb-tune@latest \
    && go install github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy@latest \
    && go install github.com/timescale/timescaledb-backup/cmd/ts-dump@latest \
    && go install github.com/timescale/timescaledb-backup/cmd/ts-restore@latest

###########################################
# Final Image
###########################################
FROM addon-base as addon
ARG BUILD_ARCH

# Add some build-tools
RUN apk add --no-cache --virtual .build-tools \
    wget \
    rsync

# -----------------------------------------
# PostgreSql 14
# -----------------------------------------

# Add Postgresql 14
RUN apk add --no-cache \
    postgresql14-jit \
    postgresql14 \
    postgresql14-dev \
    postgresql14-contrib-jit \
    postgresql14-contrib


# Make sure pg_config follows the most current version
RUN rm /usr/bin/pg_config \
    && ln -s /usr/libexec/postgresql/pg_config /usr/bin/pg_config


# --------------------------------------
# TimescaleDB for PostgreSQl 14 - Build and install
# --------------------------------------
# Enable this if you only want the OSS parts
#ENV OSS_ONLY -DAPACHE_ONLY=1
ARG TIMESCALEDB_VERSION=2.11.1
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
    && apk add --no-cache -u musl \
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
    && ./bootstrap -DCMAKE_BUILD_TYPE=RelWithDebInfo -DREGRESS_CHECKS=OFF -DTAP_CHECKS=OFF -DGENERATE_DOWNGRADE_SCRIPT=ON -DWARNINGS_AS_ERRORS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    # BUGFIX Line below is used to fix the error that <postgres.h> cannot be found, even though we have the postgres-dev package installed.
    && export C_INCLUDE_PATH=$C_INCLUDE_PATH:/usr/include/postgresql/14/server \
    && cd build && make install \
    && cd ~ \
    \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && rm -rf /build 

# -----------------------------------------
# PostgreSql 15
# -----------------------------------------

#Add Postgresql 15
RUN apk add --no-cache \
    postgresql15-jit \
    postgresql15 \
    postgresql15-dev \
    postgresql15-contrib-jit \
    postgresql15-contrib


# Set default postgresql version
RUN rm /usr/libexec/postgresql \
    && ln -s /usr/libexec/postgresql15 /usr/libexec/postgresql \
    && rm /usr/share/postgresql \
    && ln -s /usr/share/postgresql15 /usr/share/postgresql

# Add JIT support
RUN apk add --no-cache \
	-u llvm14-libs

# Add LatestTimescaleDB and Postgis
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
        postgis=3.3.3-r1 \
        gdal-driver-PostGISRaster \
    && \
    apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main/ \
        libturbojpeg

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# --------------------------------------
# TimescaleDB for PostgreSQl 15 - Build and install
# --------------------------------------
# Enable this if you only want the OSS parts
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
    && apk add --no-cache -u musl \
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
    && ./bootstrap -DCMAKE_BUILD_TYPE=RelWithDebInfo -DREGRESS_CHECKS=OFF -DTAP_CHECKS=OFF -DGENERATE_DOWNGRADE_SCRIPT=ON -DWARNINGS_AS_ERRORS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    # BUGFIX Line below is used to fix the error that <postgres.h> cannot be found, even though we have the postgres-dev package installed.
    && export C_INCLUDE_PATH=$C_INCLUDE_PATH:/usr/include/postgresql/15/server \
    && cd build && make install \
    && cd ~ \
    \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 

# --------------------------------------------
# pgAgent - build and install
# --------------------------------------------
RUN mkdir -p /build
COPY pgagent.patch /build/

RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
    && apk add --no-cache -u musl \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                gcc \
                make \
                cmake \
				build-base \
				boost-dev \
				openldap-dev \
    && git clone https://github.com/postgres/pgagent /build/pgagent \
    && cd /build/pgagent \
    && git checkout ${pgagent_version} \
    && git apply -v ../pgagent.patch \
    && cmake . \
    && make && make install \
    && cd ~ \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build \
	&& apk add --no-cache \
				boost-libs

###########################################
# Timescaledb toolkit - Build and Install
########################################### 

# https://docs.timescale.com/self-hosted/latest/tooling/install-toolkit/
# https://packagecloud.io/app/timescale/timescaledb/search?q=timescaledb-toolkit&filter=all&dist=
# https://stackoverflow.com/questions/57749127/how-can-i-specify-the-glibc-version-in-cargo-build-for-rust
# https://stackoverflow.com/questions/57749127/how-can-i-specify-the-glibc-version-in-cargo-build-for-rust

FROM addon

# Copy timescaledb-toolkit
#COPY --from=addon /usr/share/postgresql15 /usr/share/postgresql15
#COPY --from=addon /usr/lib/postgresql15 /usr/lib/postgresql15

# Copy timescaledb-tools
COPY --from=timescaledb-tools /go/bin/* /usr/local/bin/

# Copy the timescaledb and postgis extensions from the previous addon
COPY --from=previous-addon /usr/lib/postgresql14/timescale* /usr/lib/postgresql14/
COPY --from=previous-addon /usr/lib/postgresql14/postgis* /usr/lib/postgresql14/
COPY --from=previous-addon /lib/libssl.so.1.1 /lib/
COPY --from=previous-addon /lib/libcrypto.so.1.1 /lib/

# Add nano for debugging
# RUN set -ex \
#     && apk add --no-cache \
#     nano

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=50000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Copy root fs files
COPY rootfs /

WORKDIR /