package pcap

import "testing"

func TestOpenLive(t *testing.T) {
	handle, err := OpenLive("en0", 1600, false, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer handle.Close()

	err = handle.WritePacketData([]byte("1"))
	if err != nil {
		t.Fatal(err)
	}
}
