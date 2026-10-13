The musl archives are built from The Tcpdump Group's stable libpcap 1.10.7
release, not from the older glibc archives in this repository.

- Release archive: https://www.tcpdump.org/release/libpcap-1.10.7.tar.xz
- SHA-256: `68fa62cffb974f4275641ce14c2e2d75739251f30e00e6a0900903b247d76a03`
- Upstream tag: `libpcap-1.10.7`
- Upstream commit: `1926f4163e4eef978c71fde28a3f6d51fff183a8`
- Detached signature: `libpcap-1.10.7.tar.xz.sig`
- Public key: `signing-key.asc`, obtained from
  https://www.tcpdump.org/release/signing-key-RSA-E089DEF1D9C15D0D.asc
- Signing fingerprint: `1F166A5742ABB9E0249A8D30E089DEF1D9C15D0D`

The detached signature was verified before locking the archive digest. Rebuilds
verify the locked SHA-256 before extracting any source. To independently repeat
the signature check, download the exact archive and import this public key into
a temporary GnuPG home, then run `gpg --verify libpcap-1.10.7.tar.xz.sig
libpcap-1.10.7.tar.xz`. Verify the full fingerprint when importing the key.

`LICENSE` is copied unchanged from that signed release. The source archive is
not a Git-generated snapshot; it includes upstream-generated configure files.
The original archive remains available at the pinned URL, and its exact bytes
are required by `scripts/musl/source.env`. The generated architecture manifests
record the compiler, target libc, package inventory, configure options and
static-library checksum. Those manifests are build provenance, not acceptance
of every capture backend or a full Yaklang deployment.
