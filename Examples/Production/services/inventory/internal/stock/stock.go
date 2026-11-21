// Package stock tracks how many units of each SKU are on hand and reserved.
package stock

import (
	"errors"
	"sync"
	"time"
)

var ErrInsufficientStock = errors.New("insufficient stock")

type Item struct {
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}

type reservation struct {
	items     []Item
	expiresAt time.Time
}

// Store is safe for concurrent use.
type Store struct {
	mu           sync.Mutex
	onHand       map[string]int
	reservations map[string]reservation
	ttl          time.Duration
}

func NewStore(onHand map[string]int, ttl time.Duration) *Store {
	return &Store{onHand: onHand, reservations: map[string]reservation{}, ttl: ttl}
}

// Available is on-hand stock minus every live reservation.
func (s *Store) Available(sku string) int {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.availableLocked(sku, time.Now())
}

func (s *Store) availableLocked(sku string, now time.Time) int {
	available := s.onHand[sku]
	for _, r := range s.reservations {
		if now.After(r.expiresAt) {
			continue
		}
		for _, item := range r.items {
			if item.SKU == sku {
				available -= item.Quantity
			}
		}
	}
	return available
}

// Reserve holds stock for an order, all or nothing.
func (s *Store) Reserve(orderID string, items []Item) error {
	s.mu.Lock()
	defer s.mu.Unlock()

	now := time.Now()
	for _, item := range items {
		if s.availableLocked(item.SKU, now) < item.Quantity {
			return ErrInsufficientStock
		}
	}
	s.reservations[orderID] = reservation{items: items, expiresAt: now.Add(s.ttl)}
	return nil
}

func (s *Store) Release(orderID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.reservations, orderID)
}
