import { OrderList } from "./components/OrderList";
import "./styles/app.css";

export default function App() {
  return (
    <main>
      <h1>Your orders</h1>
      <OrderList customerId="cus_demo" />
    </main>
  );
}
