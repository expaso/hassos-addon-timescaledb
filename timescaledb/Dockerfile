ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:20.2.0
ARG BUILD_ARCH=aarch64

ARG ALPINE_VERSION=3.23

# Define the versions for all components of the addon
# These images are all prebuild, otherwise building the docker images takes waaaay to long
# Where possible, we just take the latest version from the Alpine repository, so it's
# possible we won't mention the latest version here.
# The dependency images are built on the same TimescaleDB image (and so the same Alpine
# release as the base image above), hence the -ts<version> suffix on their tags.
FROM timescale/timescaledb:2.31.0-pg17                                                          AS timescale-pg17
FROM timescale/timescaledb:2.31.0-pg18                                                          AS timescale-pg18

# hadolint ignore=DL3007
FROM ghcr.io/expaso/timescaledb/dependency/timescaledb-tools:latest                                    AS timescaledb-tools
FROM ghcr.io/expaso/timescaledb/dependency/pgagent-pg17:pgagent-4.2.3-ts2.31.0                         AS pgagent-pg17
FROM ghcr.io/expaso/timescaledb/dependency/pgagent-pg18:pgagent-4.2.3-ts2.31.0                         AS pgagent-pg18
FROM ghcr.io/expaso/timescaledb/dependency/postgis-pg17:3.6.4-ts2.31.0                                 AS postgis-pg17
FROM ghcr.io/expaso/timescaledb/dependency/postgis-pg18:3.6.4-ts2.31.0                                 AS postgis-pg18
FROM ghcr.io/expaso/timescaledb/dependency/timescaledb-toolkit-pg17:1.27.0-p2-ts2.31.0                 AS timescaledb-toolkit-pg17
FROM ghcr.io/expaso/timescaledb/dependency/timescaledb-toolkit-pg18:1.27.0-p2-ts2.31.0                 AS timescaledb-toolkit-pg18
FROM ghcr.io/expaso/timescaledb/dependency/postgresql-extension-system-stat-pg17:3.2-ts2.31.0          AS system-stat-pg17
FROM ghcr.io/expaso/timescaledb/dependency/postgresql-extension-system-stat-pg18:3.2-ts2.31.0          AS system-stat-pg18
FROM ghcr.io/expaso/timescaledb/dependency/pgvector-pg17:0.8.7-ts2.31.0                                AS pgvector-pg17
FROM ghcr.io/expaso/timescaledb/dependency/pgvector-pg18:0.8.7-ts2.31.0                                AS pgvector-pg18


###########################################
# Define base Image
###########################################
# hadolint ignore=DL3006
FROM $BUILD_FROM AS addon
ARG BUILD_ARCH
ARG TARGETARCH=${BUILD_ARCH}
ARG TARGETVARIANT
ARG ALPINE_VERSION

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

# Upgrade SSL libraries, and musl: the base image pins it, while the PostgreSQL dev
# packages need the latest musl-dev of this Alpine release
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add --upgrade libssl3 libcrypto3 openssl-dev musl

###########################################
# Install all sub-components
###########################################

# -----------------------------------------
# PostgreSql 17 (old, only used to upgrade existing databases)
# -----------------------------------------
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        postgresql17-jit \
        postgresql17 \
        postgresql17-contrib-jit \
        postgresql17-contrib

# -----------------------------------------
# PostgreSql 18 (new)
# -----------------------------------------
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        postgresql18-jit \
        postgresql18 \
        postgresql18-dev \
        postgresql18-contrib-jit \
        postgresql18-contrib

# Set default postgresql version to 18
RUN rm /usr/libexec/postgresql \
    && ln -s /usr/libexec/postgresql18 /usr/libexec/postgresql \
    && rm /usr/share/postgresql \
    && ln -s /usr/share/postgresql18 /usr/share/postgresql

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions

# -----------------------------------------
# Extension Postgis
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
    && apk add --repository https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community \
        gdal-driver-postgisraster \
    && apk add --repository https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main \
        libturbojpeg

# Postgis + Postgis-Raster pg-17 (old)
COPY --from=postgis-pg17 --link /usr/local/lib/postgresql/postgis* /usr/lib/postgresql17/
COPY --from=postgis-pg17 --link /usr/local/lib/postgresql/bitcode/postgis-3/* /usr/lib/postgresql17/bitcode/postgis-3/
COPY --from=postgis-pg17 --link /usr/local/lib/postgresql/bitcode/postgis_raster-3/* /usr/lib/postgresql17/bitcode/postgis_raster-3/
COPY --from=postgis-pg17 --link /usr/local/share/postgresql/contrib/postgis* /usr/share/postgresql17/contrib/
COPY --from=postgis-pg17 --link /usr/local/share/postgresql/extension/postgis* /usr/share/postgresql17/extension/

# Postgis + Postgis-Raster pg-18 (new)
COPY --from=postgis-pg18 --link /usr/local/lib/postgresql/postgis* /usr/lib/postgresql18/
COPY --from=postgis-pg18 --link /usr/local/lib/postgresql/bitcode/postgis-3/* /usr/lib/postgresql18/bitcode/postgis-3/
COPY --from=postgis-pg18 --link /usr/local/lib/postgresql/bitcode/postgis_raster-3/* /usr/lib/postgresql18/bitcode/postgis_raster-3/
COPY --from=postgis-pg18 --link /usr/local/share/postgresql/contrib/postgis* /usr/share/postgresql18/contrib/
COPY --from=postgis-pg18 --link /usr/local/share/postgresql/extension/postgis* /usr/share/postgresql18/extension/

# -----------------------------------------
# Extension Timescale
# -----------------------------------------
# Both versions get the same TimescaleDB release, pg_upgrade requires that
COPY --from=timescale-pg17 --link /usr/local/lib/postgresql/timescaledb*.so /usr/lib/postgresql17/
COPY --from=timescale-pg17 --link /usr/local/share/postgresql/extension/timescaledb* /usr/share/postgresql17/extension/
COPY --from=timescale-pg18 --link /usr/local/lib/postgresql/timescaledb*.so /usr/lib/postgresql18/
COPY --from=timescale-pg18 --link /usr/local/share/postgresql/extension/timescaledb* /usr/share/postgresql18/extension/

# --------------------------------------------
# Extension pgAgent
# --------------------------------------------
COPY --from=pgagent-pg17 --link /usr/local/share/postgresql/extension/pgagent* /usr/share/postgresql17/extension/
COPY --from=pgagent-pg18 --link /usr/local/share/postgresql/extension/pgagent* /usr/share/postgresql18/extension/

# The pgAgent daemon itself runs against the new version
COPY --from=pgagent-pg18 --link /usr/local/share/pgagent.sql /usr/local/share/
COPY --from=pgagent-pg18 --link /usr/local/bin/pgagent /usr/local/bin/

# Add compatibility libraries
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        boost-libs

# --------------------------------------
# Extension Timescaledb-Toolkit
# --------------------------------------
COPY --from=timescaledb-toolkit-pg17 --link /usr/local/lib/postgresql/timescaledb_toolkit* /usr/lib/postgresql17/
COPY --from=timescaledb-toolkit-pg17 --link /usr/local/share/postgresql/extension/timescaledb_toolkit* /usr/share/postgresql17/extension/
COPY --from=timescaledb-toolkit-pg18 --link /usr/local/lib/postgresql/timescaledb_toolkit* /usr/lib/postgresql18/
COPY --from=timescaledb-toolkit-pg18 --link /usr/local/share/postgresql/extension/timescaledb_toolkit* /usr/share/postgresql18/extension/

# Add compatibility libraries for timescaledb toolkit
# hadolint ignore=DL3018
RUN --mount=type=cache,id=apk-${TARGETARCH}-${TARGETVARIANT},sharing=locked,target=/var/cache/apk \
    set -ex \
    && apk add \
        gcompat

# --------------------------------------------
# Extension System-Stat
# --------------------------------------------
COPY --from=system-stat-pg17 --link /usr/local/lib/postgresql/system_stats*.so /usr/lib/postgresql17/
COPY --from=system-stat-pg17 --link /usr/local/share/postgresql/extension/system_stats* /usr/share/postgresql17/extension/
COPY --from=system-stat-pg18 --link /usr/local/lib/postgresql/system_stats*.so /usr/lib/postgresql18/
COPY --from=system-stat-pg18 --link /usr/local/share/postgresql/extension/system_stats* /usr/share/postgresql18/extension/

# --------------------------------------------
# Extension pgVector
# --------------------------------------------
COPY --from=pgvector-pg17 --link /usr/local/lib/postgresql/vector*.so /usr/lib/postgresql17/
COPY --from=pgvector-pg17 --link /usr/local/share/postgresql/extension/vector* /usr/share/postgresql17/extension/
COPY --from=pgvector-pg18 --link /usr/local/lib/postgresql/vector*.so /usr/lib/postgresql18/
COPY --from=pgvector-pg18 --link /usr/local/share/postgresql/extension/vector* /usr/share/postgresql18/extension/

# --------------------------------------
# Timescaledb Tools (alwasys latest)
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
# /package/admin/s6-overlay is a symlink to the versioned s6-overlay directory, which rsync
# no longer follows on the receiving side, so copy that part to the resolved path first.
RUN S6_OVERLAY_DIR="$(readlink -f /package/admin/s6-overlay)" \
    && cp -R /rootfs/package/admin/s6-overlay/. "${S6_OVERLAY_DIR}/" \
    && rm -rf /rootfs/package \
    && rsync -LKavz /rootfs/ / && rm -rf /rootfs

# Make backup and restore scripts executable
RUN chmod +x /usr/share/timescaledb/backup_pre.sh \
    && chmod +x /usr/share/timescaledb/backup_post.sh \
    && chmod +x /usr/share/timescaledb/restore_from_backup.sh

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
    org.opencontainers.image.licenses="Apache 2.0" \
    org.opencontainers.image.url="https://ghcr.io/expaso/timescaledb/${BUILD_ARCH}:" \
    org.opencontainers.image.source="https://github.com/expaso/hassos-addon-timescaledb" \
    org.opencontainers.image.documentation="https://github.com/expaso/hassos-addon-timescaledb/blob/master/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
