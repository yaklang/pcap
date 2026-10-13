#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=musl/source.env
source "$repo_root/scripts/musl/source.env"
arch="${1:-}"
[[ $# == 1 && ( "$arch" == amd64 || "$arch" == arm64 ) ]] || {
  echo 'usage: scripts/test-musl-pcap.sh <amd64|arm64>' >&2; exit 2;
}
case "$arch" in
  amd64) platform_image="$MUSL_BUILD_IMAGE_AMD64"; test_image="$MUSL_TEST_IMAGE_AMD64" ;;
  arm64) platform_image="$MUSL_BUILD_IMAGE_ARM64"; test_image="$MUSL_TEST_IMAGE_ARM64" ;;
esac
image="${MUSL_IMAGE_MIRROR:-$platform_image}"
[[ "${image##*@}" == "${platform_image##*@}" ]] || {
  echo 'MUSL_IMAGE_MIRROR must retain the pinned builder digest' >&2; exit 1;
}
runtime_image="${MUSL_RUNTIME_IMAGE:-$test_image}"
[[ "${runtime_image##*@}" == "${test_image##*@}" ]] || {
  echo 'MUSL_RUNTIME_IMAGE must retain the pinned glibc 2.28 image digest' >&2; exit 1;
}
work="$(mktemp -d "${TMPDIR:-/tmp}/pcap-musl-test-${arch}.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/output" "$work/modules"
module_cache="${MUSL_MODULE_CACHE:-$work/modules}"
toolchain="pcap-musl-toolchain:$arch"
docker buildx build --platform "linux/$arch" --build-arg "BUILD_IMAGE=$image" \
  --network "${MUSL_BUILD_NETWORK:-default}" \
  --target toolchain --load --tag "$toolchain" \
  --file "$repo_root/scripts/musl/Dockerfile" "$repo_root/scripts/musl"
# Only compilation may fetch checksummed Go dependencies. Runtime below is offline
# and has no capture privileges. -mod=readonly also keeps module files unchanged.
docker run --rm --platform "linux/$arch" --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$repo_root,dst=/workspace,readonly" \
  --mount "type=bind,src=$work/output,dst=/output" \
  --mount "type=bind,src=$module_cache,dst=/modules" \
  --workdir /workspace \
  --env GOTOOLCHAIN=local --env GOCACHE=/tmp/go-cache --env GOMODCACHE=/modules \
  --env CGO_ENABLED=1 --env CC=gcc "$toolchain" sh -ec '
    go test -mod=readonly -trimpath -tags musl -c \
      -ldflags "-linkmode external -extldflags -static" -o /output/pcap.test .
    go version -m /output/pcap.test > /output/build-info.txt
    readelf -l /output/pcap.test > /output/program-headers.txt
    readelf -d /output/pcap.test > /output/dynamic-section.txt
    if grep -q INTERP /output/program-headers.txt || grep -q NEEDED /output/dynamic-section.txt; then
      echo "test binary is not fully static" >&2; exit 1
    fi
  '
printf 'passwd: compat\ngroup: compat\nshadow: files\nhosts: files dns\n' > "$work/output/nsswitch.conf"
docker run --rm --platform "linux/$arch" --network none --read-only \
  --cap-drop ALL --security-opt no-new-privileges --pids-limit 128 \
  --memory 1g --ulimit core=0 --tmpfs /tmp:rw,size=256m \
  --mount "type=bind,src=$repo_root,dst=/workspace,readonly" \
  --mount "type=bind,src=$work/output,dst=/evidence,readonly" \
  --mount "type=bind,src=$work/output/nsswitch.conf,dst=/etc/nsswitch.conf,readonly" \
  --workdir /workspace "$runtime_image" sh -ec '
    test "$(getconf GNU_LIBC_VERSION)" = "glibc 2.28"
    unset HOME
    exec timeout 120 /evidence/pcap.test -test.v \
      -test.run "^(TestMusl.*|TestPcapNonexistentFile|TestPcapFileRead|TestBPF|TestPCAPGoWrite|TestPCAPGoNgWrite|ExampleBPF)$"
  '
echo "Linux $arch musl offline capture/BPF regression passed in glibc 2.28 without HOME"
