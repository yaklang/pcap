#!/bin/sh
set -eu
# shellcheck source=source.env
. /recipe/source.env
export SOURCE_DATE_EPOCH LC_ALL=C TZ=UTC ZERO_AR_DATE=1
case "${LIBPCAP_TARGET_ARCH:?target architecture required}" in
  amd64) machine=x86_64; platform_image="$MUSL_BUILD_IMAGE_AMD64" ;;
  arm64) machine=aarch64; platform_image="$MUSL_BUILD_IMAGE_ARM64" ;;
  *) echo 'musl libpcap supports amd64 and arm64 only' >&2; exit 1 ;;
esac
test "${LIBPCAP_ACTUAL_BUILD_IMAGE##*@}" = "${platform_image##*@}"
test "$(uname -m)" = "$machine"
case "$(gcc -dumpmachine)" in *-linux-musl) ;; *) echo 'compiler must target musl' >&2; exit 1 ;; esac

mkdir -p /src /artifacts
curl --fail --location --silent --show-error --retry 3 --proto '=https' \
  "$LIBPCAP_SOURCE_URL" -o /src/source.tar.xz
printf '%s  %s\n' "$LIBPCAP_SOURCE_SHA256" /src/source.tar.xz | sha256sum -c -
tar -xJf /src/source.tar.xz -C /src --strip-components=1
cd /src
export CFLAGS='-O2 -g0 -fPIC -ffile-prefix-map=/src=libpcap-source'
export LDFLAGS=-static
set -- \
  --prefix=/usr/local --disable-shared --enable-ipv6 --enable-usb --enable-bluetooth \
  --disable-remote --disable-dbus --disable-rdma \
  --disable-netmap --without-libnl --without-dag --without-septel \
  --without-snf --without-turbocap --without-dpdk
./configure "$@"
make -j2
make DESTDIR=/install install
cp -R /install/usr/local/include /artifacts/include
mkdir -p /artifacts/lib
cp libpcap.a /artifacts/lib/libpcap.a
cp LICENSE /artifacts/LICENSE

# Reject both glibc-specific references and optional dlopen backends. Ordinary
# libc calls such as getaddrinfo remain valid musl references and are not rejected.
nm -u -P libpcap.a > /tmp/undefined-symbols
if grep -E '(^|[[:space:]])(_IO_[^ ]*|__[^ ]*_chk|__chk_fail|__(xstat|lxstat|fxstat|isoc99_[^ ]*|libc_[^ ]*)|dlopen|dlsym|dlclose|dlerror)[[:space:]]+U' /tmp/undefined-symbols; then
  echo 'archive has glibc ABI or dynamic-loader references' >&2
  exit 1
fi
apk info -v | sort > /artifacts/TOOLCHAIN_PACKAGES.txt
jq -n \
  --arg version "$LIBPCAP_VERSION" \
  --arg url "$LIBPCAP_SOURCE_URL" \
  --arg source_sha256 "$LIBPCAP_SOURCE_SHA256" \
  --arg commit "$LIBPCAP_SOURCE_COMMIT" \
  --arg signer "$LIBPCAP_SIGNING_FINGERPRINT" \
  --arg arch "$LIBPCAP_TARGET_ARCH" \
  --arg image_index "$MUSL_BUILD_IMAGE" --arg image "$platform_image" \
  --arg compiler "$(gcc --version | head -n1)" \
  --arg compiler_target "$(gcc -dumpmachine)" \
  --arg cflags "$CFLAGS" --arg ldflags "$LDFLAGS" \
  --argjson source_date_epoch "$SOURCE_DATE_EPOCH" \
  --arg archive_sha256 "$(sha256sum libpcap.a | cut -d' ' -f1)" \
  --args '
    {
      schema_version: 1, library: "libpcap", version: $version,
      source: {url: $url, sha256: $source_sha256, commit: $commit, signing_fingerprint: $signer},
      target: {goos: "linux", goarch: $arch, libc: "musl", linkage: "static"},
      build: {image_index: $image_index, image: $image, compiler: $compiler, compiler_target: $compiler_target,
              cflags: $cflags, ldflags: $ldflags, configure: $ARGS.positional,
              source_date_epoch: $source_date_epoch},
      archive: {path: "lib/libpcap.a", sha256: $archive_sha256},
      features: {linux_packet_socket: true, ipv6: true, usbmon: true,
                 remote_capture: false, dbus: false, bluetooth: true,
                 rdma: false, netmap: false, libnl: false}
    }' -- "$@" > /artifacts/MANIFEST.json
cd /artifacts
find . -type f ! -name SHA256SUMS | sort > /tmp/pcap-artifact-paths
xargs sha256sum < /tmp/pcap-artifact-paths > SHA256SUMS
sha256sum -c SHA256SUMS
