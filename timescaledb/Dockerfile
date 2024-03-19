ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:15.0.7
ARG BUILD_ARCH=aarch64
ARG GO_VERSION=1.19.0

###########################################
# Define base Image
###########################################
FROM $BUILD_FROM as addon-base

RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    apk update

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
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    apk add --virtual .build-tools \
    wget \
    rsync

# -----------------------------------------
# Install postgreSql 15 (OLD)
# -----------------------------------------
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    apk add \
    postgresql15-jit \
    postgresql15 \
    postgresql15-dev \
    postgresql15-contrib-jit \
    postgresql15-contrib

# Make sure pg_config follows the most current version
RUN rm /usr/bin/pg_config \
    && ln -s /usr/libexec/postgresql/pg_config /usr/bin/pg_config

# -----------------------------------------
# PostgreSql 16 (NEW)
# -----------------------------------------

RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    apk add \
    postgresql16-jit \
    postgresql16 \
    postgresql16-dev \
    postgresql16-contrib-jit \
    postgresql16-contrib

# Set default postgresql version to 16
RUN rm /usr/libexec/postgresql \
    && ln -s /usr/libexec/postgresql16 /usr/libexec/postgresql \
    && rm /usr/share/postgresql \
    && ln -s /usr/share/postgresql16 /usr/share/postgresql

# Add Latest Postgis
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    apk add --repository https://dl-cdn.alpinelinux.org/alpine/v3.19/community \
        postgis=3.4.2-r0 \
        gdal-driver-PostGISRaster \
    && \
    apk add --repository https://dl-cdn.alpinelinux.org/alpine/v3.19/main \
        libturbojpeg

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions


# --------------------------------------------
# pgAgent - build pached version and install
# --------------------------------------------
RUN mkdir -p /build
COPY pgagent.patch /build/

RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
        && apk add -u musl \
    && apk add --virtual .build-deps \
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
	&& apk add \
				boost-libs

# --------------------------------------
# PostGIS - Add required packages for runtime (see postgis dependencies)
# --------------------------------------
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add  \
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
# PostGIS - Build and install OLD Postgis (for upgrade reasons)
# --------------------------------------
ENV POSTGIS_VERSION 3.3.3
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
                wget \
    && mkdir -p /build/ \
    && wget -P /build https://download.osgeo.org/postgis/source/postgis-${POSTGIS_VERSION}.tar.gz \
    && apk add --virtual .build-deps \
                coreutils \
                gcc \
                make \
                cmake \
				build-base \
                libxml2-dev \
                protobuf-c-dev \
    #&& apk add --virtual .community-build-deps --repository http://dl-cdn.alpinelinux.org/alpine/v3.17/community/ \
    && apk add --virtual .community-build-deps \
                geos-dev \
                proj-dev \
                gdal-dev \
    && cd /build \
    && tar xvzf postgis-${POSTGIS_VERSION}.tar.gz \
    && cd /build/postgis-${POSTGIS_VERSION} \
    && ./configure --with-pgconfig=/usr/libexec/postgresql15/pg_config \
    && make && make install \
    && cd ~ \
    && apk del .fetch-deps .build-deps .community-build-deps \
    && rm -rf /build 

#Define timesaledb versions
FROM timescale/timescaledb:2.14.2-pg15 as timescale-pg15
FROM timescale/timescaledb:2.14.2-pg16 as timescale-pg16

###########################################
# Timescaledb toolkit - Build and Install
########################################### 

# https://docs.timescale.com/self-hosted/latest/tooling/install-toolkit/
# https://packagecloud.io/app/timescale/timescaledb/search?q=timescaledb-toolkit&filter=all&dist=
# https://stackoverflow.com/questions/57749127/how-can-i-specify-the-glibc-version-in-cargo-build-for-rust

FROM timescale-pg16 AS timescaledb-toolkit
ENV TOOLKIT_VERSION 1.18.0

RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    --mount=type=cache,id=cargo-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/root/.cargo \
    set -ex \
    && apk add \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
                wget \
                curl \
    && apk add \
                coreutils \
                gcc \
                make \
                cmake \
		        build-base \
    && apk add --repository http://dl-cdn.alpinelinux.org/alpine/v3.19/main/ \
                rust \
                cargo \
    && export PATH="/root/.cargo/bin:${PATH}" \
    && cargo install --version '=0.10.2' --force cargo-pgrx \
    && cargo install rustfmt

# Add compatibility librarties for timescaledb toolkit
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    --mount=type=cache,id=cargo-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/root/.cargo \
    set -ex \
    && apk add gcompat clang16-libclang

RUN --mount=type=cache,id=pgrx-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/root/.pgrx \
    --mount=type=cache,id=cargo-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/root/.cargo \
    set -ex \
    && export PATH="/root/.cargo/bin:${PATH}" \
    && mkdir -p /build/ \
    && cd /build \
        && git clone https://github.com/timescale/timescaledb-toolkit.git . \
        && git checkout ${TOOLKIT_VERSION} \
        && cd extension \
        # initdb fails as root so generate the correct config ourselves
        # && cargo pgx init --pg16 /usr/lib/postgresql/14/bin/pg_config        
        && mkdir -p /root/.pgrx \
        && printf '[configs]\npg16="/usr/local/bin/pg_config"\n' > /root/.pgrx/config.toml \
        && cargo pgrx install --release \
        && cargo run --manifest-path ../tools/post-install/Cargo.toml -- /usr/local/bin/pg_config \
    && cd ~ \
    && rm -rf /build

FROM addon

# Copy timescaledb-tools
COPY --from=timescaledb-tools /go/bin/* /usr/local/bin/

# Copy the new timescale version to the old postgresql version
COPY --from=timescale-pg15 /usr/local/lib/postgresql/timescaledb*.so /usr/lib/postgresql15/
COPY --from=timescale-pg15 /usr/local/share/postgresql/extension/timescaledb* /usr/share/postgresql15/extension/

# Copy the new timescale version to the new postgresql version
COPY --from=timescale-pg16 /usr/local/lib/postgresql/timescaledb*.so /usr/lib/postgresql16/
COPY --from=timescale-pg16 /usr/local/share/postgresql/extension/timescaledb* /usr/share/postgresql16/extension/

# Copy libssl over from the old addon. This version is needed in alpine 3.19.
# FIXUP
COPY --from=timescale-pg15 /lib/libssl.so.1.1 /lib/
COPY --from=timescale-pg15 /lib/libcrypto.so.1.1 /lib/

# Copy new timescaledb-toolkit to new postgresql version
COPY --from=timescaledb-toolkit /usr/local/lib/postgresql/timescaledb_toolkit* /usr/lib/postgresql16/
COPY --from=timescaledb-toolkit /usr/local/share/postgresql/extension/timescaledb_toolkit* /usr/share/postgresql16/extension/

# Add compatibility librarties for timescaledb toolkit
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        gcompat \
        clang16-libclang

#Add nano for debugging
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add --no-cache \
        nano

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=50000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

# Copy root fs files
COPY rootfs /

WORKDIR /
