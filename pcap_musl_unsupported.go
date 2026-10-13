//go:build linux && musl && !amd64 && !arm64

package pcap

/*
#error "the musl build tag supports Linux amd64 and arm64 only"
*/
import "C"
