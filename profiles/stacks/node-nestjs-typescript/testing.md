# Testing recipes

This file teaches how to verify in this stack. It imposes no pattern: which patterns the project uses is the team's decision.

## Test one module

`Test.createTestingModule` takes the metadata of a `@Module()`. `compile()` is asynchronous and returns the testing module, and `get()` returns an instance of a controller or provider from it.

`overrideProvider(<token>)` swaps a dependency for a double, with `useValue(...)`, `useClass(...)` or `useFactory(...)`.

What this verifies: the module assembles and the injection resolves. What it does not verify: how the module behaves over HTTP, or against the real dependency it was swapped for. `verify.unit` comes from the `package.json` of the project, and the test runner is whichever the project uses: the recipe above is the Nest API and does not depend on the runner.

## Test one path end to end

1. Build the module as above, with `Test.createTestingModule`.
2. Call `createNestApplication()` on it, then `await app.init()`: the application is not initialized for you.
3. Send requests with `supertest` over `app.getHttpServer()`.
4. Call `app.close()` in `afterAll`.

End to end files live in `test/` with the `.e2e-spec` suffix. The `test:e2e` script of the project is what the stack detection proposes for `verify.integration`; `verify.integration_when` is still a question for the person.

## Real-system scenarios for boundary types

How to write, in this stack, the `## Verification` section of the golden path of a boundary type. Each scenario uses the format of `templates/golden-path.md`:

```text
### Scenario: <what it proves>

- Context: <...>
- Steps: <...>
- Success: <...>
- When blocked: <...>
```

Rules:

- No mock at the boundary. The scenario runs against the real system.
- The real system is a local instance or a sandbox, never production.
- Credentials appear only as a placeholder, such as `<API_KEY>`. A real secret never appears in the text.
- The scenario says how to bring the dependency up, for example a local container, without imposing which one.

Generic example, for an incoming HTTP boundary:

```text
### Scenario: <module> rejects a request without credentials

- Context: the application runs locally with the <module> module and a local database; credentials are <TEST_TOKEN>, a placeholder set in the local environment, never production.
- Steps: start the dependencies locally; start the application; send a request to the <module> route with no credential; send the same request with <TEST_TOKEN>.
- Success: the first request is refused and nothing is written; the second succeeds.
- When blocked: when the local dependencies cannot start, ask the owner of the environment for access to the sandbox, and record in the PR that the scenario was not run and why.
```

Generic example, for an outgoing boundary:

```text
### Scenario: <service> gives up on a third party that does not answer

- Context: the application runs locally and calls the sandbox of the third party at <SANDBOX_URL> with <API_KEY>, a placeholder from the local environment; never production.
- Steps: call the <service> operation while the sandbox is made to answer slowly or not at all; then call it with the sandbox healthy.
- Success: the first call ends within the timeout the golden path declares and reports a controlled failure; the second returns the expected result.
- When blocked: when the sandbox cannot be reached, ask the owner of the integration for access, and record in the PR that the scenario was not run.
```

## Not verified

The Nest testing page consulted does not cover the scripts a generated project defines, nor the `test/jest-e2e.json` file. The `test:e2e` name and that file are common in generated projects but were not confirmed in the documentation: read the `package.json` of the project instead of assuming them. The same page says new projects use Vitest by default and shows Jest and `supertest` in its examples, so confirm which runner the project has.
