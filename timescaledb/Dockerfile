ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:14.0.2
ARG BUILD_ARCH=aarch64
ARG GO_VERSION=1.19.0

###########################################
# Base Image
###########################################
FROM $BUILD_FROM as addon-base

###########################################
# Build TimeScaleDB tools binaries in separate image
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

# Add old postgis and timescaledb for postgresql 14 by downloading it, and installing it manually.
# The reason is, otherwise these packagefiles would be overwritten by the newer versions in Postgresql 15.
RUN set -ex \
    && mkdir /download \
    && cd /download \
    && wget http://dl-cdn.alpinelinux.org/alpine/v3.16/community/${BUILD_ARCH}/postgresql-timescaledb-2.6.1-r1.apk \
    && wget http://dl-cdn.alpinelinux.org/alpine/v3.16/community/${BUILD_ARCH}/postgis-3.2.2-r0.apk \
    && wget http://dl-cdn.alpinelinux.org/alpine/v3.16/main/${BUILD_ARCH}/poppler-22.05.0-r0.apk \
    && mkdir ./timescale && tar -xv -f postgresql-timescaledb-2.6.1-r1.apk -C ./timescale \
    && cp -r ./timescale/* / \
    && mkdir ./postgis && tar -xv -f postgis-3.2.2-r0.apk -C ./postgis \
    && cp -r ./postgis/* / \
    && mkdir ./poppler && tar -xv -f poppler-22.05.0-r0.apk -C ./poppler \
    && cp -r ./poppler/* / \
    && cd .. \
    && rm -rf /download
    
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

# Add JIT support
RUN apk add --no-cache \
	-u llvm14-libs

# Add LatestTimescaleDB and Postgis
RUN apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
    postgresql-timescaledb=2.11.0-r0 \
    postgis=3.3.3-r0

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# Copy over the timescaledb-tools
COPY --from=timescaledb-tools /go/bin/* /usr/local/bin/

# --------------------------------------------
# pgagent - build and install
# --------------------------------------------
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
    && mkdir -p /build/ \
    && git clone https://github.com/postgres/pgagent /build/pgagent \
    && apk add --no-cache -u musl \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                gcc \
                make \
                cmake \
				build-base \
				boost-dev \
				openldap-dev \
    && cd /build/pgagent \
    && git checkout ${pgagent_version} \
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


####################################
# Back to build final image
####################################
FROM addon

# --------------------------------------
# Bake in support for GLIBC (AARCH64 support??)
# --------------------------------------

# ENV \
#     LANG=en_US.UTF-8 \
#     LANGUAGE=en_US:en \
#     LC_ALL=en_US.UTF-8

# ENV \
#     GLIBC_REPO=https://github.com/sgerrand/alpine-pkg-glibc \
#     GLIBC_VERSION=2.35-r1

# RUN set -ex && \
#     apk --update add libstdc++ curl ca-certificates && \
#     for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION}; \
#         do curl -sSL ${GLIBC_REPO}/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
#     apk add --allow-untrusted /tmp/*.apk && \
#     rm -v /tmp/*.apk && \
#     /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

# Copy timescaledb-toolkit
COPY --from=addon /usr/share/postgresql15 /usr/share/postgresql15
COPY --from=addon /usr/lib/postgresql15 /usr/lib/postgresql15

# --------------------------------------
# Finish image
# --------------------------------------

# Add nano for debugging
RUN set -ex \
    && apk add --no-cache \
    nano

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=50000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Copy data
COPY rootfs /

WORKDIR /
