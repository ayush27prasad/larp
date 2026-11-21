// Package httpapi exposes the stock store over HTTP for orders-api.
package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"

	"github.com/orderly/inventory/internal/stock"
)

type reserveRequest struct {
	OrderID string       `json:"order_id"`
	Items   []stock.Item `json:"items"`
}

func Routes(store *stock.Store) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("POST /reservations", func(w http.ResponseWriter, r *http.Request) {
		var req reserveRequest
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		if err := store.Reserve(req.OrderID, req.Items); err != nil {
			status := http.StatusInternalServerError
			if errors.Is(err, stock.ErrInsufficientStock) {
				status = http.StatusConflict
			}
			http.Error(w, err.Error(), status)
			return
		}
		w.WriteHeader(http.StatusCreated)
	})
	mux.HandleFunc("DELETE /reservations/", func(w http.ResponseWriter, r *http.Request) {
		store.Release(strings.TrimPrefix(r.URL.Path, "/reservations/"))
		w.WriteHeader(http.StatusNoContent)
	})
	mux.HandleFunc("GET /stock/{sku}", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]int{"available": store.Available(r.PathValue("sku"))})
	})
	return mux
}
