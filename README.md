# cross-build friendly

no need install libpcap, use locked libpcap

if u want to build in macOS(darwin), find your aarch64/x86_64 linux gcc by uself

## Linux musl static builds

Linux amd64 and arm64 callers can select the bundled **musl** libpcap with the
`musl` build tag. Use a musl compiler and external static linking, for example:

```sh
CGO_ENABLED=1 CC=x86_64-linux-musl-gcc go build -tags musl \
  -ldflags '-linkmode external -extldflags -static' ./cmd
```

Use the matching arm64 musl compiler when cross compiling. The tag selects an
explicit static archive, so it cannot accidentally select a shared library or
the older glibc archive. A glibc C compiler with this tag is rejected. Without
the tag, the existing glibc Linux archives and other OS bindings remain in use.

The musl archives use **libpcap 1.10.7**, the upstream stable release from
2026-09-05. It includes the upstream BPF interpreter and packet-parser security
fixes absent from the older bundled releases. The Go binding already uses
`pcap_offline_filter`, which is required for the bounded BPF interpreter fix;
valid PCAP, PCAPNG, filter compilation, packet matching, and 64-bit timestamps
are exercised for both architectures. Invalid caller-supplied BPF programs are
also tested. See the [upstream changes](https://github.com/the-tcpdump-group/libpcap/blob/1926f4163e4eef978c71fde28a3f6d51fff183a8/CHANGES).

This opt-in profile supports Linux packet sockets, IPv6, USB monitoring,
Bluetooth and offline capture files. The existing amd64 archive contains a
Bluetooth backend, so the musl builder includes locked BlueZ headers and retains
that backend; libpcap's Bluetooth code uses Linux sockets directly and does not
link to libbluetooth. D-Bus, RDMA, netmap, remote capture, libnl and
vendor capture plugins are disabled so the archive needs no additional native
libraries or dynamic loading. Live capture still requires the target kernel,
interface and capture permissions. The offline tests do not prove live capture
or a complete Yaklang Node deployment. The existing amd64/arm64 archive object
inventories contain Linux packet, USB and netfilter backends; Bluetooth was
present in amd64 only. The musl archives retain those backends, but neither
Bluetooth hardware nor USB/netfilter live capture is accepted by the offline
tests. Optional plugins absent from that inventory stay explicitly disabled.

### Rebuild and verify the bundled archives

```sh
scripts/build-musl-libpcap.sh amd64
scripts/build-musl-libpcap.sh arm64
scripts/build-musl-libpcap.sh amd64 --check
scripts/test-musl-pcap.sh amd64
scripts/test-musl-pcap.sh arm64
```

The builder requires Docker Buildx and either a native target host or configured
QEMU emulation. CI runs each architecture on its native runner. It pins the
multi-architecture builder image index and each platform manifest,
compiler/parser package versions, upstream release URL, source SHA-256 and source commit in
`scripts/musl/source.env` and `scripts/musl/Dockerfile`. The source archive's
detached signature was verified with The Tcpdump Group's key fingerprint
`1F166A5742ABB9E0249A8D30E089DEF1D9C15D0D`; its signature and public key are retained
under `libpcap/1.10.7/source`. Every generated architecture directory contains
the original license, toolchain inventory, build manifest and `SHA256SUMS`.

`--check` compares a fresh build with the committed artifacts. If a pinned Alpine
package is no longer available, the build fails rather than choosing a new
compiler implicitly. A registry mirror can be supplied with `MUSL_IMAGE_MIRROR`
while retaining the exact target platform manifest digest.
`MUSL_BUILD_NETWORK=host` can select the host network for builds on machines whose
BuildKit DNS is unavailable. Runtime regression tests use a pinned Debian
Buster/glibc 2.28 image, NSS compat and no HOME, with networking and
capture privileges disabled. `MUSL_RUNTIME_IMAGE` can similarly supply a mirror
of that same digest; `MUSL_MODULE_CACHE` can reuse a Go module cache.
