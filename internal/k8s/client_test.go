package k8s

import "testing"

func TestClientType(t *testing.T) {
	var client *Client

	if client != nil {
		t.Fatal("expected nil client")
	}
}
