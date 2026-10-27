# Golden path: creating a service

A service performs one business operation. A handler calls it. It calls other services, a repository and external clients. Replace every `<stack: ...>` gap with the tool, path or command of your stack, then list this file in `architecture.golden_paths` of `.rastro/config.yml`.

Rules in play, defined in `../rules.md`: `[module-public-api]`, `[no-service-cycle]`, `[pure-domain]` and `[no-sensitive-log]`.

## Checklist

- [ ] Name the service after the business operation, not the technique: `PlaceOrderService`, not `OrderManager`. Put it in `<stack: folder for services in a module>`.
- [ ] Give it one public method that performs the operation. A second operation is a second service.
- [ ] Receive every dependency through the constructor, typed as an interface: `<stack: dependency-injection mechanism>`.
- [ ] Reach another module only through its public API (`[module-public-api]`): import from `<other-module>/index.ts`.
- [ ] Check the dependency edge before you add it. If the target already depends on this service, directly or through a chain, stop (`[no-service-cycle]`).
- [ ] Enforce `[no-service-cycle]` with a cycle detector in the lint. The section below says how.
- [ ] Decide the transaction boundary in the service, never in the handler or the repository: `<stack: transaction mechanism>`. Two modules that do not share a transaction need a compensating call when the second step fails.
- [ ] Throw a typed error for each outcome a caller must tell apart (`UnknownBookError`, `OutOfStockError`). The handler maps the type to a response.
- [ ] Keep business rules in `domain/` when it exists, as plain classes (`[pure-domain]`). The service orchestrates and the entity decides.
- [ ] Log the operation name and identifiers, and no field of `architecture.sensitive_data` (`[no-sensitive-log]`): `<stack: logger>`.
- [ ] Test the service with fakes for its dependencies, one case per typed error: `<stack: unit test runner>`.

## Cycle detector

Without a cycle detector in the lint, `no-service-cycle` is advisory: a reviewer sees only the cycle that fits in one diff, and a cycle that closes across two PRs passes both reviews.

To make the rule deterministic:

1. Pick a tool that builds the import graph of your service folders and fails when the graph has a cycle: `<stack: cycle detector>`.
2. Add its command to `verify.lint` in `.rastro/config.yml`: `<stack: command that runs the detector over the service folders>`. CI runs `verify.lint`, so the detector runs there too.
3. List each cycle that already exists as one `Known debt:` line of the rule, and exclude exactly those from the detector: `<stack: how the detector excludes a known cycle>`.
4. Until the detector runs, report a pass on `no-service-cycle` as "not checked by a tool". Do not report it as clean.

## Worked example

Stack: TypeScript, plain classes, no framework. The bookstore `orders` module places an order. It depends on `catalog` and `inventory`, and neither depends back on `orders`.

`src/catalog/index.ts` and `src/inventory/index.ts` are the public APIs that `orders` imports:

```ts
export interface Catalog {
  exists(isbn: string): Promise<boolean>;
}
```

```ts
export type StockLine = { isbn: string; quantity: number };

export type ReserveResult =
  | { reserved: true }
  | { reserved: false; shortIsbn: string };

export interface Inventory {
  reserve(lines: ReadonlyArray<StockLine>): Promise<ReserveResult>;
  release(lines: ReadonlyArray<StockLine>): Promise<void>;
}
```

`src/orders/domain/order.ts` imports nothing:

```ts
export type OrderLine = { isbn: string; quantity: number };

export class EmptyOrderError extends Error {
  constructor() {
    super('an order needs at least one line');
  }
}

export class Order {
  private constructor(
    readonly id: string,
    readonly customerId: string,
    readonly lines: ReadonlyArray<OrderLine>,
  ) {}

  static place(
    id: string,
    customerId: string,
    lines: ReadonlyArray<OrderLine>,
  ): Order {
    if (lines.length === 0) {
      throw new EmptyOrderError();
    }
    return new Order(id, customerId, lines);
  }
}
```

`src/orders/repositories/order.repository.ts`:

```ts
import type { Order } from '../domain/order';

export interface OrderRepository {
  save(order: Order): Promise<void>;
}
```

`src/orders/services/place-order.service.ts`:

```ts
import { randomUUID } from 'node:crypto';
import type { Catalog } from '../../catalog';
import type { Inventory } from '../../inventory';
import { Order, type OrderLine } from '../domain/order';
import type { OrderRepository } from '../repositories/order.repository';

export class UnknownBookError extends Error {
  constructor(readonly isbn: string) {
    super(`unknown book ${isbn}`);
  }
}

export class OutOfStockError extends Error {
  constructor(readonly isbn: string) {
    super(`not enough copies of ${isbn}`);
  }
}

export type PlaceOrderInput = {
  customerId: string;
  lines: ReadonlyArray<OrderLine>;
};

export class PlaceOrderService {
  constructor(
    private readonly catalog: Catalog,
    private readonly inventory: Inventory,
    private readonly orders: OrderRepository,
  ) {}

  async execute(input: PlaceOrderInput): Promise<Order> {
    for (const line of input.lines) {
      if (!(await this.catalog.exists(line.isbn))) {
        throw new UnknownBookError(line.isbn);
      }
    }
    const reservation = await this.inventory.reserve(input.lines);
    if (!reservation.reserved) {
      throw new OutOfStockError(reservation.shortIsbn);
    }
    const order = Order.place(randomUUID(), input.customerId, input.lines);
    try {
      await this.orders.save(order);
    } catch (error) {
      await this.inventory.release(input.lines);
      throw error;
    }
    return order;
  }
}
```

What the example shows:

- `PlaceOrderService` imports `Catalog` and `Inventory` from the `index.ts` of each module, never from their internals (`[module-public-api]`).
- Dependencies run one way: `orders` calls `inventory` and `catalog`. When `inventory` has to react to a cancelled order, `orders` calls `inventory.release`. `inventory` never imports `orders` (`[no-service-cycle]`).
- `order.ts` imports no framework and no ORM. The repository owns the mapping to storage (`[pure-domain]`).
- Typed errors let the handler pick a status code without reading a message.
- A failed save releases the reservation, because `orders` and `inventory` do not share a transaction.
