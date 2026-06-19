package main

import "testing"

func TestEnvDefault(t *testing.T) {
	if got := env("DEFINITELY_UNSET_VAR", "fallback"); got != "fallback" {
		t.Fatalf("expected fallback, got %q", got)
	}
}
