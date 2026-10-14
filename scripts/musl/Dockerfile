ARG BUILD_IMAGE=golang:1.22.12-alpine3.21@sha256:1699c10032ca2582ec89a24a1312d986a3f094aed3d5c1147b19880afe40e052
FROM ${BUILD_IMAGE} AS toolchain
# Pin the direct compiler/parser inputs. Fail if an Alpine repository no longer
# supplies them rather than silently building replacement archives with new tools.
RUN apk add --no-cache \
    gcc=14.2.0-r4 musl=1.2.5-r11 musl-dev=1.2.5-r11 \
    linux-headers=6.6-r1 make=4.4.1-r2 binutils=2.43.1-r3 \
    flex=2.6.4-r6 bison=3.8.2-r1 curl=8.14.1-r2 jq=1.7.1-r0 \
    bluez-dev=5.79-r0

FROM toolchain AS build
ARG TARGETARCH
ARG BUILD_IMAGE
COPY source.env build-inside.sh /recipe/
RUN LIBPCAP_TARGET_ARCH="${TARGETARCH}" LIBPCAP_ACTUAL_BUILD_IMAGE="${BUILD_IMAGE}" sh /recipe/build-inside.sh

FROM scratch AS artifact
COPY --from=build /artifacts/ /
