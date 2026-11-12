# Security questions

This file teaches how to verify in this stack. It imposes no pattern: which patterns the project uses is the team's decision.

These are questions, not rules. The person answers the ones for the boundary types of the project, and each answer becomes a threat, a control and a verification in the `## Security` section of the golden path, in the format of `templates/golden-path.md`.

## Input validation

- Does incoming data pass through a `ValidationPipe`?
- Is the pipe registered globally or per route, and where?
- Are `whitelist` and `forbidNonWhitelisted` on, and what happens to an extra field?
- Do the DTOs use `class-validator` and `class-transformer`?
- Does `transform` convert route and query parameters, and who checks the type afterwards?

## Guards and authorization

- Which routes need a guard?
- Is the guard global (`APP_GUARD`) or per controller?
- Is each public route a declared exception, or an oversight?

## Config and secrets

- Where do the secrets come from?
- Does `@nestjs/config`, or another mechanism, validate the variables at boot?
- Can a secret end up in the repository, in the image or in a log?

## Outbound HTTP

- Does the client (`@nestjs/axios` or another) set a `timeout`?
- Who decides the `retries`, given that `@nestjs/axios` does not retry on its own?
- Is a retry safe for the operation being repeated?
- What happens with a response from a third party that is outside the contract?

## Logging of sensitive data

- What does the `logging` record of a request body, a header and an error?
- Can personal data or a token appear in it?

## Rate limiting

- Does the boundary have `rate limiting`?
- With `@nestjs/throttler`, where is the `ThrottlerGuard` registered, and which routes use `@SkipThrottle()` and why?

## Headers

- Which security `headers` does the response carry, with `helmet` or without it?
- Who checks the CORS configuration?

## Not verified

Not checked against the official documentation; confirm before relying on it:

- The shape of the `HttpModule` options of `@nestjs/axios` beyond `timeout`.
- `ConfigModule` and the validation of variables in `@nestjs/config`.
- `helmet` and CORS in Nest.
- Registering the pipe globally through `APP_PIPE`: the validation page shows `app.useGlobalPipes(...)` and does not mention `APP_PIPE`.

Confirmed in the documentation: `ValidationPipe` with `whitelist`, `forbidNonWhitelisted` and `transform`; `class-validator` and `class-transformer`; `@nestjs/throttler` with `ttl` in milliseconds, `limit`, `ThrottlerGuard` through `APP_GUARD` and `@SkipThrottle()`; `@nestjs/axios` with no built-in retry.
