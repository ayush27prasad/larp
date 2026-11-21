package main

import (
	"log"
	"net/http"
	"time"

	"github.com/orderly/inventory/internal/httpapi"
	"github.com/orderly/inventory/internal/stock"
)

func main() {
	store := stock.NewStore(map[string]int{"MUG-01": 120, "TEE-02": 40, "CAP-03": 0}, 15*time.Minute)
	log.Println("inventory listening on :8081")
	log.Fatal(http.ListenAndServe(":8081", httpapi.Routes(store)))
}
