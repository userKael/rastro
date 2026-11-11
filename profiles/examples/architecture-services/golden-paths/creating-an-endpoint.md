---
id: creating-an-endpoint
type: handler
version: 1.0.0
status: current
verified_by: review
instances: [src/orders/handlers/place-order.handler.ts:1]
origin: example, bookstore, 2026-11-11
---

# Golden path: creating an endpoint

## When to use

An endpoint is a handler. It receives a request, calls one service and turns the result into a response. A job or a queue consumer follows the same path with a different entry point. Replace every `<stack: ...>` gap with the tool, path or command of your stack. This file shows the format of a golden path in a bookstore; it is not one to adopt, because in your project the first instance of a type writes its own golden path, pointing to its own code. The worked example copies code only because no real code exists here to point at.

Rules in play, defined in `../rules.md`: `[module-public-api]` and `[no-sensitive-log]`. The service the handler calls follows `creating-a-service.md`.

Not covered here: a read that goes straight from the handler to a repository, such as listing `catalog` titles. The `handler` layer calls one `service`, so that read gets a service first. Business rules do not belong in the handler either.

## Decisions

- **The handler validates the input before it calls a service.** Why: a malformed body must never reach business code, and a 400 at the boundary is cheaper than a failure deeper in. Revisit if: the framework validates the request before the handler runs.
- **The handler takes the customer from the authenticated principal, never from the request body or URL.** Why: a caller must not choose whose order it acts on. Revisit if: the framework supplies the authenticated principal in a different shape.
- **The handler calls exactly one service and makes no repository call.** Why: business state and business rules stay in the service, so the handler stays a translation layer. Revisit if: one request must run two operations that cannot sit in one service.
- **The handler maps each typed error to a status code.** Why: the status code comes from the type of the error, never from reading a message. Revisit if: a shared error mapper replaces the per-handler mapping.

## Checklist

- [ ] Name the handler after the business action (`PlaceOrderHandler`), not after the verb or the URL. Put it in `<stack: folder for handlers in a module>`.
- [ ] Parse and validate the input at the boundary. Reject a malformed body with 400 before any service call: `<stack: request validation mechanism>`.
- [ ] Call exactly one service. A handler makes no repository call and does not branch on business state.
- [ ] Map each typed error of the service to a status code in the handler. Let every other error reach `<stack: global error handler>`.
- [ ] Authenticate and authorize before the handler body runs: `<stack: authentication and authorization guard>`. Take the customer from the authenticated principal the guard sets on the request, never from the body or the URL.
- [ ] Register the route in `<stack: route registration point>`.
- [ ] Update the contract in the same PR when the endpoint is published: `<stack: API specification file or generator>`. `architecture.contract_sources` lists these files.
- [ ] Log the operation name, the identifiers and the status. Log no field of `architecture.sensitive_data` and no whole request body (`[no-sensitive-log]`): `<stack: logger>`.
- [ ] Import another module only through its public API (`[module-public-api]`).
- [ ] Test the handler with the service faked, one case per status code. Test the route end to end once: `<stack: HTTP test client>`.

## Worked example

Stack: TypeScript, plain classes, no framework. The bookstore `orders` module exposes `POST /orders`. The handler takes a request shape of its own, so the same class runs behind any HTTP framework once `<stack: adapter from the framework request to HttpRequest, with customerId set from the authenticated principal>` is written.

`src/orders/handlers/place-order.handler.ts`:

```ts
import {
  OutOfStockError,
  UnknownBookError,
  type PlaceOrderService,
} from '../services/place-order.service';

type HttpRequest = { customerId: string; body: unknown };
type HttpResponse = { status: number; body: unknown };

type PlaceOrderBody = {
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
      const order = await this.placeOrder.execute({
        customerId: request.customerId,
        lines: body.lines,
      });
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
  const { lines } = raw as Partial<PlaceOrderBody>;
  if (!Array.isArray(lines) || lines.length === 0) {
    return null;
  }
  const valid = lines.every(
    (line) =>
      typeof line?.isbn === 'string' &&
      Number.isInteger(line.quantity) &&
      line.quantity > 0,
  );
  return valid ? { lines } : null;
}
```

What the example shows:

- The handler validates first, so a malformed body never reaches the service.
- The customer comes from the authenticated principal on the request, never from the body, so a caller cannot place an order as another customer.
- The handler calls one service and holds no business rule: stock and catalog checks live in `PlaceOrderService`.
- Each typed error of the service maps to one status code: 422 for an unknown book, 409 for short stock. Any other error is rethrown to the global handler.
- The responses carry the `isbn` and the order id. They carry no customer data, and the handler logs none (`[no-sensitive-log]`).

## Security

- Untrusted input, with properties that the caller must not set, from OWASP API Security Top 10 API3:2023 Broken Object Property Level Authorization. Control: the handler parses the body at the boundary, reads only the properties it declares, takes the customer from the authenticated principal rather than the body, and rejects a malformed body with 400. Verified by: the validation item of the checklist in review, and the handler test, which has one case per status code.
- Access without authentication, from OWASP API Security Top 10 API2:2023 Broken Authentication. Control: authentication runs before the handler body. Verified by: the guard item of the checklist in review, the end-to-end test of the route, and the scenario below.
- A request for an order of another customer, from OWASP API Security Top 10 API1:2023 Broken Object Level Authorization. Control: the handler passes the authenticated customer to the service, which refuses an order that customer does not own. Verified by: the scenario below.
- Sensitive data in a response, from OWASP API Security Top 10 API3:2023 Broken Object Property Level Authorization. Control: the response carries the identifiers the caller needs and no field of `architecture.sensitive_data`. Verified by: review of the response shape, and the scenario below, which checks the bodies.
- Sensitive data in a log, from the project rule `[no-sensitive-log]`. Control: the handler logs no field of `architecture.sensitive_data` and no whole request body. Verified by: the logging item of the checklist in review.

## Verification

A reviewer checks each instance against the checklist above. No command enforces this golden path yet, so `verified_by` is `review`.

### Scenario: one customer cannot read the order of another

- Context: the service runs in a test environment, with two customers that each hold a token, and an order placed by customer A. Run `<stack: command to start the test environment and to obtain a token for each customer>`.
- Steps: request the order of A with the token of customer B, then request it with no token: `<stack: HTTP client command>`.
- Success: 404 for B, 401 with no token, and no field of the order of A in either body.
- When blocked: with no test environment or no customer accounts, ask whoever looks after the environment, and record in the PR that the scenario did not run and which control is left unverified.

## Known debt

None.

## History

| Version | Date | Item | Change |
|---|---|---|---|
| 1.0.0 | 2026-11-11 | example | Created from the first instance |
