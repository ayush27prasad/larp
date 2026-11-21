package stock

import (
	"testing"
	"time"
)

func TestReserveReducesAvailability(t *testing.T) {
	s := NewStore(map[string]int{"MUG-01": 5}, time.Minute)
	if err := s.Reserve("ord_1", []Item{{SKU: "MUG-01", Quantity: 3}}); err != nil {
		t.Fatal(err)
	}
	if got := s.Available("MUG-01"); got != 2 {
		t.Fatalf("available = %d, want 2", got)
	}
}

func TestReserveIsAllOrNothing(t *testing.T) {
	s := NewStore(map[string]int{"MUG-01": 5, "TEE-02": 1}, time.Minute)
	err := s.Reserve("ord_1", []Item{{SKU: "MUG-01", Quantity: 1}, {SKU: "TEE-02", Quantity: 2}})
	if err != ErrInsufficientStock {
		t.Fatalf("err = %v, want ErrInsufficientStock", err)
	}
	if got := s.Available("MUG-01"); got != 5 {
		t.Fatalf("available = %d, want 5", got)
	}
}

func TestReleaseRestoresStock(t *testing.T) {
	s := NewStore(map[string]int{"MUG-01": 5}, time.Minute)
	_ = s.Reserve("ord_1", []Item{{SKU: "MUG-01", Quantity: 5}})
	s.Release("ord_1")
	if got := s.Available("MUG-01"); got != 5 {
		t.Fatalf("available = %d, want 5", got)
	}
}
