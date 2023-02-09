ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:13.1.1
ARG BUILD_ARCH=aarch64
ARG GO_VERSION=1.19.0

###########################################
# Base Image fixes
###########################################
FROM $BUILD_FROM as addon-base

# Fix libcrypto from the base-image
RUN sed -i "s/libcrypto3=3.0.7-r2/libcrypto3=3.0.8-r0/g" /etc/apk/world \
    && sed -i "s/libssl3=3.0.7-r2/libssl3=3.0.8-r0/g" /etc/apk/world \
    && apk update \
    && apk upgrade

###########################################
# Build TimeScaleDB tools binaries in separate image
###########################################
FROM golang:${GO_VERSION}-alpine AS tools

ENV TOOLS_VERSION 0.8.1

RUN apk update && apk add --no-cache git \
    && go install github.com/timescale/timescaledb-tune/cmd/timescaledb-tune@latest \
    && go install github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy@latest \
    && go install github.com/timescale/timescaledb-backup/cmd/ts-dump@latest \
    && go install github.com/timescale/timescaledb-backup/cmd/ts-restore@latest

####################################################
# Build the latest timescaledb against postgres-12
# We use this to upgrade timescaleDB first
####################################################
FROM addon-base as timescale-pg12

ENV TIMESCALEDB_VERSION 2.9.2
ENV POSTGRES_VERSION 12.13-r1
# Patch the include-path. For some reason, it won't get found by the c-compiler when building timescale.
ENV C_INCLUDE_PATH /usr/include/postgresql/12/server 

# Add postgresql 12
RUN apk add --no-cache \
    postgresql12=$POSTGRES_VERSION \
    postgresql12-dev=$POSTGRES_VERSION

# --------------------------------------
# Build latest TimescaleDB
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
    # Build indicated version
    && cd /build/timescaledb && rm -fr build \
    && git checkout ${TIMESCALEDB_VERSION} \
    && ./bootstrap -DCMAKE_BUILD_TYPE=RelWithDebInfo -DREGRESS_CHECKS=OFF -DTAP_CHECKS=OFF -DGENERATE_DOWNGRADE_SCRIPT=ON -DWARNINGS_AS_ERRORS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    && cd build && make install \
    && cd ~ \
    \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 


#Alias the previous images
FROM husselhans/hassos-addon-timescaledb-${BUILD_ARCH}:1.1.6 as addon-pg12
FROM husselhans/hassos-addon-timescaledb-${BUILD_ARCH}:2.1.1 as addon-previous

FROM addon-base AS addon

#Versions
ENV TIMESCALEDB_VERSION 2.9.2
ENV POSTGRES_VERSION 14.6-r1
ENV PGAGENT_VERSION REL-4_2_2
ENV POSTGIS_VERSION 3.3.2

# --------------------------------------
# PostgreSql 12 - Install (for pg_upgrade reasons)
# --------------------------------------
RUN apk add --no-cache \
    postgresql12

# --------------------------------------
# PostgreSql 14 - Install
# --------------------------------------
RUN apk add --no-cache \
    postgresql14-jit=${POSTGRES_VERSION} \
    postgresql14=${POSTGRES_VERSION} \
    postgresql14-dev=${POSTGRES_VERSION} \
    postgresql14-contrib-jit=${POSTGRES_VERSION} \
    postgresql14-contrib=${POSTGRES_VERSION}

# Add JIT support
RUN apk add --no-cache \
	-u llvm14-libs

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# Copy over the tools
COPY --from=tools /go/bin/* /usr/local/bin/


# --------------------------------------
# TimescaleDB - Build and install
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
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 

# --------------------------------------
# pgAgent - Build and install
# --------------------------------------
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
    && git checkout ${PGAGENT_VERSION} \
    && cmake . \
    && make && make install \
    && cd ~ \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build \
	&& apk add --no-cache \
				boost-libs

# --------------------------------------
# PostGIS - Add required packages for runtime (see postgis dependencies)
# --------------------------------------
# RUN set -ex \
#     && apk add --no-cache \
#     --repository http://dl-cdn.alpinelinux.org/alpine/v3.17/main/ \

RUN set -ex \
    && apk add --no-cache \
    #--repository http://dl-cdn.alpinelinux.org/alpine/v3.17/community/ \
	openexr \ 
    poppler \
    gdal \
    geos \
    json-c \
    libgcc \
    libpq \
    libstdc++ \
    libxml2 \ 
    musl \
    pcre \
    perl \
    proj \
    protobuf-c

# --------------------------------------
# PostGIS - Build and install
# --------------------------------------
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
                wget \
    && mkdir -p /build/ \
    && wget -P /build https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                gcc \
                make \
                cmake \
				build-base \
                libxml2-dev \
                protobuf-c-dev \
    #&& apk add --no-cache --virtual .community-build-deps --repository http://dl-cdn.alpinelinux.org/alpine/v3.17/community/ \
    && apk add --no-cache --virtual .community-build-deps \
                geos-dev \
                proj-dev \
                gdal-dev \
    && cd /build \
    && tar xvzf postgis-${POSTGIS_VERSION}.tar.gz \
    && cd /build/postgis-${POSTGIS_VERSION} \
    && ./configure --with-pgconfig=/usr/libexec/postgresql14/pg_config \
    && make && make install \
    && cd ~ \
    && apk del .fetch-deps .build-deps .community-build-deps \
    && rm -rf /build 

# Below for Postgresql 15
# RUN set -ex \
#     apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/v3.17/community/ \
#     postgis=${POSTGIS_VERSION}-r1 

# --------------------------------------
# Timescaledb toolkit - Build and Install
# --------------------------------------
FROM addon AS timescaledb-toolkit
ENV ALPINE_VERSION 3.17
ENV TOOLKIT_VERSION 1.13.1
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
                wget \
                curl \
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                gcc \
                make \
                cmake \
		build-base \
    #&& apk add --no-cache --virtual .community-build-deps --repository http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community/ \
    && apk add --no-cache --virtual .community-build-deps \
                rust \
                cargo \
    && export PATH="/root/.cargo/bin:${PATH}" \
    && cargo install cargo-pgx \
    && cargo install rustfmt

RUN set -ex \
    && mkdir -p /build/ \
    # && chown postgres:postgres -R /build \
    # && chown postgres:postgres -R /usr/share/postgresql14 \
    # && chown postgres:postgres -R /usr/lib/postgresql14 \        
    && cd /build \
        && git clone https://github.com/timescale/timescaledb-toolkit.git . \
        && git checkout ${TOOLKIT_VERSION} \
        && cd extension \
        # initdb fails as root so generate the correct config ourselves
        # && cargo pgx init --pg14 /usr/lib/postgresql/14/bin/pg_config        
        && mkdir -p /root/.pgx \
        && printf '[configs]\npg14="/usr/libexec/postgresql14/pg_config"\n' > /root/.pgx/config.toml \
        && cargo pgx install --release --pg_config /usr/libexec/postgresql14/pg_config \
        && cargo run --manifest-path ../tools/post-install/Cargo.toml -- /usr/libexec/postgresql14/pg_config \
    && cd ~ \
    && apk del .fetch-deps .build-deps .community-build-deps \
    && rm -rf /build

####################################
# Now build final image
####################################
FROM addon

# Copy timescaledb-toolkit
COPY --from=timescaledb-toolkit /usr/share/postgresql14 /usr/share/postgresql14
COPY --from=timescaledb-toolkit /usr/lib/postgresql14 /usr/lib/postgresql14

# -----------------------------------------------------------------------------------------------------------
# PG12 Upgrade: For upgrade reasons, copy over timescale and postgis extentions from the previous PG12 addon
# -----------------------------------------------------------------------------------------------------------
# Copy old pre-compiled versions of postgresql extentions from the old plugin (never trust old alpine images ;)
COPY --from=addon-pg12 /usr/lib/postgresql/* /usr/lib/postgresql12/
COPY --from=addon-pg12 /usr/lib/libproj* /usr/lib/

# Copy new timescale version build against postgres-12, and copy over to postgresql12 directory on the new addon.
COPY --from=timescale-pg12 /usr/lib/postgresql12/* /usr/lib/postgresql12/
# Dumb fix for a docker build: https://github.com/moby/moby/issues/37965
RUN true 

COPY --from=timescale-pg12 /usr/share/postgresql12/extension/* /usr/share/postgresql12/extension/
# Dumb fix for a docker build: https://github.com/moby/moby/issues/37965
RUN true

# Fixup a packaging problem with an Alpine Package..
RUN cp /usr/share/postgresql14/extension/postgis--unpackaged--3.3.2.sql /usr/share/postgresql14/extension/postgis--ANY--3.3.2.sql

# Copy over all addons of previous addon to the new one
COPY --from=addon-previous /usr/lib/postgresql14/* /usr/lib/postgresql14/
COPY --from=addon-previous /usr/lib/libproj* /usr/lib/


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
