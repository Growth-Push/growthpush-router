# AGENTS.md

## Project

This repository is a Phoenix/Elixir app (`growthpush_router`) with server-rendered UI and Gettext.

Use the nearest scoped `AGENTS.md` for layer-specific conventions:

- `lib/growthpush_router/AGENTS.md` for domain contexts, schemas, auth business rules, and data validation.
- `lib/growthpush_router_web/AGENTS.md` for controllers, templates, routing, Gettext usage, and user-facing UI.

## Validation

Before finishing changes, run:

```bash
mix precommit
```

## Public Functions

- Public functions in domain modules must have `@doc`.
- Each public function doc must include at least one executable doctest covering the happy path.
- If a public function cannot reasonably have a doctest, document why in the function `@doc` and cover the happy path with a regular test.
