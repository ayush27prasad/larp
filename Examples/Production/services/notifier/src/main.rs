mod templates;

use serde::Deserialize;
use std::io::{self, BufRead};

/// One line of the order event stream published by orders-api.
#[derive(Debug, Deserialize)]
pub struct OrderEvent {
    pub order_id: String,
    pub customer_email: String,
    pub status: String,
    pub total_cents: i64,
}

fn main() {
    for line in io::stdin().lock().lines() {
        let Ok(line) = line else { break };
        match serde_json::from_str::<OrderEvent>(&line) {
            Ok(event) => send(&event),
            Err(err) => eprintln!("skipping malformed event: {err}"),
        }
    }
}

fn send(event: &OrderEvent) {
    // Delivery goes through SMTP in production; stdout keeps local runs simple.
    println!("To: {}", event.customer_email);
    println!("Subject: {}", templates::subject(event));
    println!();
    println!("{}", templates::body(event));
}
