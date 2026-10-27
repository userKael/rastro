# Golden path: creating an endpoint

An endpoint is a handler. It receives a request, calls one service and turns the result into a response. A job or a queue consumer follows the same path with a different entry point. Replace every `<stack: ...>` gap with the tool, path or command of your stack, then list this file in `architecture.golden_paths` of `.rastro/config.yml`.

Rules in play, defined in `../rules.md`: `[module-public-api]` and `[no-sensitive-log]`. The service the handler calls follows `creating-a-service.md`.

## Checklist

- [ ] Name the handler after the business action (`PlaceOrderHandler`), not after the verb or the URL. Put it in `<stack: folder for handlers in a module>`.
- [ ] Parse and validate the input at the boundary. Reject a malformed body with 400 before any service call: `<stack: request validation mechanism>`.
- [ ] Call exactly one service. A handler makes no repository call and does not branch on business state.
- [ ] Map each typed error of the service to a status code in the handler. Let every other error reach `<stack: global error handler>`.
- [ ] Authenticate and authorize before the handler body runs: `<stack: authentication and authorization guard>`.
- [ ] Register the route in `<stack: route registration point>`.
- [ ] Update the contract in the same PR when the endpoint is published: `<stack: API specification file or generator>`. `architecture.contract_sources` lists these files.
- [ ] Log the operation name, the identifiers and the status. Log no field of `architecture.sensitive_data` and no whole request body (`[no-sensitive-log]`): `<stack: logger>`.
- [ ] Import another module only through its public API (`[module-public-api]`).
- [ ] Test the handler with the service faked, one case per status code. Test the route end to end once: `<stack: HTTP test client>`.

## Worked example

Stack: TypeScript, plain classes, no framework. The bookstore `orders` module exposes `POST /orders`. The handler takes a request shape of its own, so the same class runs behind any HTTP framework once `<stack: adapter from the framework request to HttpRequest>` is written.

`src/orders/handlers/place-order.handler.ts`:

```ts
import {
  OutOfStockError,
  UnknownBookError,
  type PlaceOrderService,
} from '../services/place-order.service';

type HttpRequest = { body: unknown };
type HttpResponse = { status: number; body: unknown };

type PlaceOrderBody = {
  customerId: string;
  lines: { isbn: string; quantity: number }[];
};

export class PlaceOrderHandler {
  constructor(private readonly placeOrder: PlaceOrderService) {}

  async handle(request: HttpRequest): Promise<HttpResponse> {
    const body = parsePlaceOrderBody(request.body);
    if (body === null) {
      return { status: 400, body: { error: 'invalid_body' } };
    }
    try {
      const order = await this.placeOrder.execute(body);
      return { status: 201, body: { orderId: order.id } };
    } catch (error) {
      if (error instanceof UnknownBookError) {
        return { status: 422, body: { error: 'unknown_book', isbn: error.isbn } };
      }
      if (error instanceof OutOfStockError) {
        return { status: 409, body: { error: 'out_of_stock', isbn: error.isbn } };
      }
      throw error;
    }
  }
}

function parsePlaceOrderBody(raw: unknown): PlaceOrderBody | null {
  if (typeof raw !== 'object' || raw === null) {
    return null;
  }
  const { customerId, lines } = raw as Partial<PlaceOrderBody>;
  if (
    typeof customerId !== 'string' ||
    !Array.isArray(lines) ||
    lines.length === 0
  ) {
    return null;
  }
  const valid = lines.every(
    (line) =>
      typeof line?.isbn === 'string' &&
      Number.isInteger(line.quantity) &&
      line.quantity > 0,
  );
  return valid ? { customerId, lines } : null;
}
```

What the example shows:

- The handler validates first, so a malformed body never reaches the service.
- The handler calls one service and holds no business rule: stock and catalog checks live in `PlaceOrderService`.
- Each typed error of the service maps to one status code: 422 for an unknown book, 409 for short stock. Any other error is rethrown to the global handler.
- The responses carry the `isbn` and the order id. They carry no customer data, and the handler logs none (`[no-sensitive-log]`).
