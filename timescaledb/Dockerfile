ARG BUILD_FROM
ARG BUILD_ARCH

###########################################
# Build TimeScaleDB tools binaries in separate image
###########################################
ARG GO_VERSION=1.14.0
FROM golang:${GO_VERSION}-alpine AS tools

ENV TOOLS_VERSION 0.8.1
ENV BUILD_ARCH $BUILD_ARCH

RUN apk update && apk add --no-cache git \
    && mkdir -p ${GOPATH}/src/github.com/timescale/ \
    && cd ${GOPATH}/src/github.com/timescale/ \
    && git clone https://github.com/timescale/timescaledb-tune.git \
    && git clone https://github.com/timescale/timescaledb-parallel-copy.git \
	# Fixup build arch to be compatible with GO cross compile
	&& if [ "${BUILD_ARCH}" == "aarch64" ]; then BUILD_ARCH="arm64"; fi \
    # Build timescaledb-tune
    && cd timescaledb-tune/cmd/timescaledb-tune \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && GOOS="linux" GOARCH="${BUILD_ARCH}}" go build -o /go/bin/timescaledb-tune \
    # Build timescaledb-parallel-copy
    && cd ${GOPATH}/src/github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy \
    && git fetch && git checkout --quiet $(git describe --abbrev=0) \
    && go get -d -v \
    && GOOS="linux" GOARCH="${BUILD_ARCH}}" go build -o /go/bin/timescaledb-parallel-copy


####################################
# Now build image and copy in tools
####################################
FROM $BUILD_FROM

# Fix versions
ENV TIMESCALEDB_VERSION 1.7.0
ENV POSTGIS_VERSION 2.5.3
# Enable this if you only wanr
#ENV OSS_ONLY -DAPACHE_ONLY=1

# Add normal postgresql alpine package
RUN apk add --no-cache \
    postgresql \
	postgresql-dev

# Create it's run directory
RUN mkdir -p /run/postgresql \
	&& chown -R postgres:postgres /run/postgresql \
    && mkdir -p /run/postgresql/extensions \
	&& chown -R postgres:postgres /run/postgresql/extensions


# Copy over the tools
COPY --from=tools /go/bin/* /usr/local/bin/

# --------------------------------------
# Build TimescaleDB
# --------------------------------------
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                git \
                openssl \
                openssl-dev \
                tar \
    && mkdir -p /build/ \
    && git clone https://github.com/timescale/timescaledb /build/timescaledb\
    && apk add --no-cache --virtual .build-deps \
                coreutils \
                dpkg-dev dpkg \
                gcc \
                libc-dev \
                make \
                cmake \
                util-linux-dev\
    && cd /build/timescaledb && rm -fr build \
    && git checkout ${TIMESCALEDB_VERSION} \
    && ./bootstrap -DREGRESS_CHECKS=OFF -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    && cd build && make install \
    && cd ~ \
    && if [ "${OSS_ONLY}" != "" ]; then rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; fi \
    && apk del .fetch-deps .build-deps \
    && rm -rf /build 

# --------------------------------------
# Build Postgis
# --------------------------------------
RUN set -ex \
    && apk add --no-cache --virtual .fetch-deps \
                ca-certificates \
                openssl \
                tar \
    # add libcrypto from (edge:main) for gdal-2.3.0
    #&& apk add --no-cache --virtual .crypto-rundeps \
    #            --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
    #            libressl2.7-libcrypto \
    #            libcrypto1.1 \
    #            poppler \
    #            llvm9-dev \
    && apk add --no-cache --virtual .build-deps \
        autoconf \
        automake \
        file \
        json-c-dev \
        libtool \
        libxml2-dev \
        make \
        perl \
        llvm \
        clang \
        clang-dev \
    && apk add --no-cache --virtual .build-deps-edge \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/community \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
        g++ \
        gdal-dev \
        geos-dev \
        proj-dev \
        protobuf-c-dev \
    && cd /tmp \
    && wget https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz -O - | tar -xz \
    && chown root:root -R postgis-${POSTGIS_VERSION} \
    && cd /tmp/postgis-${POSTGIS_VERSION} \
    && ./autogen.sh \
    && ./configure \
    && echo "PERL = /usr/bin/perl" >> extensions/postgis/Makefile \
    && echo "PERL = /usr/bin/perl" >> extensions/postgis_topology/Makefile \
    && make -s \
    && make -s install \
    && apk add --no-cache --virtual .postgis-rundeps \
        json-c \
    && apk add --no-cache --virtual .postgis-rundeps-edge \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/community \
        --repository http://dl-cdn.alpinelinux.org/alpine/edge/main \
        geos \
        gdal \
        proj \
        protobuf-c \
        libstdc++ \
    && cd / \
    && rm -rf /tmp/postgis-${POSTGIS_VERSION} \
    && apk del .fetch-deps .build-deps .build-deps-edge

# --------------------------------------
# Finish image
# --------------------------------------

# Make sure that S6 is not so hard on our service startup/shutdown
ENV \
    S6_SERVICES_GRACETIME=18000

# Copy data
COPY rootfs /

WORKDIR /
