ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:16.2.1
ARG BUILD_ARCH=aarch64

ARG ALPINE_VERSION=3.20

# Define the versions for all components of the addon
# These images are all prebuild, otherwise building the docker images takes waaaay to long
FROM timescale/timescaledb:2.16.1-pg15                                      as timescale-pg15
FROM timescale/timescaledb:2.16.1-pg16                                      as timescale-pg16
# hadolint ignore=DL3007
FROM husselhans/hassos-addon-timescaledb-timescaledb-tools:latest           as timescaledb-tools
FROM husselhans/hassos-addon-timescaledb-postgis-pg15:3.3.3                 as postgis-pg15
FROM husselhans/hassos-addon-timescaledb-pgagent-pg16:4.2.2                 as pgagent-pg16
FROM husselhans/hassos-addon-timescaledb-timescaledb-toolkit-pg16:1.18.0    as timescaledb-toolkit-pg16

###########################################
# Define base Image
###########################################
# hadolint ignore=DL3006
FROM $BUILD_FROM as addon
ARG BUILD_ARCH
ARG TARGETARCH=${BUILD_ARCH}
ARG TARGETVARIANT

# Add some handy tools
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk update \
    && apk add ca-certificates \
    && apk add \
        wget \
        rsync \
        nano

###########################################
# Install all sub-components
###########################################

# -----------------------------------------
# PostgreSql 15 (OLD)
# -----------------------------------------
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
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
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
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

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# -----------------------------------------
# Postgis pg-15 (OLD)
# -----------------------------------------

# Postgis + Postgis-Raster
COPY --from=postgis-pg15 --link /usr/local/lib/postgresql/postgis* /usr/lib/postgresql15/

COPY --from=postgis-pg15 --link /usr/local/lib/postgresql/bitcode/postgis-3/* /usr/lib/postgresql15/bitcode/postgis-3/
COPY --from=postgis-pg15 --link /usr/local/lib/postgresql/bitcode/postgis_raster-3/* /usr/lib/postgresql15/bitcode/postgis_raster-3/

COPY --from=postgis-pg15 --link /usr/local/share/postgresql/contrib/postgis* /usr/share/postgresql15/contrib/
COPY --from=postgis-pg15 --link /usr/local/share/postgresql/extension/postgis* /usr/share/postgresql15/extension/

# -----------------------------------------
# Postgis pg-16 (NEW)
# -----------------------------------------
#Add required packages for runtime (see postgis dependencies)
# hadolint ignore=DL3018
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
        
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add --repository https://dl-cdn.alpinelinux.org/alpine/v3.19/community --allow-untrusted \
        postgis=3.4.2-r2 \
        gdal-driver-PostGISRaster \
    && \
    apk add --repository https://dl-cdn.alpinelinux.org/alpine/v3.19/main \
        libturbojpeg

# -----------------------------------------
# Timescale pg-15 (OLD)
# -----------------------------------------
# Copy the new timescale version to the old postgresql version
COPY --from=timescale-pg15 --link /usr/local/lib/postgresql/timescaledb*.so /usr/lib/postgresql15/
COPY --from=timescale-pg15 --link /usr/local/share/postgresql/extension/timescaledb* /usr/share/postgresql15/extension/
# FIXUP Copy libssl over from the old addon. This version is needed in alpine 3.19.
COPY --from=timescale-pg15 --link /lib/libssl.so.1.* /lib/
COPY --from=timescale-pg15 --link /lib/libcrypto.so.1.* /lib/

# -----------------------------------------
# Timescale pg-16 (NEW)
# -----------------------------------------
# Copy the new timescale version to the new postgresql version
COPY --from=timescale-pg16 --link /usr/local/lib/postgresql/timescaledb*.so /usr/lib/postgresql16/
COPY --from=timescale-pg16 --link /usr/local/share/postgresql/extension/timescaledb* /usr/share/postgresql16/extension/

# --------------------------------------------
# pgAgent pg-16 (NEW)
# --------------------------------------------
# Copy the new timescale version to the new postgresql version
COPY --from=pgagent-pg16 --link /usr/local/lib/postgresql/pgagent*.so /usr/lib/postgresql16/
COPY --from=pgagent-pg16 --link /usr/local/share/postgresql/extension/pgagent* /usr/share/postgresql16/extension/
COPY --from=pgagent-pg16 --link /usr/local/share/postgresql/extension/pgagent* /usr/share/postgresql16/extension/

COPY --from=pgagent-pg16 --link /usr/local/share/pgagent.sql /usr/local/share/
COPY --from=pgagent-pg16 --link /usr/local/bin/pgagent /usr/local/bin/

# Add compatibility libraries
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        boost-libs

# --------------------------------------
# Timescaledb pg16 toolkit (NEW)
# --------------------------------------
# Copy new timescaledb-toolkit to new postgresql version
COPY --from=timescaledb-toolkit-pg16 --link /usr/local/lib/postgresql/timescaledb_toolkit* /usr/lib/postgresql16/
COPY --from=timescaledb-toolkit-pg16 --link /usr/local/share/postgresql/extension/timescaledb_toolkit* /usr/share/postgresql16/extension/

# Add compatibility librarties for timescaledb toolkit
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        gcompat \
        clang16-libclang

# --------------------------------------
# Timescaledb Tools pg16 toolkit (NEW)
# --------------------------------------
# Copy timescaledb-tools
COPY --from=timescaledb-tools /go/bin/* /usr/local/bin/

###########################################
# Finalize Image
###########################################

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=50000 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0

ARG CACHE_BUST

# Timestamp the build
RUN date +%Y%m%d%H%M%S > /build-timestamp

# Copy root fs files
# hadolint ignore=DL3021
COPY --link rootfs /rootfs
RUN rsync -LKavz /rootfs/ / && rm -rf /rootfs

WORKDIR /

# Build arugments
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION
ARG BUILD_REPOSITORY

# Labels
LABEL \
    io.hass.name="Timescaledb HA Addon (${BUILD_ARCH})" \
    io.hass.description="Home Assistant Add-on: TimescaleDb" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="base" \
    io.hass.version=${BUILD_VERSION} \
    io.hass.base.version=${BUILD_VERSION} \
    io.hass.base.name="alpine" \
    io.hass.base.image="hassioaddons/base" \
    maintainer="Hans van Essen <hans@expaso.nl>" \
    org.opencontainers.image.title="Timescaledb HA Addon (${BUILD_ARCH})" \
    org.opencontainers.image.description="Home Assistant Add-on: TimescaleDb" \
    org.opencontainers.image.vendor="Expaso BV" \
    org.opencontainers.image.authors="Hans van Essen <hans@expaso.nl>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://hub.docker.com/repository/docker/husselhans/hassos-addon-timescaledb-${BUILD_ARCH}/general" \
    org.opencontainers.image.source="https://github.com/Expaso/hassos-addon-timescaledb" \
    org.opencontainers.image.documentation="https://github.com/Expaso/hassos-addon-timescaledb/blob/master/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}