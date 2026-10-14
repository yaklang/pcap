#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=musl/source.env
source "$repo_root/scripts/musl/source.env"
usage() { echo 'usage: scripts/build-musl-libpcap.sh <amd64|arm64> [--check]' >&2; exit 2; }
arch="${1:-}"
case "$arch" in
  amd64) platform_image="$MUSL_BUILD_IMAGE_AMD64" ;;
  arm64) platform_image="$MUSL_BUILD_IMAGE_ARM64" ;;
  *) usage ;;
esac
mode="${2:-}"
[[ $# -le 2 && ( -z "$mode" || "$mode" == --check ) ]] || usage
# A registry mirror may supply the same immutable image; a different image
# requires a reviewed source.env update, never an unrecorded local override.
image="${MUSL_IMAGE_MIRROR:-$platform_image}"
[[ "${image##*@}" == "${platform_image##*@}" ]] || {
  echo 'MUSL_IMAGE_MIRROR must retain the pinned image digest' >&2; exit 1;
}
work="$(mktemp -d "${TMPDIR:-/tmp}/pcap-musl-${arch}.XXXXXX")"
trap 'rm -rf -- "$work"' EXIT
build_options=()
if [[ "$mode" == --check ]]; then
  build_options+=(--no-cache-filter build)
fi
docker buildx build --platform "linux/$arch" \
  --network "${MUSL_BUILD_NETWORK:-default}" \
  "${build_options[@]}" \
  --build-arg "BUILD_IMAGE=$image" --target artifact \
  --output "type=local,dest=$work/artifact" \
  --file "$repo_root/scripts/musl/Dockerfile" "$repo_root/scripts/musl"
destination="$repo_root/libpcap/$LIBPCAP_VERSION/$arch/musl"
(cd "$work/artifact" && sha256sum -c SHA256SUMS)
if [[ "$mode" == --check ]]; then
  diff -qr "$destination" "$work/artifact"
else
  mkdir -p "$destination"
  cp -R "$work/artifact/." "$destination/"
fi
echo "verified Linux $arch musl libpcap $LIBPCAP_VERSION: $destination"
