ARG BUILD_FROM
FROM $BUILD_FROM

# Setup base
RUN apk add --no-cache \
    postgresql

ENV \
    S6_SERVICES_GRACETIME=18000

# Copy data
COPY rootfs /

WORKDIR /
