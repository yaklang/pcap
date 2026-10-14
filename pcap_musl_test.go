//go:build linux && musl

package pcap

import (
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gopacket/gopacket"
	"github.com/gopacket/gopacket/layers"
	"github.com/gopacket/gopacket/pcapgo"
)

func TestMuslUsesBundledLibpcap(t *testing.T) {
	if version := Version(); !strings.HasPrefix(version, "libpcap version 1.10.7") {
		t.Fatalf("musl build selected the wrong libpcap: %s", version)
	}
}

// A 64-bit timeval must survive the C/Go boundary on both supported architectures.
func TestMuslPCAPTimestampAfter2038(t *testing.T) {
	path := filepath.Join(t.TempDir(), "after2038.pcap")
	file, err := os.Create(path)
	if err != nil {
		t.Fatal(err)
	}
	writer := pcapgo.NewWriter(file)
	if err := writer.WriteFileHeader(65535, layers.LinkTypeEthernet); err != nil {
		file.Close()
		t.Fatal(err)
	}
	data := packet[:]
	want := gopacket.CaptureInfo{
		Timestamp: time.Unix(2208988800, 123456000), CaptureLength: len(data), Length: len(data),
	}
	if err := writer.WritePacket(want, data); err != nil {
		file.Close()
		t.Fatal(err)
	}
	if err := file.Close(); err != nil {
		t.Fatal(err)
	}
	handle, err := OpenOffline(path)
	if err != nil {
		t.Fatal(err)
	}
	defer handle.Close()
	got, info, err := handle.ReadPacketData()
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, data) || !info.Timestamp.Equal(want.Timestamp) || info.CaptureLength != want.CaptureLength || info.Length != want.Length {
		t.Fatalf("packet or 64-bit timestamp changed: got %+v, want %+v", info, want)
	}
}

// These paths use pcap_offline_filter, whose bounded interpreter was hardened in
// 1.10.7. A malformed caller-supplied program must reject without reading beyond
// its instruction buffer or dividing by zero.
func TestMuslMalformedBPFRejectsSafely(t *testing.T) {
	handle, err := OpenOffline("test_ethernet.pcap")
	if err != nil {
		t.Fatal(err)
	}
	defer handle.Close()
	data, info, err := handle.ReadPacketData()
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		name         string
		instructions []BPFInstruction
	}{
		{"jump outside program", []BPFInstruction{{Code: 0x05, K: 2}}},
		{"invalid opcode", []BPFInstruction{{Code: 0xffff}}},
		{"division by zero", []BPFInstruction{{Code: 0x00, K: 1}, {Code: 0x34, K: 0}, {Code: 0x16}}},
	} {
		t.Run(test.name, func(t *testing.T) {
			filter, err := handle.NewBPFInstructionFilter(test.instructions)
			if err == nil && filter.Matches(info, data) {
				t.Fatal("malformed BPF program accepted the packet")
			}
		})
	}
}
