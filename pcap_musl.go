//go:build linux && musl && (amd64 || arm64)

package pcap

/*
#cgo amd64 CFLAGS: -I${SRCDIR}/libpcap/1.10.7/amd64/musl/include
#cgo amd64 LDFLAGS: ${SRCDIR}/libpcap/1.10.7/amd64/musl/lib/libpcap.a
#cgo arm64 CFLAGS: -I${SRCDIR}/libpcap/1.10.7/arm64/musl/include
#cgo arm64 LDFLAGS: ${SRCDIR}/libpcap/1.10.7/arm64/musl/lib/libpcap.a
#include <stdlib.h>
#ifdef __GLIBC__
#error "the musl build tag requires a musl C compiler; glibc objects cannot be mixed with the bundled musl libpcap"
#endif
*/
import "C"
