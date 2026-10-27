# Golden path: creating an external client

An external client wraps one system outside the process: an HTTP API, an SDK or a queue. A service reaches that system only through the client. Replace every `<stack: ...>` gap with the tool, path or command of your stack, then list this file in `architecture.golden_paths` of `.rastro/config.yml`.

Rules in play, defined in `../rules.md`: `[module-public-api]` and `[no-sensitive-log]`.

## Checklist

- [ ] Write one client per external system, in `<stack: folder for external clients>`. The module that uses it owns the interface, and the client implements it.
- [ ] Define the interface in the consuming module's own types (`BookMetadataSource`). External field names and shapes stop at the client, and no external type appears in a service signature.
- [ ] Read the base URL, the credentials and the timeout from configuration validated at startup, never from source: `<stack: configuration and secret loading>`.
- [ ] Set a timeout on every call: `<stack: HTTP client and its timeout option>`.
- [ ] Retry only calls that are safe to repeat, with a bounded number of attempts and a growing delay: `<stack: retry helper>`. Retry a call that creates something only when the system accepts an idempotency key.
- [ ] Translate every failure to a type of your own: a missing record becomes `null`, an unreachable system becomes `MetadataUnavailableError`. A caller never sees a raw status code or a transport error.
- [ ] Log the operation, the outcome and the duration. Log no request header, no credential and no response body that holds data of `architecture.sensitive_data` (`[no-sensitive-log]`): `<stack: logger>`.
- [ ] Test the client against a fake transport, one case per translated outcome. Keep one recorded response of the real system as a fixture: `<stack: HTTP mocking or fixture tool>`.
- [ ] Exercise the client once against the system's sandbox: `<stack: sandbox or emulator, and where its credentials come from>`. List in the PR description what you did not exercise.

## Worked example

Stack: TypeScript, plain classes, the global `fetch`. The bookstore `catalog` module looks up a title by ISBN in a publisher's data service. `catalog` owns the interface and the error, and `PublisherDataClient` implements the interface.

`src/catalog/book-metadata.ts`:

```ts
export type BookMetadata = {
  isbn: string;
  title: string;
  authors: ReadonlyArray<string>;
};

export interface BookMetadataSource {
  find(isbn: string): Promise<BookMetadata | null>;
}

export class MetadataUnavailableError extends Error {
  constructor(readonly reason: string) {
    super(`book metadata source unavailable: ${reason}`);
  }
}
```

`src/catalog/clients/publisher-data.client.ts`:

```ts
import {
  MetadataUnavailableError,
  type BookMetadata,
  type BookMetadataSource,
} from '../book-metadata';

type PublisherDataConfig = {
  baseUrl: string;
  apiKey: string;
  timeoutMs: number;
};

type PublisherBook = {
  isbn13: string;
  title: string;
  contributors: { name: string; role: string }[];
};

export class PublisherDataClient implements BookMetadataSource {
  constructor(
    private readonly config: PublisherDataConfig,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  async find(isbn: string): Promise<BookMetadata | null> {
    let response: Response;
    try {
      response = await this.fetchFn(
        `${this.config.baseUrl}/books/${encodeURIComponent(isbn)}`,
        {
          headers: { authorization: `Bearer ${this.config.apiKey}` },
          signal: AbortSignal.timeout(this.config.timeoutMs),
        },
      );
    } catch {
      throw new MetadataUnavailableError('no response');
    }
    if (response.status === 404) {
      return null;
    }
    if (!response.ok) {
      throw new MetadataUnavailableError(`status ${response.status}`);
    }
    const book = (await response.json()) as PublisherBook;
    return {
      isbn: book.isbn13,
      title: book.title,
      authors: book.contributors
        .filter((contributor) => contributor.role === 'author')
        .map((contributor) => contributor.name),
    };
  }
}
```

What the example shows:

- The client takes `fetch` as a constructor argument, so a test passes a fake transport and makes no network call.
- The timeout is set on every call, and the credential comes from `config`, not from source.
- A 404 becomes `null`, and any other failure becomes `MetadataUnavailableError`. The publisher's field names (`isbn13`, `contributors`) stop inside the client.
- The example has no retry and no logging. Add both as the checklist says: `<stack: retry helper>` for the read, `<stack: logger>` for the outcome and the duration.
