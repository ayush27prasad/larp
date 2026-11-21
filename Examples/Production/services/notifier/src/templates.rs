//! Email bodies for each order event. Names match `[notifier.templates]` in
//! config/settings.toml.

use crate::OrderEvent;

pub fn subject(event: &OrderEvent) -> String {
    match event.status.as_str() {
        "PAID" => format!("Order {} confirmed", event.order_id),
        "SHIPPED" => format!("Order {} is on its way", event.order_id),
        "CANCELLED" => format!("Order {} was cancelled", event.order_id),
        other => format!("Order {} update: {}", event.order_id, other),
    }
}

pub fn body(event: &OrderEvent) -> String {
    let total = format_cents(event.total_cents);
    match event.status.as_str() {
        "PAID" => format!("Thanks! We've received your payment of {total}."),
        "SHIPPED" => "Your order has shipped. Tracking details will follow.".to_string(),
        "CANCELLED" => format!("Your order was cancelled and {total} will not be charged."),
        _ => String::new(),
    }
}

pub fn format_cents(cents: i64) -> String {
    format!("${}.{:02}", cents / 100, cents % 100)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn formats_cents_as_dollars() {
        assert_eq!(format_cents(1_579), "$15.79");
        assert_eq!(format_cents(5), "$0.05");
    }
}
